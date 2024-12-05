import { DeploymentTarget } from "../deploy-core"
import { BigNumber, utils } from "ethers"
const toEther = (val: any): BigNumber => utils.parseEther(String(val))

const OUTPUT_FILE = "./scripts/deployment/output/lndr.json"
const TX_CONFIRMATIONS = 1
const ETHERSCAN_BASE_URLS = {
	[DeploymentTarget.Sepolia] : "https://sepolia.etherscan.io/address",
	[DeploymentTarget.ArbitrumSepolia] : "https://sepolia.arbiscan.io/address",
}

const CONTRACT_UPGRADES_ADMIN = "0x3Dd1BC3021e9CD98F5C99f90bCad06ca470DD9Ec"
const SYSTEM_PARAMS_ADMIN = "0x31c57298578f7508B5982062cfEc5ec8BD346247"
const TREASURY_WALLET = {
	[DeploymentTarget.Hardhat]: "0x31c57298578f7508B5982062cfEc5ec8BD346247",
	[DeploymentTarget.Sepolia]: "0xb14b29d81De2cB3a4f8DcA7BAcC94150c980c41f",
	[DeploymentTarget.ArbitrumSepolia]: "0xb14b29d81De2cB3a4f8DcA7BAcC94150c980c41f",
	//[DeploymentTarget.BscTestnet]: "0xb14b29d81De2cB3a4f8DcA7BAcC94150c980c41f",
}

const LZ_ENDPOINTS = {
	[DeploymentTarget.Hardhat]: "0x6EDCE65403992e310A62460808c4b910D972f10f",
	[DeploymentTarget.Sepolia]: "0xae92d5aD7583AD66E49A0c67BAd18F6ba52dDDc1",
	[DeploymentTarget.ArbitrumSepolia]: "0x6098e96a28E02f27B1e6BD381f870F1C8Bd169d3",
	//[DeploymentTarget.BscTestnet]: "0x6EDCE65403992e310A62460808c4b910D972f10f",
}

const COLLATERAL = [
	{
		name: "wETH",
		address: "0x9cb928a44b0664ad8e933c833f8210d772269b68",
		oracleAddress: "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625",
		oracleTimeoutMinutes: 90_000,
		oracleIsEthIndexed: false,
		MCR: toEther(1.111),
		CCR: toEther(1.4),
		minNetDebt: toEther(2_000),
		gasCompensation: toEther(200),
		mintCap: toEther(1_500_000),
	},
	{
		name: "rETH",
		address: "0x6924e831b35b183ca103e435a7a1b83f4d3239c7",
		oracleAddress: "0xbC204BDA3420D15AD526ec3B9dFaE88aBF267Aa9",
		oracleTimeoutMinutes: 90_000,
		oracleIsEthIndexed: false,
		MCR: toEther(1.176),
		CCR: toEther(1.4),
		minNetDebt: toEther(2_000),
		gasCompensation: toEther(200),
		mintCap: toEther(1_500_000),
	},
]

module.exports = {
	COLLATERAL,
	CONTRACT_UPGRADES_ADMIN,
	ETHERSCAN_BASE_URLS,
	OUTPUT_FILE,
	SYSTEM_PARAMS_ADMIN,
	TREASURY_WALLET,
	LZ_ENDPOINTS,
	TX_CONFIRMATIONS,
}

