// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../Interfaces/IPriceFeed.sol";
import "../Dependencies/AggregatorV3Interface.sol";
interface ICompositePriceFeed is IPriceFeed {
    function ethUsdOracle() external view returns (AggregatorV3Interface, uint256, uint8);
    function lstEthOracle() external view returns (AggregatorV3Interface, uint256, uint8);
}