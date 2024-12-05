// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../Dependencies/BaseMath.sol";
import "../Dependencies/LendrMath.sol";
import "../Dependencies/SafetyTransfer.sol";

import "../Interfaces/IDeposit.sol";
import "../Interfaces/IDebtToken.sol";
import "../Interfaces/IAddressesConfigurable.sol";
import "../Interfaces/ILNDRStaking.sol";
import "hardhat/console.sol";

contract LNDRStaking is ILNDRStaking, UUPSUpgradeable, PausableUpgradeable, OwnableUpgradeable, BaseMath, ReentrancyGuardUpgradeable {
	using SafeERC20Upgradeable for IERC20Upgradeable;

	// --- Data ---
	string public constant NAME = "LNDRStaking";
	address constant ETH_REF_ADDRESS = address(0);

	mapping(address => uint256) public stakes;
	uint256 public totalLNDRStaked;

	mapping(address => uint256) public F_ASSETS; // Running sum of asset fees per-LNDR-staked
	uint256 public F_DEBT_TOKENS; // Running sum of debt token fees per-LNDR-staked

	// User snapshots of F_ASSETS and F_DEBT_TOKENS, taken at the point at which their latest deposit was made
	mapping(address => Snapshot) public snapshots;

	struct Snapshot {
		mapping(address => uint256) F_ASSETS_Snapshot;
		uint256 F_DEBT_TOKENS_Snapshot;
	}

	address[] public collateralTokens;
	address[] public debtTokens;

	mapping(address => bool) public isCollateralToken;
	mapping(address => bool) public isDebtToken;
	mapping(address => bool) public isAdminContract;
	mapping(address => bool) public isFeeCollector;
	mapping(address => bool) public isVesselManager;
	
	mapping(address => uint256) public sentToTreasuryTracker;

	IERC20Upgradeable public override lndrToken;
	address public treasuryAddress;

	bool public isSetupInitialized;


	// --- Initializer ---

	function initialize() public initializer {
		__Ownable_init();
		__ReentrancyGuard_init();
		__Pausable_init();
		_pause();
	}

	// --- Functions ---
	function setAddresses(
		address _lndrTokenAddress,
		address _treasuryAddress
	) external onlyOwner {
		require(!isSetupInitialized, "Setup is already initialized");

		lndrToken = IERC20Upgradeable(_lndrTokenAddress);
		treasuryAddress = _treasuryAddress;
		isSetupInitialized = true;
	}

	function addAdminContract(
		address _adminContract
	) external onlyOwner {
		address _debt = IAddressesConfigurable(_adminContract).debtToken();
		address _feeCollector = IAddressesConfigurable(_adminContract).feeCollector();
		address _vesselManager = IAddressesConfigurable(_adminContract).vesselManager();

		require(isDebtToken[_debt] == false, "Already registerd debt token");
		debtTokens.push(_debt);

		isAdminContract[_adminContract] = true;
		isDebtToken[_debt] = true;
		isFeeCollector[_feeCollector] = true;
		isVesselManager[_vesselManager] = true;
	}

	// If caller has a pre-existing stake, send any accumulated asset and debtToken gains to them.
	function stake(uint256 _LNDRamount) external override nonReentrant whenNotPaused {
		require(_LNDRamount > 0);

		// harvest pending gains
		// _harvestGains();

		uint256 currentStake = stakes[msg.sender];
		uint256 newStake = currentStake + _LNDRamount;

		// // Increase user’s stake and total LNDR staked
		stakes[msg.sender] = newStake;
		totalLNDRStaked = totalLNDRStaked + _LNDRamount;
		emit TotalLNDRStakedUpdated(totalLNDRStaked);

		// Transfer LNDR from caller to this contract
		lndrToken.transferFrom(msg.sender, address(this), _LNDRamount);

		// emit StakeChanged(msg.sender, newStake);
	}

	// Unstake the LNDR and send the it back to the caller, along with their accumulated gains.
	// If requested amount > stake, send their entire stake.
	function unstake(uint256 _LNDRamount) external override nonReentrant {
		uint256 currentStake = stakes[msg.sender];
		_requireUserHasStake(currentStake);

		// // harvest pending gains
		// _harvestGains();

		if (_LNDRamount > 0) {
			uint256 LNDRToWithdraw = LendrMath._min(_LNDRamount, currentStake);
			uint256 newStake = currentStake - LNDRToWithdraw;

			// Decrease user's stake and total LNDR staked
			stakes[msg.sender] = newStake;
			totalLNDRStaked = totalLNDRStaked - LNDRToWithdraw;
			emit TotalLNDRStakedUpdated(totalLNDRStaked);

			// Transfer unstaked LNDR to user
			IERC20Upgradeable(address(lndrToken)).safeTransfer(msg.sender, LNDRToWithdraw);
			emit StakeChanged(msg.sender, newStake);
		}
	}

	function _harvestGains() internal {
		uint256 currentStake = stakes[msg.sender];
		if (currentStake != 0) {
			uint256 collateralLength = collateralTokens.length;
			for (uint256 i = 0; i < collateralLength; i++) {
				address collateral = collateralTokens[i];
				uint256 gain = _getPendingAssetGain(collateral, msg.sender);

				_sendAssetGainToUser(collateral, gain);
				emit StakingGainsAssetWithdrawn(msg.sender, collateral, gain);
				_updateUserSnapshots(collateral, msg.sender);
			}

			uint256 debtLength = debtTokens.length;
			for (uint256 i = 0; i < debtLength; i++) {
				address debt = debtTokens[i];
				uint256 gain = _getPendingDebtTokenGain(msg.sender);

				IERC20Upgradeable(debt).safeTransfer(msg.sender, gain);
				emit StakingGainsDebtTokensWithdrawn(msg.sender, gain);
				_updateUserSnapshots(debt, msg.sender);
			}
		}
	}

	function pause() public onlyOwner {
		_pause();
	}

	function unpause() public onlyOwner {
		_unpause();
	}

	// --- Reward-per-unit-staked increase functions. Called by Lendr core contracts ---

	function increaseFee_Collateral(address _asset, uint256 _assetFee) external override callerIsVesselManager {
		if (paused()) {
			sendToTreasury(_asset, _assetFee);
			return;
		}

		if (!isCollateralToken[_asset]) {
			isCollateralToken[_asset] = true;
			collateralTokens.push(_asset);
		}

		uint256 assetFeePerLNDRStaked;

		if (totalLNDRStaked > 0) {
			assetFeePerLNDRStaked = (_assetFee * DECIMAL_PRECISION) / totalLNDRStaked;
		}

		F_ASSETS[_asset] = F_ASSETS[_asset] + assetFeePerLNDRStaked;
		emit Fee_AssetUpdated(_asset, F_ASSETS[_asset]);
	}

	function increaseFee_DebtToken(address _debt, uint256 _debtTokenFee) external override callerIsFeeCollector {
		if (paused()) {
			sendToTreasury(_debt, _debtTokenFee);
			return;
		}

		uint256 feePerLNDRStaked;
		if (totalLNDRStaked > 0) {
			feePerLNDRStaked = (_debtTokenFee * DECIMAL_PRECISION) / totalLNDRStaked;
		}

		F_DEBT_TOKENS = F_DEBT_TOKENS + feePerLNDRStaked;
		emit Fee_DebtTokenUpdated(F_DEBT_TOKENS);
	}

	function sendToTreasury(address _asset, uint256 _amount) internal {
		_sendAsset(treasuryAddress, _asset, _amount);
		sentToTreasuryTracker[_asset] += _amount;
		emit SentToTreasury(_asset, _amount);
	}

	// --- Pending reward functions ---

	function getPendingAssetGain(address _asset, address _user) external view override returns (uint256) {
		return _getPendingAssetGain(_asset, _user);
	}

	function _getPendingAssetGain(address _asset, address _user) internal view returns (uint256) {
		uint256 F_ASSET_Snapshot = snapshots[_user].F_ASSETS_Snapshot[_asset];
		uint256 AssetGain = (stakes[_user] * (F_ASSETS[_asset] - F_ASSET_Snapshot)) / DECIMAL_PRECISION;
		return AssetGain;
	}

	function getPendingDebtTokenGain(address _user) external view override returns (uint256) {
		return _getPendingDebtTokenGain(_user);
	}

	function _getPendingDebtTokenGain(address _user) internal view returns (uint256) {
		uint256 debtTokenSnapshot = snapshots[_user].F_DEBT_TOKENS_Snapshot;
		return (stakes[_user] * (F_DEBT_TOKENS - debtTokenSnapshot)) / DECIMAL_PRECISION;
	}

	// --- Internal helper functions ---

	function _updateUserSnapshots(address _asset, address _user) internal {
		snapshots[_user].F_ASSETS_Snapshot[_asset] = F_ASSETS[_asset];
		snapshots[_user].F_DEBT_TOKENS_Snapshot = F_DEBT_TOKENS;
		emit StakerSnapshotsUpdated(_user, F_ASSETS[_asset], F_DEBT_TOKENS);
	}

	function _sendAssetGainToUser(address _asset, uint256 _assetGain) internal {
		_assetGain = SafetyTransfer.decimalsCorrection(_asset, _assetGain);
		_sendAsset(msg.sender, _asset, _assetGain);
		emit AssetSent(_asset, msg.sender, _assetGain);
	}

	function _sendAsset(address _sendTo, address _asset, uint256 _amount) internal {
		IERC20Upgradeable(_asset).safeTransfer(_sendTo, _amount);
	}

	// --- 'require' functions ---

	modifier callerIsVesselManager() {
		require(isVesselManager[msg.sender], "LNDRStaking: caller is not VesselManager");
		_;
	}

	modifier callerIsFeeCollector() {
		require(isFeeCollector[msg.sender], "LNDRStaking: caller is not FeeCollector");
		_;
	}

	function _requireUserHasStake(uint256 currentStake) internal pure {
		require(currentStake > 0, "LNDRStaking: User must have a non-zero stake");
	}

	function authorizeUpgrade(address newImplementation) public {
		_authorizeUpgrade(newImplementation);
	}

	function _authorizeUpgrade(address) internal override onlyOwner {}
}
