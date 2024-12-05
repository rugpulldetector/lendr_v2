// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../Dependencies/BaseMath.sol";
import "../Dependencies/LendrMath.sol";

import "../Interfaces/ICommunityIssuance.sol";
// import "../Interfaces/IStabilityPool.sol";
import "../Interfaces/IStakedDebtToken.sol";

contract CommunityIssuance is ICommunityIssuance, UUPSUpgradeable, OwnableUpgradeable, BaseMath {
	using SafeERC20Upgradeable for IERC20Upgradeable;

	string public constant NAME = "CommunityIssuance";

	IERC20Upgradeable public	lndrToken;
    
	address[] public 			stabilityPools;
	uint256[] public 			stabilityPoolWeights;
    mapping(address => uint256) public rewardWeightsPerStakedDebtToken;
	
    // modifier updateReward(address _account) {
    //     rewardPerWeightStored = rewardPerWeight();
    //     updatedAt = lastTimeRewardApplicable();

    //     if (_account != address(0)) {
    //         rewards[_account] = earned(_account);
    //         userRewardPerWeightPaid[_account] = rewardPerWeightStored;
    //         userUpdatedAt[_account] = block.timestamp;
    //     }
    //     _;
    // }

	// --- Initializer ---

	function initialize(address _lndrTokenAddress) public initializer {
		__Ownable_init();
		lndrToken = IERC20Upgradeable(_lndrTokenAddress);
	}

    // Fallback function (Solidity ^0.6.0 and higher)
    fallback() external payable {}

    // Receive function to accept Ether
    receive() external payable {}

    // function setLNDRToken(address _lndrTokenAddress) external onlyOwner {
    //     require(_lndrTokenAddress != address(0), "Invalid address");
    //     lndrToken = IERC20Upgradeable(_lndrTokenAddress);
    // }

	// function setStabilityPoolsAndWeights(
	// 	address[] calldata _stabilityPools,
	// 	uint256[] calldata _stabilityPoolWeights
	// ) external onlyOwner {

	// 	require(_stabilityPoolAddress.length == _stabilityPoolWeights.length, "Length should be same");

	// 	uint256 totalWeights;
	// 	for (uint256 i = 0; i < _stabilityPoolWeights.length; i++) {
	// 		totalWeights += _stabilityPoolWeights[i];
	// 	}

	// 	require(totalWeights == 1 ether, "Total weight should be 1 ether");

	// 	stabilityPools = _stabilityPoolAddress;
	// 	stabilityPoolWeights = _stabilityPoolWeights;
		
	// 	// emit StabilityPoolAdded();
	// }

	// function setRewardsDuration(uint256 _duration) external onlyOwner {
    //     require(finishAt < block.timestamp, "reward duration not finished");
    //     duration = _duration;
    // }

    // function lastTimeRewardApplicable() public view returns (uint256) {
    //     return _min(finishAt, block.timestamp);
    // }

    // function rewardPerWeight() public view returns (uint256) {
    //     return rewardPerWeightStored + (rewardRatio * (lastTimeRewardApplicable() - updatedAt) * 1e18);
    // }

    // /**
    //  * @notice Update user's claimable reward data and record the timestamp.
    //  */
    // function refreshReward(address _account) external updateReward(_account) {}

    // function earned(address _account) public view returns (uint256) {
	// 	uint256 weight;
    //     for (uint i = 0; i < stabilityPools.length; i++) {
	// 		IERC20 pool = IERC20(stabilityPools[i]);
    //         weight += pool.balanceOf(_account) * stabilityPoolWeights[i] / pool.totalSupply();
    //     }

    //     return (weight * (rewardPerWeight() - userRewardPerWeightPaid[_account])) / 1 ether + rewards[_account];
    // }

    // function getReward() external updateReward(msg.sender) {
    //     uint256 reward = rewards[msg.sender];
    //     if (reward > 0) {
    //         rewards[msg.sender] = 0;
    //         lndrToken.transfer(msg.sender, reward);
    //         emit ClaimReward(msg.sender, reward, block.timestamp);
    //     }
    // }

    // function notifyRewardAmount(
    //     uint256 amount
    // ) external onlyOwner updateReward(address(0)) {
    //     require(amount != 0, "amount = 0");
    //     if (block.timestamp >= finishAt) {
    //         rewardRatio = amount / duration;
    //     } else {
    //         uint256 remainingRewards = (finishAt - block.timestamp) * rewardRatio;
    //         rewardRatio = (amount + remainingRewards) / duration;
    //     }

    //     require(rewardRatio != 0, "reward ratio = 0");

    //     finishAt = block.timestamp + duration;
    //     updatedAt = block.timestamp;

	// 	lndrToken.transferFrom(msg.sender, address(this), amount);
    //     emit NotifyRewardChanged(amount, block.timestamp);
    // }

    function getRewardRatio(address _stakedDebtToken) external view returns (uint256) {
        return 1e18; //* rewardWeightsPerStakedDebtToken[stakedDebtToken];
    }

    function vestReward(address _to, uint256 _amount) external {
        require(_amount > 0, "amount = 0");
        require(_to != address(0), "invalid address");
        require(_amount <= lndrToken.balanceOf(address(this)), "insufficient balance");

        lndrToken.transfer(_to, _amount);
    }

    function issueLNDR() external returns (uint256) {
        return 0;
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }

    function authorizeUpgrade(address newImplementation) public {
		_authorizeUpgrade(newImplementation);
	}

	function _authorizeUpgrade(address) internal override onlyOwner {}
}
