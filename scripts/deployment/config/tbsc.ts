import { BigNumber, utils } from "ethers"
const toEther = (val: any): BigNumber => utils.parseEther(String(val))

const OUTPUT_FILE = "./scripts/deployment/output/tbsc.json"
const TX_CONFIRMATIONS = 1
const ETHERSCAN_BASE_URL = "https://testnet.bscscan.com/"

const CONTRACT_UPGRADES_ADMIN = "0x31c57298578f7508B5982062cfEc5ec8BD346247"
const SYSTEM_PARAMS_ADMIN = "0x31c57298578f7508B5982062cfEc5ec8BD346247"
const TREASURY_WALLET = "0x31c57298578f7508B5982062cfEc5ec8BD346247"

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
	ETHERSCAN_BASE_URL,
	OUTPUT_FILE,
	SYSTEM_PARAMS_ADMIN,
	TREASURY_WALLET,
	TX_CONFIRMATIONS,
}
