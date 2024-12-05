// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "../Interfaces/IInflationFeed.sol";

/*
* PriceFeed placeholder for testnet and development. The price is simply set manually and saved in a state 
* variable. The contract does not connect to a live Chainlink price feed. 
*/
contract InflationFeedTester is IInflationFeed {
    
    uint256 public targetPeg = 1e18;
    uint256 public currentIndex = 1e18; // For UI test
    bool public initialized = true;
    // --- Functions ---

    // View price getter for simplicity in tests
    function getTargetPeg() external view override returns (uint256) {
        return targetPeg;
    }

    function getCurrentIndex() external view override returns (uint256) {
        return currentIndex;
    }

    function getInitialized() external view override returns (bool) {
        return initialized;
    }

    // Manual external targetPeg setter.
    function setTargetPeg(uint256 _targetPeg) external returns (bool) {
        targetPeg = _targetPeg;
        return true;
    }

    function updateTargetPeg() external override {
        emit LastTargetPegUpdated(targetPeg);
    }
}
