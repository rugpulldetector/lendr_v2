// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface ICommunityIssuance {
	// --- Events ---

	event TotalLNDRIssuedUpdated(uint256 _totalLNDRIssued);

	event LNDRIssuedUpdated(address indexed _stakedDebtToken, uint256 _totalLNDRIssued);

	// --- Functions ---

	function issueLNDR() external returns (uint256);

	// function sendLNDR(address _account, uint256 _LNDRamount) external;

	// function addFundToStakedDebtToken(uint256 _assignedSupply) external;

	// function addFundToStakedDebtTokenFrom(uint256 _assignedSupply, address _spender) external;

	// function setWeeklyLndrDistribution(uint256 _weeklyReward) external;

	function vestReward(address _to, uint256 _amount) external;

	function getRewardRatio(address _stakedDebtToken) external view returns (uint256);
}
