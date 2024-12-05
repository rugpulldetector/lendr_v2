// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "../FeeCollector.sol";

contract FeeCollectorTester is FeeCollector {

	bool public __routeToLNDRStaking;

	function calcNewDuration(
		uint256 remainingAmount,
		uint256 remainingTimeToLive,
		uint256 addedAmount
	) external pure returns (uint256) {
		return _calcNewDuration(remainingAmount, remainingTimeToLive, addedAmount);
	}

	function setRouteToLNDRStaking(bool ___routeToLNDRStaking) external onlyOwner {
		__routeToLNDRStaking = ___routeToLNDRStaking;
	}

	function _routeToLNDRStaking() internal view override returns (bool) {
		return __routeToLNDRStaking;
	}
}
