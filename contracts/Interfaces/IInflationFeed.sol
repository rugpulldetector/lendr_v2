// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IInflationFeed {

    // --- Events ---
    event LastTargetPegUpdated(uint _lastTargetPeg);
   
    // --- Function ---
    function updateTargetPeg() external;

    function getTargetPeg() external view returns (uint256);

    function getInitialized() external view returns (bool);

    function getCurrentIndex() external view returns (uint256);
}
