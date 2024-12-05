// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "../LNDR/CommunityIssuance.sol";

contract CommunityIssuanceTester is CommunityIssuance {

	function obtainLNDR(uint256 _amount) external {
		lndrToken.transfer(msg.sender, _amount);
	}

	// function getLastUpdateTokenDistribution() external view returns (uint256) {
	// 	return _getLastUpdateTokenDistribution();
	// }

	// function unprotectedIssueLNDR() external returns (uint256) {
	// 	return issueLNDR();
	// }
}
