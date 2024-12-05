// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

import "./Dependencies/BaseMath.sol";
import "./Interfaces/IRWAPriceFeed.sol";

/*
* RWAPriceFeed uses Chainlink based oracle to get US CPI
*/
contract RWAPriceFeed is BaseMath, OwnableUpgradeable, UUPSUpgradeable, ChainlinkClient, IRWAPriceFeed {
    using Chainlink for Chainlink.Request;
    
    string constant public NAME = "RWAPriceFeed";

    uint constant public TARGET_DIGITS = 18;  
    // Peg deviation maximum, 18-digit precision.
    uint256 public MAX_PEG_VARIANCE = 1e16; //1% This would prevent the peg from moving more than 1% in either direction
    // Minimum time period between peg updates
    uint256 public pegUpdateDelay = 1 days; // 1 day = 86400 seconds

    // Public oracle variables
    address public oracleId;
    string public jobId;
    bool public isSetupInitialized;

    struct AssetRequestVars {
        string reqService;
        string reqKeypath;
        string reqAbi;
        string reqData;
	}

    mapping(address => AssetRequestVars) public assetReqVars;
    mapping(address => uint256) public startingIndex;
    mapping(address => bool) public initialized;
    mapping(address => uint256) public counter; //counter for how many times the peg has been out of range. resets to 0 when peg is in range, or when peg is out of range 7 times
    mapping(address => uint256) private currentIndex;
    mapping(address => uint256) private rwaPrice;
    // Time of the last peg update, used to prevent multiple updates in a short time period 
    mapping(address => uint256) public lastUpdateTime; //block timestamp
    mapping(bytes32 => address) private requestIdToAssetId;


    // Public oracle variables
    uint256 public fee = 1e18;

    // Owner delay variables
    uint256 public txWindowStart; // time now + ownerTxDelay is time when owner functions can be called
    uint256 public txWindowEnd; // End of owner functions time window
    uint256 public ownerTxDelay = 3 days; // length of the window for owner functions, 3 days = 259200 seconds

    event oracleChanged(address _oracleId);
    event linkTokenChanged(address _token);
    event jobIdChanged(string _jobId);
    event truflationFeeChanged(uint256 _fee);
    event pegOutsideOfRange(address _rwaToken, uint256 _newPeg, uint256 _rwaPrice, uint256 _counter);
    event ownerFunctionsStart(uint256 _txWindowStart, uint256 _txWindowEnd);

    // --- Initializer ---
	function initialize() public initializer {
		__Ownable_init();
        __UUPSUpgradeable_init();
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

    // should be called when adding a new market
    function addAsset(
        address _rwaToken, 
        string memory _reqService,
        string memory _reqKeypath,
        string memory _reqAbi,
        string memory _reqData
    ) external onlyOwner {
        AssetRequestVars memory _assetReqVars = AssetRequestVars({
            reqService: _reqService,
            reqKeypath: _reqKeypath,
            reqAbi: _reqAbi,
            reqData: _reqData
        });

        assetReqVars[_rwaToken] = _assetReqVars;
        initialized[_rwaToken] = false;
        startingIndex[_rwaToken] = 1e18;
        currentIndex[_rwaToken] = 1e18;
        rwaPrice[_rwaToken] = 1e18;
        counter[_rwaToken] = 0;
        lastUpdateTime[_rwaToken] = block.timestamp;
    }

    /*
    * updateRWAPrice(): Updates the target peg based on the current inflation index. Calls the oracle to get current data
    * if the last update was more than 24hrs ago.
    */
    function updateRWAPrice(address _rwaToken) external override {
        require(initialized[_rwaToken], "Uninitialized rwa token");

        // Make sure there is sufficient link token to pay oracle
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.balanceOf(address(this)) >= fee, "Not enough LINK, Send 1+ LINK to InflationFeed contract");

        // limit updates to once per 24hrs
        if(shouldUpdateRWAPrice(_rwaToken)) {
            lastUpdateTime[_rwaToken] = block.timestamp;
            requestRWAPriceWei(_rwaToken);
        }
    }

    function shouldUpdateRWAPrice(address _rwaToken) internal view returns (bool) {
        if(initialized[_rwaToken] && block.timestamp < lastUpdateTime[_rwaToken] + pegUpdateDelay) { // Not time to update the peg yet silly - wait 24hrs
            return false;
        }
        return true;
    }

    function getRWAPrice(address _rwaToken) external view override returns (uint256) {
        return rwaPrice[_rwaToken];
    }

    function getCurrentIndex(address _rwaToken) external view override returns (uint256) {
        return currentIndex[_rwaToken];
    }

    function getLinkToken() public view returns (address) {
        return chainlinkTokenAddress();
    }

    function requestRWAPriceWei(address _rwaToken) internal returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            bytes32(bytes(jobId)),
            address(this),
            this.fulfillRWAPriceWei.selector
        );
        req.add("service", assetReqVars[_rwaToken].reqService);
        req.add("keypath", assetReqVars[_rwaToken].reqKeypath);
        req.add("abi", assetReqVars[_rwaToken].reqAbi);
        req.add("multiplier", "1000000000000000000");
        req.add("data", assetReqVars[_rwaToken].reqData);
        req.add("refundTo",
            Strings.toHexString(uint160(address(this)), 20));

        requestId = sendChainlinkRequestTo(oracleId, req, fee);
        requestIdToAssetId[requestId] = _rwaToken;
        return requestId;
    }

    function fulfillRWAPriceWei(
        bytes32 _requestId,
        bytes memory _inflation
    ) public recordChainlinkFulfillment(_requestId) {
        handleFulfill(uint(toInt256(_inflation)), _requestId);
    }

    function handleFulfill(uint _index, bytes32 _requestId) internal {
        // get inflation from oracle
        address _rwaToken = requestIdToAssetId[_requestId];
        delete requestIdToAssetId[_requestId];

        currentIndex[_rwaToken] = _index;

        if(!initialized[_rwaToken]) {
            startingIndex[_rwaToken] = currentIndex[_rwaToken];
            initialized[_rwaToken] = true;
            rwaPrice[_rwaToken] = currentIndex[_rwaToken] * DECIMAL_PRECISION / startingIndex[_rwaToken];
            return ;
        }
        // calculate new peg
        uint256 newPeg = currentIndex[_rwaToken] * DECIMAL_PRECISION / startingIndex[_rwaToken];

        //check if new price is outside acceptable variance, moves by maximum amount if so
        //this section changed based on Certik audit result
        if (newPeg > rwaPrice[_rwaToken] + rwaPrice[_rwaToken] * MAX_PEG_VARIANCE / DECIMAL_PRECISION) {

            counter[_rwaToken] = counter[_rwaToken] + 1; // increment counter of how many times peg is outside of range in a row
            emit pegOutsideOfRange(_rwaToken, newPeg, rwaPrice[_rwaToken], counter[_rwaToken]);

            // if outside of range 7 times in a row, move peg by maximum amount
            if (counter[_rwaToken] >= 7) {
                counter[_rwaToken] = 0; // reset counter
                rwaPrice[_rwaToken] = rwaPrice[_rwaToken] + rwaPrice[_rwaToken] * MAX_PEG_VARIANCE / DECIMAL_PRECISION;
            }

            emit LastRWAPriceUpdated(_rwaToken, rwaPrice[_rwaToken]);
            return ;
        }
        if (newPeg < rwaPrice[_rwaToken] - rwaPrice[_rwaToken] * MAX_PEG_VARIANCE / DECIMAL_PRECISION){

            counter[_rwaToken] = counter[_rwaToken] + 1; // increment counter of how many times peg is outside of range in a row
            emit pegOutsideOfRange(_rwaToken, newPeg, rwaPrice[_rwaToken], counter[_rwaToken]);

            // if outside of range 7 times in a row, move peg by maximum amount
            if (counter[_rwaToken] >= 7) {
                counter[_rwaToken] = 0; // reset counter
                rwaPrice[_rwaToken] = rwaPrice[_rwaToken] - rwaPrice[_rwaToken] * MAX_PEG_VARIANCE / DECIMAL_PRECISION;
            }

            emit LastRWAPriceUpdated(_rwaToken, rwaPrice[_rwaToken]);
            return ;
        }

        //check if new price is outside acceptable variance
        if (newPeg <= rwaPrice[_rwaToken] + rwaPrice[_rwaToken] * MAX_PEG_VARIANCE / DECIMAL_PRECISION &&
            newPeg >= rwaPrice[_rwaToken] - rwaPrice[_rwaToken] * MAX_PEG_VARIANCE / DECIMAL_PRECISION) {

            //reset counter if peg is in normal range
            if(counter[_rwaToken] != 0) {
                counter[_rwaToken] = 0; 
            }

            //update peg
            rwaPrice[_rwaToken] = newPeg;
            emit LastRWAPriceUpdated(_rwaToken, rwaPrice[_rwaToken]);
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
        require((block.timestamp >= txWindowStart && block.timestamp <= txWindowEnd) || isSetupInitialized == false, "Owner function can only be called within the time window"); //and before launch
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

