import { BigNumber, utils } from "ethers"
const toEther = (val: any): BigNumber => utils.parseEther(String(val))

const OUTPUT_FILE = "./scripts/deployment/output/mantle.json"
const TX_CONFIRMATIONS = 1
const ETHERSCAN_BASE_URL = "https://explorer.mantle.xyz/address/"

/// @dev Safe Multisig on Mantle: https://multisig.mantle.xyz/

const CONTRACT_UPGRADES_ADMIN = "0x601FD66A2a32D980835517b135178124E973Dd7f"
const SYSTEM_PARAMS_ADMIN = "0x601FD66A2a32D980835517b135178124E973Dd7f"
const TREASURY_WALLET = "0x601FD66A2a32D980835517b135178124E973Dd7f"

const DEBT_TOKEN_ADDRESS = "0x894134a25a5faC1c2C26F1d8fBf05111a3CB9487"


const COLLATERAL = [
    {
        name: "wETH",
        address: "0xdeaddeaddeaddeaddeaddeaddeaddeaddead1111",
        oracleAddress: "0x009E9B1eec955E9Fe7FE64f80aE868e661cb4729",
        oracleTimeoutSeconds: 90_000,
        oracleIsEthIndexed: false,
        borrowingFee: toEther(0.02),
        MCR: toEther(1.111),
        CCR: toEther(1.4),
        minNetDebt: toEther(200),
        gasCompensation: toEther(20),
        mintCap: toEther(500_000),
        redemptionBlockTimestamp: 1705449600
    },
    {
        name: "mETH",
        address: "0xcDA86A272531e8640cD7F1a92c01839911B90bb0",
        oracleAddress: "0xF55faBDf4C4F19D48d12A94209c735ca5AC43c78",
        oracleTimeoutSeconds: 90_000,
        oracleIsEthIndexed: true,
        borrowingFee: toEther(0.04),
        MCR: toEther(1.25),
        CCR: toEther(1.4),
        minNetDebt: toEther(200),
        gasCompensation: toEther(20),
        mintCap: toEther(500_000),
        redemptionBlockTimestamp: 1705449600
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
