// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IOracleFeed {
   function fetchPrice(address _collateralToken, address _rwaToken) external view returns (uint256);
}