import { BigNumber, utils } from "ethers"
const toEther = (val: any): BigNumber => utils.parseEther(String(val))

const OUTPUT_FILE = "./scripts/deployment/output/polygon-zkevm.json"
const TX_CONFIRMATIONS = 1
const ETHERSCAN_BASE_URL = "https://zkevm.polygonscan.com/address/"

const CONTRACT_UPGRADES_ADMIN = "0xc48aD04a391a0cfA538422360fAb8534b49d6878"
const SYSTEM_PARAMS_ADMIN = "0xc48aD04a391a0cfA538422360fAb8534b49d6878"
const TREASURY_WALLET = "0xc48aD04a391a0cfA538422360fAb8534b49d6878"

const DEBT_TOKEN_ADDRESS = "0xCA68ad4EE5c96871EC6C6dac2F714a8437A3Fe66"

const COLLATERAL = [
    {
        name: "wETH",
        address: "0x4F9A0e7FD2Bf6067db6994CF12E4495Df938E6e9",
        oracleAddress: "0x97d9F9A00dEE0004BE8ca0A8fa374d486567eE2D",
        oracleTimeoutSeconds: 90_000,
        oracleIsEthIndexed: false,
        borrowingFee: toEther(0.02),
        MCR: toEther(1.111),
        CCR: toEther(1.4),
        minNetDebt: toEther(200),
        gasCompensation: toEther(20),
        mintCap: toEther(1_000_000),
    }
]

module.exports = {
    COLLATERAL,
    CONTRACT_UPGRADES_ADMIN,
    ETHERSCAN_BASE_URL,
    DEBT_TOKEN_ADDRESS,
    OUTPUT_FILE,
    SYSTEM_PARAMS_ADMIN,
    TREASURY_WALLET,
    TX_CONFIRMATIONS,
}
