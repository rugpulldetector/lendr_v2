// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./Dependencies/LendrBase.sol";
import "./Dependencies/SafetyTransfer.sol";
import "./Interfaces/IStakeDebtToken.sol";
import "./Interfaces/IDebtToken.sol";
import "./Interfaces/IVesselManager.sol";
import "./Interfaces/ICommunityIssuance.sol";

contract StakedDebtToken is ERC4626Upgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable, LendrBase, IStakeDebtToken {
	using SafeERC20Upgradeable for IERC20Upgradeable;

	// Tracker for debtToken held in the pool. Changes when users deposit/withdraw, and when Vessel debt is offset.
	uint256 internal totalDebtTokenDeposits;

	// totalColl.tokens and totalColl.amounts should be the same length and
	// always be the same length as IAdminContract(adminContract).validCollaterals().
	// Anytime a new collateral is added to AdminContract, both lists are lengthened
	Colls internal totalColl;

	mapping(address => uint256) internal userRewardPerTokenPaid;

	uint256 internal rewardPerTokenStored;

	address public communityIssuanceAddr;
	uint256 public rewardRatio;
	
    // User address => rewards to be claimed
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userUpdatedAt;

	uint256 public updatedAt; // reward updated at
	uint256 public finishAt; // reward distribution finish time
	uint256 public rewardDuration; // reward distribution Duration
	
	/// @notice Emitted when a beneficiary claims their earned reward.
	event RewardClaimed(address indexed beneficiary, uint256 amount, uint256 timeStamp);

	/// @notice Emitted when this contract is notified of a new reward.
	event RewardNotified(uint256 amount, address notifier);

	// --- Initializer ---

	function initialize(address underlyingToken) public initializer {
		string memory name = string.concat("Staked ", IERC20Metadata(underlyingToken).name());
		string memory symbol = string.concat("S", IERC20Metadata(underlyingToken).symbol());

		__Ownable_init();
		__ERC20_init(name, symbol);
		__ERC4626_init(IERC20Upgradeable(underlyingToken));
		__ReentrancyGuard_init();
		__UUPSUpgradeable_init();
	}

	function setCommunityIssurance(address _communityIssuance) external onlyAdminContract {
		require(_communityIssuance != address(0), "Non-zero addresss");
		communityIssuanceAddr = _communityIssuance;
	}

	/**
	 * @notice add a collateral
	 * @dev should be called anytime a collateral is added to controller
	 * keeps all arrays the correct length
	 * @param _collateral address of collateral to add
	 */
	function addCollateralType(address _collateral) external onlyAdminContract {
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

	function totalAssets() public view virtual override returns (uint256) {
        return IERC20Upgradeable(asset()).balanceOf(address(this));
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
		uint256 _shares) internal virtual override updateReward(_caller)
	{
		super._deposit(_caller, _receiver, _assets, _shares);
	}

    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assets,
        uint256 _shares
    ) internal virtual override updateReward(_owner) {
		super._withdraw(_caller, _receiver, _owner, _assets, _shares);
	}

	// ----  BAMM functionalities
    function getSwapCollateralAmount(address collateral, uint debtTokenAmount) public view returns(uint collateralAmount, uint feeAmount) {
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
    function swap(uint lusdAmount, uint minEthReturn, address payable dest) public returns(uint) {
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

	// ----  Staking & Unstaking Mechanism

    function _transfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
		super._transfer(_sender, _recipient, _amount);

        // if (_sender != address(0))
		// 	updateReward(_sender);
        // if (_recipient != address(0))
		// 	updateReward(_recipient);
    }
	
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored + (rewardRatio * (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalSupply();
    }

    function earned(address _account) public view returns (uint256) {
        return ((balanceOf(_account) * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) + rewards[_account];
    }
	
	function claimReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            ICommunityIssuance(communityIssuanceAddr).mint(msg.sender, reward);
            emit RewardClaimed(msg.sender, reward, block.timestamp);
        }
    }

    function refreshReward(address _account) external updateReward(_account) {}

	
	function setRewardsDuration(uint256 _duration) external onlyOwner {
        require(finishAt < block.timestamp, "reward duration not finished");
        rewardDuration = _duration;
    }

	function lastTimeRewardApplicable() internal view returns(uint256) {
		return block.timestamp;
	}

	// --- Liquidation functions ---

	/**
	 * @notice sets the offset for liquidation
	 * @dev Cancels out the specified debt against the debtTokens contained in the Stability Pool (as far as possible)
	 * and transfers the Vessel's collateral from ActivePool to StakeDebtToken.
	 * Only called by liquidation functions in the VesselManager.
	 * @param _debtToOffset how much debt to offset
	 * @param _asset token address
	 * @param _amountAdded token amount as uint256
	 */
	function offset(uint256 _debtToOffset, address _asset, uint256 _amountAdded) external onlyVesselManager {
		// _triggerLNDRIssuance();
		_moveOffsetCollAndDebt(_asset, _amountAdded, _debtToOffset);
	}

	/**
	 * @notice Internal function to move offset collateral and debt between pools.
	 * @dev Cancel the liquidated debtToken debt with the debtTokens in the stability pool,
	 * Burn the debt that was successfully offset. Collateral is moved from
	 * the ActivePool to this contract.
	 * @param _asset collateral address
	 * @param _amount amount as uint256
	 * @param _debtToOffset uint256
	 */
	function _moveOffsetCollAndDebt(address _asset, uint256 _amount, uint256 _debtToOffset) internal {
		IActivePool(activePool).decreaseDebt(_asset, _debtToOffset);
		_decreaseDebtTokens(_debtToOffset);
		IDebtToken(debtToken).burn(address(this), _debtToOffset);
		IActivePool(activePool).sendAsset(_asset, address(this), _amount);
	}

	function _decreaseDebtTokens(uint256 _amount) internal {
		uint256 newTotalDeposits = totalDebtTokenDeposits - _amount;
		totalDebtTokenDeposits = newTotalDeposits;
		emit StakeDebtTokenDebtTokenBalanceUpdated(newTotalDeposits);
	}


	// --- Modifiers ---

	modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
            userUpdatedAt[_account] = block.timestamp;
        }
        _;
    }

	modifier onlyAdminContract() {
		if (msg.sender != adminContract) {
			revert StakeDebtToken__AdminContractOnly(msg.sender, adminContract);
		}
		_;
	}

	modifier onlyActivePool() {
		if (msg.sender != activePool) {
			revert StakeDebtToken__ActivePoolOnly(msg.sender, activePool);
		}
		_;
	}

	modifier onlyVesselManager() {
		if (msg.sender != vesselManager) {
			revert StakeDebtToken__VesselManagerOnly(msg.sender, vesselManager);
		}
		_;
	}

	// --- Fallback function ---

	function receivedERC20(address _asset, uint256 _amount) external override onlyActivePool {
		uint256 collateralIndex = IAdminContract(adminContract).getIndex(_asset);
		uint256 newAssetBalance = totalColl.amounts[collateralIndex] + _amount;
		totalColl.amounts[collateralIndex] = newAssetBalance;
		emit StakeDebtTokenAssetBalanceUpdated(_asset, newAssetBalance);
	}

	function authorizeUpgrade(address newImplementation) public {
		_authorizeUpgrade(newImplementation);
	}

	function _authorizeUpgrade(address) internal override onlyOwner {}
}