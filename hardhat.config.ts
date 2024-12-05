import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-truffle5";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@openzeppelin/hardhat-upgrades";
import "solidity-coverage";

import { task } from "hardhat/config";

require("dotenv").config();

const accounts = require("./hardhatAccountsList2k.js");
const accountsList = accounts.accountsList;

import {
  CoreDeployer,
  DeploymentTarget,
} from "./scripts/deployment/deploy-core";

import { LndrDeployer } from "./scripts/deployment/deploy-lndr";

task("deploy-core-hardhat", "Deploys contracts to Hardhat").setAction(
  async (_, hre) => await new CoreDeployer(hre, DeploymentTarget.Hardhat).run()
);
task("deploy-core-arbitrum", "Deploys contracts to Arbitrum").setAction(
  async (_, hre) => await new CoreDeployer(hre, DeploymentTarget.Arbitrum).run()
);
task("deploy-core-mainnet", "Deploys contracts to Mainnet").setAction(
  async (_, hre) => await new CoreDeployer(hre, DeploymentTarget.Mainnet).run()
);
task("deploy-core-mantle", "Deploys contracts to Mantle").setAction(
  async (_, hre) => await new CoreDeployer(hre, DeploymentTarget.Mantle).run()
);
task(
  "deploy-core-polygon-zkevm",
  "Deploys contracts to Polygon ZkEVM"
).setAction(
  async (_, hre) =>
    await new CoreDeployer(hre, DeploymentTarget.PolygonZkEvm).run()
);
task("deploy-core-linea", "Deploys contracts to Linea").setAction(
  async (_, hre) => await new CoreDeployer(hre, DeploymentTarget.Linea).run()
);
task("deploy-core-optimism", "Deploys contracts to Optimism").setAction(
  async (_, hre) => await new CoreDeployer(hre, DeploymentTarget.Optimism).run()
);
task("deploy-core-sepolia", "Deploys contracts to Sepolia").setAction(
  async (_, hre) => await new CoreDeployer(hre, DeploymentTarget.Sepolia).run()
);
task("deploy-core-arbitrum-sepolia", "Deploys contracts to Arbitrum Sepolia").setAction(
  async (_, hre) => await new CoreDeployer(hre, DeploymentTarget.ArbitrumSepolia).run()
);

task(
  "deploy-core-fuji",
  "Deploys contracts to Avalanche Fuji Testnet"
).setAction(
  async (_, hre) => await new CoreDeployer(hre, DeploymentTarget.Fuji).run()
);
task(
  "deploy-core-tbsc",
  "Deploys contracts to Binance Smart Chain Testnet"
).setAction(
  async (_, hre) =>
    await new CoreDeployer(hre, DeploymentTarget.BscTestnet).run()
);
// task("deploy-lndr", "Deploys LNDR contracts to Sepolia Testnet and BSC Testnet").setAction(
// 	async (_, hre) => await new LndrDeployer(hre, [DeploymentTarget.Sepolia, DeploymentTarget.BscTestnet]).run()
// )
task("deploy-lndr-hardhat", "Deploys LNDR contracts to Hardhat").setAction(
  async (_, hre) => await new LndrDeployer(hre, DeploymentTarget.Hardhat).run()
);

task("deploy-lndr-sepolia", "Deploys LNDR contracts to Sepolia").setAction(
  async (_, hre) => await new LndrDeployer(hre, DeploymentTarget.Sepolia).run()
);

task(
  "deploy-lndr-arbitrum-sepolia",
  "Deploys LNDR contracts to Arbitrum-Sepolia"
).setAction(
  async (_, hre) =>
    await new LndrDeployer(hre, DeploymentTarget.ArbitrumSepolia).run()
);

