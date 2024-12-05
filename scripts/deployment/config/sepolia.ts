import { BigNumber, utils } from "ethers"
const toEther = (val: any): BigNumber => utils.parseEther(String(val))

const OUTPUT_FILE = "./scripts/deployment/output/sepolia.json"
const TX_CONFIRMATIONS = 2
const ETHERSCAN_BASE_URL = "https://sepolia.etherscan.io/address"

const CONTRACT_UPGRADES_ADMIN = "0x3Dd1BC3021e9CD98F5C99f90bCad06ca470DD9Ec"//"0x31c57298578f7508B5982062cfEc5ec8BD346247"
const SYSTEM_PARAMS_ADMIN = "0x3Dd1BC3021e9CD98F5C99f90bCad06ca470DD9Ec"//"0x31c57298578f7508B5982062cfEc5ec8BD346247"
const TREASURY_WALLET = "0xb14b29d81De2cB3a4f8DcA7BAcC94150c980c41f"//"0x31c57298578f7508B5982062cfEc5ec8BD346247"

const DEBT_TOKEN_NAME = "TEST LENDR TOKEN"
const DEBT_TOKEN_SYMBOL = "TLEDR"

const COLLATERAL = [
	{
		name: "wETH",
		address: "0x7b79995e5f793a07bc00c21412e50ecae098e7f9",//"0x7b79995e5f793a07bc00c21412e50ecae098e7f9",
		oracleAddress: "0x694AA1769357215DE4FAC081bf1f309aDC325306",//"0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625",
		oracleTimeoutSeconds: 86400,
		oracleIsEthIndexed: false,
		borrowingFee: toEther(0.02),
		MCR: toEther(1.111),
		CCR: toEther(1.4),
		minNetDebt: toEther(2_000),
		gasCompensation: toEther(200),
		mintCap: toEther(1_500_000),
		redemptionBlockTimestamp: 1705449600
	},
	// {
	// 	name: "rETH",
	// 	address: "0x178E141a0E3b34152f73Ff610437A7bf9B83267A",
	// 	oracleAddress: "0xbC204BDA3420D15AD526ec3B9dFaE88aBF267Aa9",
	// 	oracleTimeoutSeconds: 86400,
	// 	oracleIsEthIndexed: false,
	// 	MCR: toEther(1.176),
	// 	CCR: toEther(1.4),
	// 	minNetDebt: toEther(2_000),
	// 	gasCompensation: toEther(200),
	// 	mintCap: toEther(1_500_000),
	// 	redemptionBlockTimestamp: 1705449600
	// },
	// {
	// 	name: "wstETH",
	// 	address: "0xcef9cd8BB310022b5582E55891AF043213110783",
	// 	oracleAddress: "0x01fDd44216ec3284A7061Cc4e8Fb8d3a98AAcfa8",
	// 	oracleTimeoutSeconds: 86400,
	// 	oracleIsEthIndexed: false,
	// 	MCR: toEther(1.176),
	// 	CCR: toEther(1.4),
	// 	minNetDebt: toEther(2_000),
	// 	gasCompensation: toEther(200),
	// 	mintCap: toEther(1_500_000),
	// 	redemptionBlockTimestamp: 1705449600
	// },
	// {
	// 	name: "bLUSD",
	// 	address: "0x9A1Dd4C18aeBaf8A07556248cF4A7A2F2Bb85784",
	// 	oracleAddress: "0xFf92957A8d0544922539c4EA30E7B32Fd6cEC5D3",
	// 	oracleTimeoutSeconds: 86400,
	// 	oracleIsEthIndexed: false,
	// 	MCR: toEther(1.01),
	// 	CCR: toEther(1),
	// 	minNetDebt: toEther(2_000),
	// 	gasCompensation: toEther(0),
	// 	mintCap: toEther(1_500_000),
	// 	redemptionBlockTimestamp: 1705449600
	// },
]

module.exports = {
	COLLATERAL,
	CONTRACT_UPGRADES_ADMIN,
	ETHERSCAN_BASE_URL,
	OUTPUT_FILE,
	SYSTEM_PARAMS_ADMIN,
	TREASURY_WALLET,
	TX_CONFIRMATIONS,
	DEBT_TOKEN_NAME,
	DEBT_TOKEN_SYMBOL
}
