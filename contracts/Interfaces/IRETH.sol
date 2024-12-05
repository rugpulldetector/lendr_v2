// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IRETH {
    function getExchangeRate() external view returns (uint256);
}