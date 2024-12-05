// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

//import "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import "./IDeposit.sol";


interface IStakedDebtToken is IDeposit {
	
	// --- Events ---

	event StakedDebtTokenAssetBalanceUpdated(address _asset, uint256 _newBalance);
	event StakedDebtTokenDebtTokenBalanceUpdated(uint256 _newBalance);

	/// @notice Emitted when a beneficiary claims their earned reward.
	event RewardClaimed(address indexed beneficiary, uint256 amount, uint256 timeStamp);

	// --- Errors ---

	error StakedDebtToken__ActivePoolOnly(address sender, address expected);
	error StakedDebtToken__AdminContractOnly(address sender, address expected);
	error StakedDebtToken__VesselManagerOnly(address sender, address expected);

	/*
	Initial checks:
	 * - Caller is VesselManager
	 * ---
	 * Cancels out the specified debt against the debt token contained in the Stability Pool (as far as possible)
	 * and transfers the Vessel's collateral from ActivePool to StakedDebtToken.
	 * Only called by liquidation functions in the VesselManager.
	 */

	function addCollateralType(address _collateral) external;

	function getSwapCollateralAmount(address collateral, uint debtTokenAmount) external view returns(uint collateralAmount, uint feeAmount);
	function swap(uint lusdAmount, uint minEthReturn, address payable dest) external returns(uint);
	function offset(uint256 _debt, address _asset, uint256 _coll) external;
	function claimReward() external;
	function refreshReward(address _account) external;
	function transferAsset(address _to, uint256 _amountAsset) external;
}
