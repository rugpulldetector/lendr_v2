// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IAddressesConfigurable {
	function debtToken() external view returns (address);

	function feeCollector() external view returns (address);

	function vesselManager() external view returns (address);
}
