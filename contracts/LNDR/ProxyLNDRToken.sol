// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import { OFTV2 } from "@layerzerolabs/solidity-examples/contracts/token/oft/v2/OFTV2.sol";
import { ProxyOFTV2 } from "@layerzerolabs/solidity-examples/contracts/token/oft/v2/ProxyOFTV2.sol";
import { LNDRToken } from "./LNDRToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ProxyLNDRToken is LNDRToken {
    using SafeERC20 for IERC20;

    IERC20 internal immutable innerToken;

    // total amount is transferred from this chain to other chains, ensuring the total is less than uint64.max in sd
    uint public outboundAmount;

	constructor(
		address _token,
		address _lzEndpoint,
		address _treasurySig
	) LNDRToken(_lzEndpoint, _treasurySig) {
        innerToken = IERC20(_token);
    }
	
    /************************************************************************
     * public functions
     ************************************************************************/
    function circulatingSupply() public view virtual override returns (uint) {
        return innerToken.totalSupply() - outboundAmount;
    }

    function token() public view virtual override returns (address) {
        return address(innerToken);
    }

	/************************************************************************
     * internal functions
     ************************************************************************/
    function _debitFrom(
        address _from,
        uint16,
        bytes32,
        uint _amount
    ) internal virtual override returns (uint) {
        require(_from == _msgSender(), "ProxyOFT: owner is not send caller");

        _amount = _transferFrom(_from, address(this), _amount);

        // _amount still may have dust if the token has transfer fee, then give the dust back to the sender
        (uint amount, uint dust) = _removeDust(_amount);
        if (dust > 0) SafeERC20.safeTransfer(innerToken, _from, dust);

        // check total outbound amount
        outboundAmount += amount;
        uint cap = _sd2ld(type(uint64).max);
        require(cap >= outboundAmount, "ProxyOFT: outboundAmount overflow");

        return amount;
    }

	function _creditTo(
        uint16,
        address _toAddress,
        uint _amount
    ) internal virtual override returns (uint) {
        outboundAmount -= _amount;

        // tokens are already in this contract, so no need to transfer
        if (_toAddress == address(this)) {
            return _amount;
        }

        return _transferFrom(address(this), _toAddress, _amount);
    }

    function _transferFrom(
        address _from,
        address _to,
        uint _amount
    ) internal virtual override returns (uint) {
        uint before = innerToken.balanceOf(_to);
        if (_from == address(this)) {
            SafeERC20.safeTransfer(innerToken, _to, _amount);
        } else {
            SafeERC20.safeTransferFrom(innerToken, _from, _to, _amount);
        }
        return innerToken.balanceOf(_to) - before;
    }

    function _ld2sdRate() internal view virtual override returns (uint) {
        return ld2sdRate;
    }
}