module.exports = {
  paths: {
    sources: "./contracts",
    tests: "./test/lendr",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  defender: {
    apiKey: process.env.DEFENDER_TEAM_API_KEY,
    apiSecret: process.env.DEFENDER_TEAM_API_SECRET_KEY,
  },
  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          outputSelection: {
            "*": {
              "*": ["storageLayout"],
            },
          },
        },
      },
      {
        version: "0.8.18",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      // accounts: [{ privateKey: process.env.DEPLOYER_PRIVATEKEY, balance: (10e18).toString() }, ...accountsList],
      accounts: accountsList,
    },
    // hardhat: {
    // 	accounts: accountsList,
    // 	chainId: 10,
    // 	forking: {
    // 		url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
    // 		// url: `https://optimism-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
    // 		blockNumber: 117603555,
    // 	},
    // },
    // Setup for testing files in test/gravita-fork:
    // hardhat: {
    // 	accounts: accountsList,
    // 	chainId: 10,
    // 	forking: {
    // 		url: `https://optimism-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
    // 		blockNumber: 112763546,
    // 	},
    // },
    arbitrum: {
      url: `https://arb1.arbitrum.io/rpc`,
      accounts: [`${process.env.DEPLOYER_PRIVATEKEY}`],
    },
    "arbitrum-sepolia": {
      // url: `https://sepolia-rollup.arbitrum.io/rpc`,
      url: `https://arb-sepolia.g.alchemy.com/v2/U768gcro2PvgeUUgTGIHpixb1JovboPP`,
      accounts: [`${process.env.DEPLOYER_PRIVATEKEY}`],
    },
    holesky: {
      url: `https://holesky.drpc.org`,
      accounts: [`${process.env.DEPLOYER_PRIVATEKEY}`],
    },
    linea: {
      url: `https://rpc.linea.build`,
      // url: `https://linea-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`${process.env.DEPLOYER_PRIVATEKEY}`],
    },
    mantle: {
      url: `https://rpc.mantle.xyz`,
      accounts: [`${process.env.DEPLOYER_PRIVATEKEY}`],
    },
    optimism: {
      url: `https://optimism-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`${process.env.DEPLOYER_PRIVATEKEY}`],
    },
    "optimism-sepolia": {
      url: `https://sepolia.optimism.io`,
      accounts: [`${process.env.DEPLOYER_PRIVATEKEY}`],
    },
    polygonZkEvm: {
      url: `https://polygon-zkevm.drpc.org`,
      accounts: [`${process.env.DEPLOYER_PRIVATEKEY}`],
    },
    sepolia: {
      allowUnlimitedContractSize: true,
      url: `https://ethereum-sepolia-rpc.publicnode.com`,
      accounts: [`${process.env.DEPLOYER_PRIVATEKEY}`],
      network_id: 11155111,
    },
    fuji: {
      url: `https://avalanche-fuji-c-chain-rpc.publicnode.com`,
      accounts: [`${process.env.DEPLOYER_PRIVATEKEY}`],
    },
    tbsc: {
      allowUnlimitedContractSize: true,
      url: `https://fluent-morning-tab.bsc-testnet.quiknode.pro/f11a02eeccdfe291f0d4c9cec55feb294e4226f2`,
      accounts: [`${process.env.DEPLOYER_PRIVATEKEY}`],
      network_id: 97,
    },
  },
  etherscan: {
    apiKey: {
      arbitrum: `${process.env.ARBITRUM_ETHERSCAN_API_KEY}`,
      "arbitrum-sepolia": `${process.env.ARBITRUM_ETHERSCAN_API_KEY}`,
      holesky: `${process.env.ETHERSCAN_API_KEY}`,
      linea: `${process.env.LINEA_ETHERSCAN_API_KEY}`,
      mantle: ``,
      "optimism-sepolia": `${process.env.OPTIMISM_ETHERSCAN_API_KEY}`,
      polygonZkEvm: `${process.env.POLYGON_ZKEVM_ETHERSCAN_API_KEY}`,
      sepolia: `${process.env.ETHERSCAN_API_KEY}`,
      fuji: ``,
      tbsc: ``,
    },
    customChains: [
      {
        network: "arbitrum",
        chainId: 42_161,
        urls: {
          apiURL: "https://api.arbiscan.io/api",
          browserURL: "https://arbiscan.io/",
        },
      },
      {
        network: "arbitrum-sepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io",
        },
      },
      {
        network: "holesky",
        chainId: 17_000,
        urls: {
          apiURL: "https://api-holesky.etherscan.io/api",
          browserURL: "https://holesky.etherscan.io/",
        },
      },
      {
        network: "linea",
        chainId: 59_144,
        urls: {
          apiURL: "https://api.lineascan.build/api",
          browserURL: "https://lineascan.build/",
        },
      },
      {
        network: "mantle",
        chainId: 5_000,
        urls: {
          apiURL: "https://explorer.mantle.xyz/api",
          browserURL: "https://explorer.mantle.xyz/",
        },
      },
      {
        network: "optimism-sepolia",
        chainId: 11155420,
        urls: {
          apiURL: "https://sepolia-optimism.etherscan.io/api",
          browserURL: "https://sepolia-optimism.etherscan.io",
        },
      },
      {
        network: "polygonZkEvm",
        chainId: 1_101,
        urls: {
          apiURL: "https://api-zkevm.polygonscan.com/api",
          browserURL: "https://zkevm.polygonscan.com/",
        },
      },
      {
        network: "sepolia",
        chainId: 11155111,
        urls: {
          apiURL: "https://api-sepolia.etherscan.io/api",
          browserURL: "https://sepolia.etherscan.io",
        },
      },
      {
        network: "fuji",
        chainId: 43113,
        urls: {
          apiURL: "https://api.avax-test.network/ext/bc/C/rpc",
          browserURL: "https://testnet.snowtrace.io",
        },
      },
      {
        network: "tbsc",
        chainId: 97,
        urls: {
          apiURL: "https://api-testnet.bscscan.com/api",
          browserURL: "https://testnet.bscscan.com/",
        },
      },
    ],
  },
  mocha: { timeout: 12_000_000 },
  rpc: {
    host: "localhost",
    port: 8545,
  },
  gasReporter: {
    enabled: false, // `${process.env.REPORT_GAS}`,
    currency: "USD",
    coinmarketcap: `${process.env.COINMARKETCAP_KEY}`,
  },
};
