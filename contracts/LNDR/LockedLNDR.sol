// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/*
This contract is reserved for Linear Vesting to the Team members and the Advisors team.
*/
contract LockedLNDR is Ownable, Initializable {
	using SafeERC20 for IERC20;

	struct Rule {
		uint256 createdDate;
		uint256 totalSupply;
		uint256 startVestingDate;
		uint256 endVestingDate;
		uint256 claimed;
	}

	string public constant NAME = "LockedLNDR";
	uint256 public constant SIX_MONTHS = 26 weeks;
	uint256 public constant TWO_YEARS = 730 days;

	IERC20 private lndrToken;
	uint256 private assignedLNDRTokens;

	mapping(address => Rule) public entitiesVesting;

	modifier entityRuleExists(address _entity) {
		require(entitiesVesting[_entity].createdDate != 0, "Entity doesn't have a Vesting Rule");
		_;
	}

	function setAddresses(address _lndrAddress) public initializer onlyOwner {
		lndrToken = IERC20(_lndrAddress);
	}

	function addEntityVesting(address _entity, uint256 _totalSupply) public onlyOwner {
		require(address(0) != _entity, "Invalid Address");

		require(entitiesVesting[_entity].createdDate == 0, "Entity already has a Vesting Rule");

		assignedLNDRTokens += _totalSupply;

		entitiesVesting[_entity] = Rule(
			block.timestamp,
			_totalSupply,
			block.timestamp + SIX_MONTHS,
			block.timestamp + TWO_YEARS,
			0
		);

		lndrToken.safeTransferFrom(msg.sender, address(this), _totalSupply);
	}

	function lowerEntityVesting(address _entity, uint256 newTotalSupply) public onlyOwner entityRuleExists(_entity) {
		sendLNDRTokenToEntity(_entity);
		Rule storage vestingRule = entitiesVesting[_entity];

		require(newTotalSupply > vestingRule.claimed, "Total Supply goes lower or equal than the claimed total.");

		vestingRule.totalSupply = newTotalSupply;
	}

	function removeEntityVesting(address _entity) public onlyOwner entityRuleExists(_entity) {
		sendLNDRTokenToEntity(_entity);
		Rule memory vestingRule = entitiesVesting[_entity];

		assignedLNDRTokens = assignedLNDRTokens - (vestingRule.totalSupply - vestingRule.claimed);

		delete entitiesVesting[_entity];
	}

	function claimLNDRToken() public entityRuleExists(msg.sender) {
		sendLNDRTokenToEntity(msg.sender);
	}

	function sendLNDRTokenToEntity(address _entity) private {
		uint256 unclaimedAmount = getClaimableLNDR(_entity);
		if (unclaimedAmount == 0) return;

		Rule storage entityRule = entitiesVesting[_entity];
		entityRule.claimed += unclaimedAmount;

		assignedLNDRTokens = assignedLNDRTokens - unclaimedAmount;
		lndrToken.safeTransfer(_entity, unclaimedAmount);
	}

	function transferUnassignedLNDR() external onlyOwner {
		uint256 unassignedTokens = getUnassignLNDRTokensAmount();

		if (unassignedTokens == 0) return;

		lndrToken.safeTransfer(msg.sender, unassignedTokens);
	}

	function getClaimableLNDR(address _entity) public view returns (uint256 claimable) {
		Rule memory entityRule = entitiesVesting[_entity];
		claimable = 0;

		if (entityRule.startVestingDate > block.timestamp) return claimable;

		if (block.timestamp >= entityRule.endVestingDate) {
			claimable = entityRule.totalSupply - entityRule.claimed;
		} else {
			claimable =
				((entityRule.totalSupply / TWO_YEARS) * (block.timestamp - entityRule.createdDate)) -
				entityRule.claimed;
		}

		return claimable;
	}

	function getUnassignLNDRTokensAmount() public view returns (uint256) {
		return lndrToken.balanceOf(address(this)) - assignedLNDRTokens;
	}

	function isEntityExits(address _entity) public view returns (bool) {
		return entitiesVesting[_entity].createdDate != 0;
	}
}
