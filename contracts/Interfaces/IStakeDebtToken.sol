// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./IDeposit.sol";

interface IStakeDebtToken is IDeposit {
	
	// --- Events ---

	event CommunityIssuanceSet(address indexed oldCommunityIssurance, address indexed newCommunityIssurance);
	event DepositSnapshotUpdated(address indexed _depositor, uint256 _P, uint256 _G);
	event SystemSnapshotUpdated(uint256 _P, uint256 _G);

	event AssetSent(address _asset, address _to, uint256 _amount);
	event GainsWithdrawn(address indexed _depositor, address[] _collaterals, uint256[] _amounts, uint256 _debtTokenLoss);
	event LNDRPaidToDepositor(address indexed _depositor, uint256 _LNDR);
	event StakeDebtTokenAssetBalanceUpdated(address _asset, uint256 _newBalance);
	event StakeDebtTokenDebtTokenBalanceUpdated(uint256 _newBalance);
	event StakeChanged(uint256 _newSystemStake, address _depositor);
	event UserDepositChanged(address indexed _depositor, uint256 _newDeposit);

	event P_Updated(uint256 _P);
	event S_Updated(address _asset, uint256 _S, uint128 _epoch, uint128 _scale);
	event G_Updated(uint256 _G, uint128 _epoch, uint128 _scale);
	event EpochUpdated(uint128 _currentEpoch);
	event ScaleUpdated(uint128 _currentScale);

	// --- Errors ---

	error StakeDebtToken__ActivePoolOnly(address sender, address expected);
	error StakeDebtToken__AdminContractOnly(address sender, address expected);
	error StakeDebtToken__VesselManagerOnly(address sender, address expected);
	error StakeDebtToken__ArrayNotInAscendingOrder();

	/*
	Initial checks:
	 * - Caller is VesselManager
	 * ---
	 * Cancels out the specified debt against the debt token contained in the Stability Pool (as far as possible)
	 * and transfers the Vessel's collateral from ActivePool to StakeDebtToken.
	 * Only called by liquidation functions in the VesselManager.
	 */
	function offset(uint256 _debt, address _asset, uint256 _coll) external;

}
