// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IRWAPriceFeed {

    // --- Events ---
    event LastRWAPriceUpdated(address _rwaToken, uint _lastRWAPrice);
   
    // --- Function ---
    function updateRWAPrice(address _rwaToken) external;

    function getRWAPrice(address _rwaToken) external view returns (uint256);

    function getCurrentIndex(address _rwaToken) external view returns (uint256);
}