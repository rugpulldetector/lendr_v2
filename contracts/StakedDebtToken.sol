// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./Addresses.sol";
import "./Dependencies/LendrBase.sol";
import "./Dependencies/SafetyTransfer.sol";
import "./Interfaces/IStakedDebtToken.sol";
import "./Interfaces/IDebtToken.sol";
import "./Interfaces/IVesselManager.sol";
import "./Interfaces/ICommunityIssuance.sol";
import "./Interfaces/IPriceFeed.sol";

contract StakedDebtToken is ERC4626Upgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, LendrBase, IStakedDebtToken {
	using SafeERC20Upgradeable for IERC20Upgradeable;

	// Tracker for debtToken held in the pool. Changes when users deposit/withdraw, and when Vessel debt is offset.
	uint256 internal totalDebtTokenDeposits;

	// totalColl.tokens and totalColl.amounts should be the same length and
	// always be the same length as IAdminContract(adminContract).validCollaterals().
	// Anytime a new collateral is added to AdminContract, both lists are lengthened
	Colls internal totalColl;

	mapping(address => uint256) internal userRewardPerTokenPaid;

	uint256 internal rewardPerTokenStored;

    // User address => rewards to be claimed
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userUpdatedAt;

	uint256 public updatedAt; // reward updated at
	uint256 public finishAt; // reward distribution finish time
	uint256 public rewardDuration; // reward distribution Duration
	

	// --- Initializer ---

	function initialize(address _underlyingToken) public initializer {
		string memory name = string.concat("Staked ", IERC20Metadata(_underlyingToken).name());
		string memory symbol = string.concat("s", IERC20Metadata(_underlyingToken).symbol());

		__Ownable_init();
		__ERC20_init(name, symbol);
		__ERC4626_init(IERC20Upgradeable(_underlyingToken));
		__ReentrancyGuard_init();
		__UUPSUpgradeable_init();

		__stakedDebtToken_init_unchained();
	}

	function __stakedDebtToken_init_unchained() internal onlyInitializing {
		rewardDuration = 3600 * 24 * 365; // 1year
		finishAt = block.timestamp + rewardDuration;
	}

	/**
	 * @notice add a collateral
	 * @dev should be called anytime a collateral is added to controller
	 * keeps all arrays the correct length
	 * @param _collateral address of collateral to add
	 */
	function addCollateralType(address _collateral) external  onlyAdminContract {
		totalColl.tokens.push(_collateral);
		totalColl.amounts.push(0);
	}

	/**
	 * @notice get collateral balance in the SP for a given collateral type
	 * @dev Not necessarily this contract's actual collateral balance;
	 * just what is stored in state
	 * @param _collateral address of the collateral to get amount of
	 * @return amount of this specific collateral
	 */
	function getCollateral(address _collateral) external view returns (uint256) {
		uint256 collateralIndex = IAdminContract(adminContract).getIndex(_collateral);
		return totalColl.amounts[collateralIndex];
	}

	/**
	 * @notice getter function
	 * @dev gets collateral from totalColl
	 * This is not necessarily the contract's actual collateral balance;
	 * just what is stored in state
	 * @return tokens and amounts
	 */
	function getAllCollateral() external view returns (address[] memory, uint256[] memory) {
		return (totalColl.tokens, totalColl.amounts);
	}

	// override balanceOf function to return asset balance instead of share balance
	// function balanceOf(address _account) public view virtual override(ERC20Upgradeable, IERC20Upgradeable) returns (uint256) {
	// 	uint256 shareBalance = super.balanceOf(_account);
	// 	uint256 assetBalance = convertToAssets(shareBalance);
	// 	return assetBalance;
	// }

	// override totalAssets function to return asset balance instead of share balance
	function totalAssets() public view virtual override returns (uint256) {
		uint256 assetBalance = IERC20Upgradeable(asset()).balanceOf(address(this));
		for (uint i = 0; i < totalColl.tokens.length; ++i) {
			if(totalColl.tokens[i] != address(0)) {
				uint256 tokenDecimals = IERC20MetadataUpgradeable(totalColl.tokens[i]).decimals();
				uint256 price = IPriceFeed(priceFeed).fetchPrice(totalColl.tokens[i]);

				// Normalize the collateral amount to match the decimals of the vault's asset
				uint256 normalizedAmount = totalColl.amounts[i] * (10 ** (decimals() - tokenDecimals));

				// Add the value of collateral, denominated in the same decimals as the vault's asset
				assetBalance += normalizedAmount * price / DECIMAL_PRECISION;
			}
		}
        return assetBalance;
    }

	// --- External Depositor Functions ---

	/*
	 * @notice Used to provide debt tokens to the stability Pool
	 * @dev Triggers a LNDR issuance, based on time passed since the last issuance.
	 * The LNDR issuance is shared between *all* depositors
	 * - Sends depositor's accumulated gains (LNDR, collateral assets) to depositor
	 * - Increases deposit stake, and takes new snapshots for each.
	 * @param _amount amount of debtToken provided
	 * @param _assets an array of collaterals to be claimed. 
	 * Skipping a collateral forfeits the available rewards (can be useful for gas optimizations)
	 */

    function _deposit(
		address _caller,
		address _receiver,
		uint256 _assets,
		uint256 _shares) internal virtual override {
		super._deposit(_caller, _receiver, _assets, _shares);
		updateReward(_caller);
	}

    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assets,
        uint256 _shares
    ) internal virtual override {
		super._withdraw(_caller, _receiver, _owner, _assets, _shares);
		updateReward(_owner);
	}

	// ----  BAMM functionalities
    function getSwapCollateralAmount(address collateral, uint debtTokenAmount) external view override returns(uint collateralAmount, uint feeAmount) {
        // uint lusdBalance = SP.getCompoundedLUSDDeposit(address(this));
        // uint ethBalance  = SP.getDepositorETHGain(address(this)).add(address(this).balance);

        // uint eth2usdPrice = fetchPrice();
        // if(eth2usdPrice == 0) return (0, 0); // chainlink is down

        // uint ethUsdValue = ethBalance.mul(eth2usdPrice) / PRECISION;
        // uint maxReturn = addBps(lusdQty.mul(PRECISION) / eth2usdPrice, int(maxDiscount));

        // uint xQty = lusdQty;
        // uint xBalance = lusdBalance;
        // uint yBalance = lusdBalance.add(ethUsdValue.mul(2));
        
        // uint usdReturn = getReturn(xQty, xBalance, yBalance, A);
        // uint basicEthReturn = usdReturn.mul(PRECISION) / eth2usdPrice;

        // basicEthReturn = compensateForLusdDeviation(basicEthReturn);

        // if(ethBalance < basicEthReturn) basicEthReturn = ethBalance; // cannot give more than balance 
        // if(maxReturn < basicEthReturn) basicEthReturn = maxReturn;

        // ethAmount = basicEthReturn;
        // feeLusdAmount = addBps(lusdQty, int(fee)).sub(lusdQty);
    }

    // get ETH in return to LUSD
    function swap(uint lusdAmount, uint minEthReturn, address payable dest) external override returns(uint) {
        // (uint ethAmount, uint feeAmount) = getSwapEthAmount(lusdAmount);

        // require(ethAmount >= minEthReturn, "swap: low return");

        // LUSD.transferFrom(msg.sender, address(this), lusdAmount);
        // SP.provideToSP(lusdAmount.sub(feeAmount), frontEndTag);

        // if(feeAmount > 0) LUSD.transfer(feePool, feeAmount);
        // (bool success, ) = dest.call{ value: ethAmount }(""); // re-entry is fine here
        // require(success, "swap: sending ETH failed");

        // emit RebalanceSwap(msg.sender, lusdAmount, ethAmount, now);

        // return ethAmount;

		return 0;
    }


    function _transfer(address _from, address _to, uint256 _amount) internal virtual override {
		super._transfer(_from, _to, _amount);
		
		if (_from != address(0)) updateReward(_from);
        if (_to != address(0)) updateReward(_to);
    }

	function  _transferAsset(address _from, address _to, uint256 _amountAsset) internal {
		uint256 _amountShare = convertToShares(_amountAsset);
		_transfer(_from, _to, _amountShare);

		if (_from != address(0)) updateReward(_from);
        if (_to != address(0)) updateReward(_to);
	}

	function transferAsset(address _to, uint256 _amountAsset) external {
		_transferAsset(msg.sender, _to, _amountAsset);
	}
	
    function rewardPerToken() public view returns (uint256) {
        if (totalAssets() == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (getRewardRatio() * (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalAssets();
    }

    function earned(address _account) public view returns (uint256) {
        return ((balanceOf(_account) * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) + rewards[_account];
    }
	
	function claimReward() external	override {
		updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            ICommunityIssuance(communityIssuance).vestReward(msg.sender, reward);
            emit RewardClaimed(msg.sender, reward, block.timestamp);
        }
    }

    function refreshReward(address _account) external {
		updateReward(_account);
	}

	function setRewardsDuration(uint256 _duration) external onlyOwner {
        require(finishAt < block.timestamp, "reward duration not finished");
        rewardDuration = _duration;
    }

	function setFinishAt() external onlyOwner {
		finishAt = block.timestamp + rewardDuration;
	}

	function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(finishAt, block.timestamp);
    }

	function getRewardRatio() public view returns (uint256) {
		return ICommunityIssuance(communityIssuance).getRewardRatio(address(this));
	}

	function getAPY() external view returns (uint256) {
		return rewardPerToken() * 86400 * 365;
	}

	// --- Liquidation functions ---

	/**
	 * @notice sets the offset for liquidation
	 * @dev Cancels out the specified debt against the debtTokens contained in the StakedDebtToken (as far as possible)
	 * and transfers the Vessel's collateral from ActivePool to StakedDebtToken.
	 * Only called by liquidation functions in the VesselManager.
	 * @param _debtToOffset how much debt to offset
	 * @param _asset token address
	 * @param _amountAdded token amount as uint256
	 */
	function offset(uint256 _debtToOffset, address _asset, uint256 _amountAdded) external override onlyVesselManager {
		// _triggerLNDRIssuance();
		_moveOffsetCollAndDebt(_asset, _amountAdded, _debtToOffset);
		updateReward(msg.sender);
	}

	/**
	 * @notice Internal function to move offset collateral and debt between pools.
	 * @dev Cancel the liquidated debtToken debt with the debtTokens in the stability pool,
	 * Burn the debt that was successfully offset. Collateral is moved from
	 * the ActivePool to this contract.
	 * @param _collateral collateral address
	 * @param _amount amount as uint256
	 * @param _debtToOffset uint256
	 */
	function _moveOffsetCollAndDebt(address _collateral, uint256 _amount, uint256 _debtToOffset) internal {
		IActivePool(activePool).decreaseDebt(_collateral, _debtToOffset);
		IDebtToken(debtToken).burn(address(this), _debtToOffset);
		IActivePool(activePool).sendAsset(_collateral, address(this), _amount);
		
		emit StakedDebtTokenDebtTokenBalanceUpdated(totalAssets());
	}

	function updateReward(address _account) internal {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
            userUpdatedAt[_account] = block.timestamp;
        }
    }

	// --- Modifiers ---

	modifier onlyAdminContract() {
		if (msg.sender != adminContract) {
			revert StakedDebtToken__AdminContractOnly(msg.sender, adminContract);
		}
		_;
	}

	modifier onlyActivePool() {
		if (msg.sender != activePool) {
			revert StakedDebtToken__ActivePoolOnly(msg.sender, activePool);
		}
		_;
	}

	modifier onlyVesselManager() {
		if (msg.sender != vesselManager) {
			revert StakedDebtToken__VesselManagerOnly(msg.sender, vesselManager);
		}
		_;
	}

	// --- Fallback function ---

	function receivedERC20(address _asset, uint256 _amount) external override onlyActivePool {
		uint256 collateralIndex = IAdminContract(adminContract).getIndex(_asset);
		uint256 newAssetBalance = totalColl.amounts[collateralIndex] + _amount;
		totalColl.amounts[collateralIndex] = newAssetBalance;
		emit StakedDebtTokenAssetBalanceUpdated(_asset, newAssetBalance);
	}


	function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }

	function authorizeUpgrade(address newImplementation) public {
		_authorizeUpgrade(newImplementation);
	}

	function _authorizeUpgrade(address) internal override onlyOwner {}
}