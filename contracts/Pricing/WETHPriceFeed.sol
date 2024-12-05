// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../Interfaces/IWETH.sol";

// import "forge-std/console2.sol";

contract WETHPriceFeed is AggregatorV3Interface {
    int256 internal constant PRECISION = 1 ether;

    IWETH public immutable wETH;
	AggregatorV3Interface public immutable eth2USDAggregator;
    constructor(address _wETHAddress, address _eth2USDAggregatorAddress) {
        wETH = IWETH(_wETHAddress);
		eth2USDAggregator = AggregatorV3Interface(_eth2USDAggregatorAddress);
	}

    // AggregatorV3Interface functions ----------------------------------------------------------------------------------

	function decimals() external view override returns (uint8) {
		return eth2USDAggregator.decimals();
	}

	function description() external pure override returns (string memory) {
		return "WEth2UsdPriceAggregator";
	}

	function getRoundData(uint80 _roundId)
		external
		view
		override
		returns (
			uint80 roundId,
			int256 answer,
			uint256 startedAt,
			uint256 updatedAt,
			uint80 answeredInRound
		)
	{
		(roundId, answer, startedAt, updatedAt, answeredInRound) = eth2USDAggregator.getRoundData(_roundId);
	}

    function latestRoundData()
		external
		view
		override
		returns (
			uint80 roundId,
			int256 answer,
			uint256 startedAt,
			uint256 updatedAt,
			uint80 answeredInRound
		)
	{
		(roundId, answer, startedAt, updatedAt, answeredInRound) = eth2USDAggregator.latestRoundData();
	}
    
	function version() external pure override returns (uint256) {
		return 1;
	}
}
