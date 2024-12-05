// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import { OFTV2 } from "@layerzerolabs/solidity-examples/contracts/token/oft/v2/OFTV2.sol";

contract LNDRToken is OFTV2 {

	string public constant NAME = "LNDRToken";

	uint256 internal _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24

	address public immutable treasury;

	/**
	 * @notice Create LNDRToken
	 * @param _endpoint LZ endpoint for network
	 * @param _treasurySig Treasury address, for fee recieve
	 */
	constructor(address _endpoint, address _treasurySig) OFTV2("Lendr", "LNDR", 18, _endpoint) {
		require(_endpoint != address(0), "Invalid Endpoint");
		require(_treasurySig != address(0), "Invalid Treasury Sig");
		treasury = _treasurySig;

		//Lazy Mint to setup protocol.
		//After the deployment scripts, deployer addr automatically send the fund to the treasury.
		_mint(msg.sender, _1_MILLION * 50);
		_mint(_treasurySig, _1_MILLION * 50);
	}
}
