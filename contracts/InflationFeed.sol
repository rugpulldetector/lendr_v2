// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

import "./Dependencies/BaseMath.sol";
import "./Interfaces/IInflationFeed.sol";

/*
* InflationFeed uses Chainlink based oracle to get US CPI
*/
contract InflationFeed is BaseMath, OwnableUpgradeable, UUPSUpgradeable, ChainlinkClient, IInflationFeed {
    using Chainlink for Chainlink.Request;
    
    string constant public NAME = "InflationFeed";

    // Target peg variables
    // Last index used to calculate the peg
    bool public initialized;
    uint256 public startingIndex;
    uint256 public currentIndex;

    // Initial peg
    uint constant public TARGET_DIGITS = 18;  
    uint256 public targetPeg; // 1 USD initially

    // Peg deviation maximum, 18-digit precision.
    uint256 constant public MAX_PEG_VARIANCE = 1e16; //1% This would prevent the peg from moving more than 1% in either direction
    uint256 public counter; //counter for how many times the peg has been out of range. resets to 0 when peg is in range, or when peg is out of range 7 times

    // Time of the last peg update, used to prevent multiple updates in a short time period 
    uint256 public lastUpdateTime; //block timestamp

    // Minimum time period between peg updates
    uint256 public pegUpdateDelay; // 1 day = 86400 seconds

    // Public oracle variables
    address public oracleId;
    string public jobId;
    uint256 public fee;

    // Owner delay variables
    uint256 public txWindowStart; // time now + ownerTxDelay is time when owner functions can be called
    uint256 public txWindowEnd; // End of owner functions time window
    uint256 public ownerTxDelay; // length of the window for owner functions, 3 days = 259200 seconds
    bool public isSetupInitialized;

    event oracleChanged(address _oracleId);
    event linkTokenChanged(address _token);
    event jobIdChanged(string _jobId);
    event truflationFeeChanged(uint256 _fee);
    event pegOutsideOfRange(uint256 _newPeg, uint256 _targetPeg, uint256 _counter);
    event ownerFunctionsStart(uint256 _txWindowStart, uint256 _txWindowEnd);

    // --- Initializer ---
	function initialize() public initializer {
		__Ownable_init();
        __UUPSUpgradeable_init();
        
        initialized = false;
        startingIndex = 1e18;
        currentIndex = startingIndex;
        targetPeg = 1e18; // 1 USD initially
        counter = 0;
        lastUpdateTime = block.timestamp;
        pegUpdateDelay = 1 days; // 1 day = 86400 seconds
        ownerTxDelay = 3;
        fee = 1e18;
	}


    // should be called when setting up
    function setParams(
        address _oracleId,
        string memory _jobId,
        address _token
    ) external onlyOwner { 
        require(!isSetupInitialized, "Setup is already initialized");
        setChainlinkToken(_token);
        oracleId = _oracleId;
        jobId = _jobId;
        isSetupInitialized = true;
    } 

    /*
    * updateTargetPeg(): Updates the target peg based on the current inflation index. Calls the oracle to get current data
    * if the last update was more than 24hrs ago.
    */
    function updateTargetPeg() external override {

        // Make sure there is sufficient link token to pay oracle
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.balanceOf(address(this)) >= fee, "Not enough LINK, Send 1+ LINK to InflationFeed contract");

        // limit updates to once per 24hrs
        if(shouldUpdateTargetPeg()) {
            lastUpdateTime = block.timestamp;
            requestInflationWei();
        }
    }

    function shouldUpdateTargetPeg() internal view returns (bool) {
        // if (!initialized) {
        //     require(msg.sender == owner(), "Only owner can initialize"); // Only owner so owner has time to set oracle, jobId, and fee.
        // }

        if(initialized && block.timestamp < lastUpdateTime + pegUpdateDelay){ // Not time to update the peg yet silly - wait 24hrs
            return false;
        }
        return true;
    }

    function getTargetPeg() external view override returns (uint256) {
        return targetPeg;
    }

    function getInitialized() external view override returns (bool) {
        return initialized;
    }

    function getCurrentIndex() external view override returns (uint256) {
        return currentIndex;
    }

    function getLinkToken() public view returns (address) {
        return chainlinkTokenAddress();
    }

    function requestInflationWei() internal returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            bytes32(bytes(jobId)),
            address(this),
            this.fulfillInflationWei.selector
        );
        req.add("service", "truflation/series");
        req.add("abi", "int256");
        req.add("multiplier", "1000000000000000000");
        req.add("data", '{"ids":"501","types":"114"}');
        req.add("refundTo",
            Strings.toHexString(uint160(address(this)), 20));
        return sendChainlinkRequestTo(oracleId, req, fee);
    }

    function fulfillInflationWei(
        bytes32 _requestId,
        bytes memory _inflation
    ) public recordChainlinkFulfillment(_requestId) {
        handleFulfill(uint(toInt256(_inflation)));
    }

    function handleFulfill(uint _index) internal {
        // get inflation from oracle
        currentIndex = _index;

        if(!initialized) {
            startingIndex = currentIndex;
            initialized = true;
            targetPeg = currentIndex * DECIMAL_PRECISION / startingIndex;
            return ;
        }
        // calculate new peg
        uint256 newPeg = currentIndex * DECIMAL_PRECISION / startingIndex;

        //check if new price is outside acceptable variance, moves by maximum amount if so
        //this section changed based on Certik audit result
        if (newPeg > targetPeg + targetPeg * MAX_PEG_VARIANCE / DECIMAL_PRECISION) {

            counter = counter + 1; // increment counter of how many times peg is outside of range in a row
            emit pegOutsideOfRange(newPeg, targetPeg, counter);

            // if outside of range 7 times in a row, move peg by maximum amount
            if (counter >= 7) {
                counter = 0; // reset counter
                targetPeg = targetPeg + targetPeg * MAX_PEG_VARIANCE / DECIMAL_PRECISION;
            }

            emit LastTargetPegUpdated(targetPeg);
            return ;
        }
        if (newPeg < targetPeg - targetPeg * MAX_PEG_VARIANCE / DECIMAL_PRECISION){

            counter = counter + 1; // increment counter of how many times peg is outside of range in a row
            emit pegOutsideOfRange(newPeg, targetPeg, counter);

            // if outside of range 7 times in a row, move peg by maximum amount
            if (counter >= 7) {
                counter = 0; // reset counter
                targetPeg = targetPeg - targetPeg * MAX_PEG_VARIANCE / DECIMAL_PRECISION;
            }

            emit LastTargetPegUpdated(targetPeg);
            return ;
        }

        //check if new price is outside acceptable variance
        if (newPeg <= targetPeg + targetPeg * MAX_PEG_VARIANCE / DECIMAL_PRECISION &&
            newPeg >= targetPeg - targetPeg * MAX_PEG_VARIANCE / DECIMAL_PRECISION) {

            //reset counter if peg is in normal range
            if(counter != 0) {
                counter = 0; 
            }

            //update peg
            targetPeg = newPeg;
            emit LastTargetPegUpdated(targetPeg);
        }
    }

    function toInt256(bytes memory _bytes) internal pure
        returns (int256 value) {
            assembly {
            value := mload(add(_bytes, 0x20))
        }
    }

    // Owner functions

    //Time delay for all owner functions
    function startOwnerFunctionsWindow() external onlyOwner {
        require(block.timestamp > txWindowEnd, "Previous owner functions window must be complete");

        // Start the time window for owner functions
        // ---|----------3 day delay------------|---------3 days window--------|---
        // Timer start                    txWindowStart                   txWindowEnd
        txWindowStart = block.timestamp + ownerTxDelay;
        txWindowEnd = txWindowStart + 3 days;
        emit ownerFunctionsStart(txWindowStart, txWindowEnd);
    }

    /**
     * @dev requires that the function is called within the owner delay window
     */
    modifier ownerDelay() {
        require((block.timestamp >= txWindowStart && block.timestamp <= txWindowEnd) || initialized == false, "Owner function can only be called within the time window"); //and before launch
        _;
    }

    function changeOracle(address _oracle) external onlyOwner ownerDelay {
        oracleId = _oracle;
        emit oracleChanged(oracleId);
    }

    function changeJobId(string memory _jobId) external onlyOwner ownerDelay {
        jobId = _jobId;
        emit jobIdChanged(jobId);
    }

    function changeFee(uint256 _fee) external onlyOwner ownerDelay {
        fee = _fee;
        emit truflationFeeChanged(fee);
    }

    function setLinkToken(address _token) external onlyOwner ownerDelay {
        setChainlinkToken(_token);
        emit linkTokenChanged(_token);
    }

    function withdrawLink() external onlyOwner ownerDelay {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
    }
    
    function authorizeUpgrade(address newImplementation) public {
		_authorizeUpgrade(newImplementation);
	}

	function _authorizeUpgrade(address) internal override onlyOwner {}
}

