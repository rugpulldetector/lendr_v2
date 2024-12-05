// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import "../LNDR/LNDRStaking.sol";

contract LNDRStakingTester is LNDRStaking {
	function requireCallerIsVesselManager() external view callerIsVesselManager {}
}
