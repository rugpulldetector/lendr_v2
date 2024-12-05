// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface ILNDRStaking {
	// Events -----------------------------------------------------------------------------------------------------------

	event TreasuryAddressChanged(address _treausury);
	event SentToTreasury(address indexed _asset, uint256 _amount);

	event StakeChanged(address indexed staker, uint256 newStake);
	event StakingGainsAssetWithdrawn(
		address indexed staker,
		address indexed asset,
		uint256 AssetGain
	);
	event StakingGainsDebtTokensWithdrawn(address indexed staker, uint256 debtTokenAmount);
	event Fee_AssetUpdated(address indexed _asset, uint256 _amount);
	event Fee_DebtTokenUpdated(uint256 _amount);
	event TotalLNDRStakedUpdated(uint256 _totalLNDRStaked);
	event AssetSent(address indexed _asset, address indexed _account, uint256 _amount);
	event StakerSnapshotsUpdated(address _staker, uint256 _F_Asset, uint256 _F_DebtToken);

	// Functions --------------------------------------------------------------------------------------------------------

	function lndrToken() external view returns (IERC20Upgradeable);

	function stake(uint256 _LNDRamount) external;

	function unstake(uint256 _LNDRamount) external;

	function increaseFee_Collateral(address _asset, uint256 _AssetFee) external;

	function increaseFee_DebtToken(address _debt, uint256 _LNDRFee) external;

	function getPendingAssetGain(address _asset, address _user) external view returns (uint256);

	function getPendingDebtTokenGain(address _user) external view returns (uint256);
}
