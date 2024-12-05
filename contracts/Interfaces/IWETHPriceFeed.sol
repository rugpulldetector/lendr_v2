// SPDX-License-Identifier: MIT
import "./IPriceFeed.sol";
import "../Dependencies/AggregatorV3Interface.sol";

pragma solidity ^0.8.19;

interface IWETHPriceFeed is IPriceFeed {
    function getEthUsdOracle() external view returns (AggregatorV3Interface, uint256, uint8);
}