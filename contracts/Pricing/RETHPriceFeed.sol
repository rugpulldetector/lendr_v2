// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../Interfaces/IRETH.sol";

// import "forge-std/console2.sol";

contract RETHPriceFeed is AggregatorV3Interface {
    int256 internal constant PRECISION = 1 ether;

    IRETH public immutable rETH;
	AggregatorV3Interface public immutable eth2USDAggregator;
    constructor(address _rETHAddress, address _eth2USDAggregatorAddress) {
		rETH = IRETH(_rETHAddress);
		eth2USDAggregator = AggregatorV3Interface(_eth2USDAggregatorAddress);
	}

    // AggregatorV3Interface functions ----------------------------------------------------------------------------------

	function decimals() external view override returns (uint8) {
		return eth2USDAggregator.decimals();
	}

	function description() external pure override returns (string memory) {
		return "REth2UsdPriceAggregator";
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
        answer = _wETH2rETH(answer);
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
        answer = _wETH2rETH(answer);
	}
    
	function version() external pure override returns (uint256) {
		return 1;
	}
    
    // Internal/Helper functions ----------------------------------------------------------------------------------------

	function _wETH2rETH(int256 wETHValue) internal view returns (int256) {
		require(wETHValue > 0, "stETH value cannot be zero");
        int256 multiplier = int256(IRETH(rETH).getExchangeRate());
		return (wETHValue * multiplier) / PRECISION;
	}
}
