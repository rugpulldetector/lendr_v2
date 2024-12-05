import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  getImplementationAddress,
  getImplementationAddressFromProxy,
  EthereumProvider,
} from "@openzeppelin/upgrades-core";
import { DeploymentTarget } from "./deploy-core";
import {
  BigNumber,
  Contract,
  Overrides,
  Wallet,
  constants,
  ethers,
  utils,
} from "ethers";
import fs from "fs";
import { JsonRpcProvider } from "@ethersproject/providers";

const layerZeroChainIds: Partial<{ [key in DeploymentTarget]: number }> = {
  [DeploymentTarget.Hardhat]: 1,
  // [DeploymentTarget.Arbitrum]: 1,
  // [DeploymentTarget.HoleskyTestnet]: 1,
  // [DeploymentTarget.Linea]: 1,
  // [DeploymentTarget.Mainnet]: 1,
  // [DeploymentTarget.Mantle]: 1,
  // [DeploymentTarget.Optimism]: 1,
  // [DeploymentTarget.PolygonZkEvm]: 1,
  // [DeploymentTarget.Fuji]: 1,
  [DeploymentTarget.Sepolia]: 10161,
  [DeploymentTarget.ArbitrumSepolia]: 10231,
  // [DeploymentTarget.BscTestnet]: 40102,
};

/**
 * Exported deployment script, invoked from hardhat tasks defined on hardhat.config.js
 */
export class LndrDeployer {
  hre: HardhatRuntimeEnvironment;
  coreContracts: any;
  lndrContracts: any;
  state: any;
  coreState: any;
  config: any;
  coreConfig: any;
  targetNetwork: DeploymentTarget;
  provider?: JsonRpcProvider;
  deployerWallet?: Wallet;
  deployerBalance?: Partial<{ [key in DeploymentTarget]: BigNumber }>;
  feeData: Overrides | undefined;

  constructor(hre: HardhatRuntimeEnvironment, targetNetwork: DeploymentTarget) {
    this.targetNetwork = targetNetwork;
    this.config = require(`./config/lndr`);
    const configParams = require(`./config/${this.targetNetwork}`);
    this.coreConfig = configParams;
    this.hre = hre;
  }

  isHardhatDeployment = (network: DeploymentTarget) =>
    DeploymentTarget.Hardhat == network;
  isTestnetDeployment = (network: DeploymentTarget) =>
    [
      DeploymentTarget.Hardhat,
      DeploymentTarget.Sepolia,
      DeploymentTarget.BscTestnet,
    ].includes(network);
  isLayer2Deployment = (network: DeploymentTarget) =>
    [DeploymentTarget.Arbitrum, DeploymentTarget.Optimism].includes(network);

  async run() {
    console.log(`Deploying Lendr LNDR contracts`);

    const feeData = await this.hre.ethers.provider.getFeeData();

    this.feeData = <Overrides>{
      maxFeePerGas: feeData.maxFeePerGas, //utils.parseUnits("20", "gwei"),
      maxPriorityFeePerGas: feeData.maxPriorityFeePerGas, //utils.parseUnits('4', 'gwei'),
    };

    // lndrContracts = await helper.deployLndrContracts(TREASURY_WALLET, deploymentState)
    // await deployOnlyLNDRContracts()
    // await helper.connectlndrContractsToCore(lndrContracts, lndrContracts, TREASURY_WALLET)
    // await approveLNDRTokenAllowanceForCommunityIssuance()
    // await this.transferLndrContractsOwnerships()

    // this.helper.saveDeployment(this.deploymentState)

    await this.deployOnlyLNDRContracts();
    //await this.setAddresses();
    // await this.verifyOnlyLNDRContracts();
    await this.connectlndrContractsToCore();
  }

  async printDeployerBalance(network: DeploymentTarget) {
    if (this.provider && this.deployerWallet) {
      if (!this.deployerBalance) {
        this.deployerBalance = {
          [network]: BigInt(0),
        };
      }
      const prevBalance = this.deployerBalance[network];
      this.deployerBalance[network] = await this.provider.getBalance(
        this.deployerWallet.address
      );
      const cost = parseFloat(utils.formatUnits(prevBalance!))
        ? parseFloat(utils.formatUnits(prevBalance!)) -
          parseFloat(utils.formatUnits(this.deployerBalance[network]!))
        : 0;
      console.log(
        `${this.deployerWallet.address} Balance: ${utils.formatUnits(
          this.deployerBalance[network]!
        )} ${cost ? `(Deployment cost: ${cost})` : ""}`
      );
    }
  }

  loadPreviousDeployment() {
    let previousDeployment = {};
    if (fs.existsSync(this.config.OUTPUT_FILE)) {
      console.log(
        `Loading previous deployment from ${this.config.OUTPUT_FILE}...`
      );
      previousDeployment = JSON.parse(
        fs.readFileSync(this.config.OUTPUT_FILE, "utf-8")
      );
    }
    this.state = previousDeployment;
  }

  saveDeployment() {
    const deploymentStateJSON = JSON.stringify(this.state, null, 2);
    fs.writeFileSync(this.config.OUTPUT_FILE, deploymentStateJSON);
  }

  async updateState(contractName: string, contract: Contract) {
    console.log(`(Updating state...)`);
    this.state[contractName] = {
      address: contract.address,
      txHash: contract.deployTransaction.hash,
    };
    this.saveDeployment();
  }

  async deployNonUpgradeable(
    contractName: string,
    params: string[] = []
  ) {
    return await this.loadOrDeploy(contractName, false, params);
  }

  async deployUpgradeable(
    contractName: string,
    params: string[] = []
  ) {
    return await this.loadOrDeploy(contractName, true, params);
  }


  async getFactory(name: string) {
    return await this.hre.ethers.getContractFactory(name, this.deployerWallet);
  }

  async loadOrDeploy(
    contractName: string,
    isUpgradeable: boolean,
    params: string[]
  ) {
    let retry = 0;
    const maxRetries = 2;
    // const timeout = 600_000 // 10 minutes
    const factory = await this.getFactory(contractName);
    const address = this.state?.[`${contractName}`]?.address;
    const alreadyDeployed = this.state[`${contractName}`] && address;

    if (this.provider && this.deployerWallet) {
      // const feeData = await this.provider.getFeeData()
      // console.log(feeData)
      this.feeData = <Overrides>{
        maxFeePerGas: ethers.utils.parseUnits("10", "gwei"),
        maxPriorityFeePerGas: ethers.utils.parseUnits("10", "gwei"),
        gasLimit: ethers.BigNumber.from(5e6),
      };

      // console.log(this.feeData)
    }

    if (!isUpgradeable) {
      if (alreadyDeployed) {
        // Existing non-upgradeable contract
        console.log(`Using previous deployment: ${address} -> ${contractName}`);
        return factory.attach(address);
      } else {
        // Non-Upgradeable contract, new deployment
        console.log(`(Deploying ${contractName}...)`);
        while (++retry < maxRetries) {
          try {
            console.log("params", ...params);
            const contract = await factory.deploy(...params, {
              ...this.feeData,
            });
            await this.updateState(contractName, contract);
            return contract;
          } catch (e: any) {
            console.log(`[Error: ${e.message}] Retrying...`);
          }
        }
        throw Error(
          `ERROR: Unable to deploy contract ${contractName} after ${maxRetries} attempts.`
        );
      }
    }
    if (alreadyDeployed) {
      // Existing upgradeable contract
      const existingContract = factory.attach(address);
      console.log(`Using previous deployment: ${address} -> ${contractName}`);
      return existingContract;
    } else {
      // Upgradeable contract, new deployment
      console.log(`(Deploying ${contractName} [uups]...)`);
      let opts: any = { kind: "uups" };
      if (Object.keys(factory.interface.functions).includes("initialize()")) {
        opts.initializer = "initialize()";
      }
      opts.txOverrides = this.feeData;
      while (++retry < maxRetries) {
        try {
          // @ts-ignore
          const newContract = await upgrades.deployProxy(factory, params, opts);
          await this.updateState(contractName, newContract);
          return newContract;
        } catch (e: any) {
          console.log(`[Error: ${e.message}] Retrying...`);
        }
      }
      throw Error(
        `ERROR: Unable to deploy contract ${contractName} after ${maxRetries} attempts.`
      );
    }
  }

  async deployOnlyLNDRContracts() {
    if (!process.env.DEPLOYER_PRIVATEKEY) {
      throw Error("Provide a value for DEPLOYER_PRIVATEKEY in your .env file");
    }

    this.loadPreviousDeployment();

    //const contracts: { [key: string]: Contract } = {};

    // for (const network of this.targetNetwork) {
    // set deployer wallet
    //const networkConfig = this.hre.config.networks[network];

    const network = this.targetNetwork;
    this.provider = this.hre.ethers.provider;
    this.deployerWallet = new ethers.Wallet(
      process.env.DEPLOYER_PRIVATEKEY,
      this.provider
    );
    await this.printDeployerBalance(network);

    const endpointAddress = this.config.LZ_ENDPOINTS[network];
    const treasuryAddress = this.config.TREASURY_WALLET[network];

    const lndrParams = [endpointAddress, treasuryAddress];

    const lndrToken = await this.deployNonUpgradeable(
      "LNDRToken",
      lndrParams
    );
    // deploy later on

    const communityIssuanceParams = [lndrToken.address];
    const communityIssuance = await this.deployUpgradeable(
      "CommunityIssuance",
      communityIssuanceParams
    );
    const lndrStaking = await this.deployUpgradeable("LNDRStaking");

    await this.printDeployerBalance(network);
    // }

    // for (const network of this.targetNetwork) {
    // 	const contract = contracts[network]
    // 	for (const remoteNetwork of this.targetNetwork) {
    // 		if (network !== remoteNetwork) {
    // 			const remoteContract = contracts[remoteNetwork]
    // 			const remoteChainId = layerZeroChainIds[remoteNetwork]
    // 			// const remotePath = utils.solidityPack(["address", "address"], [remoteContract.address, contract.address])
    // 			console.log(`setTrustedRemote(${remoteChainId}, ${remoteContract.address})`)
    // 			let tx = await contract.setTrustedRemoteAddress(remoteChainId, remoteContract.address)
    // 			console.log(tx)
    // 		}
    // 	}
    // }

    this.lndrContracts = {
      lndrToken,
      communityIssuance,
      lndrStaking,
    };

  }

  /**
   * Calls setAddresses() on all Addresses-inherited contracts.
   */
  async setAddresses() {
    try {
      console.log(`LndrStaking.setAddresses()...`);
      await this.lndrContracts.lndrStaking.setAddresses(
        this.lndrContracts.lndrToken.address,
        this.config.TREASURY_WALLET[this.targetNetwork]
      );
    } catch (e) {
      console.log(`LndrStaking.setAddresses() failed!`);
    }
  }

  async verifyOnlyLNDRContracts() {
    const network = this.targetNetwork;
    if (!this.config.ETHERSCAN_BASE_URLS[network]) {
      console.log("(No Etherscan URL defined, skipping contract verification)");
    } else {
      const endpointAddress = this.config.LZ_ENDPOINTS[network];
      const treasuryAddress = this.config.TREASURY_WALLET[network];

      const lndrParams = [endpointAddress, treasuryAddress];

      await this.verifyContract(`LNDRToken`, lndrParams, network);
      await this.verifyContract(`LNDRStaking`, [], network);
      await this.verifyContract(`CommunityIssuance`, [], network);
    }
  }

  async verifyContract(
    name: string,
    constructorArguments: string[] = [],
    network: DeploymentTarget
  ) {
    if (!this.state[name] || !this.state[name].address) {
      console.error(`  --> No deployment state for contract ${name}!!`);
      return;
    }
    if (this.state[name].verification) {
      console.log(`Contract ${name} already verified`);
      return;
    }
    try {
      await this.hre.run("verify:verify", {
        address: this.state[name].address,
        constructorArguments,
      });
    } catch (error: any) {
      // if it was already verified, it’s like a success, so let’s move forward and save it
      if (error.name != "NomicLabsHardhatPluginError") {
        console.error(`Error verifying: ${error.name}`);
        console.error(error);
        return;
      }
    }
    this.state[
      name
    ].verification = `${this.config.ETHERSCAN_BASE_URLS[network]}/${this.state[name].address}#code`;
    this.saveDeployment();
  }


  async connectlndrContractsToCore() {

    this.loadCoreContracts();
    console.log("Connect core contracts...");
    for (const key in this.coreContracts) {
      const contract = this.coreContracts[key];
      if (contract.setCommunityIssuance) {
        try {
          await contract.setCommunityIssuance(this.lndrContracts.communityIssuance.address);
        } catch (e) {
          console.log(`${key}.setCommunityIssuance() failed!`);
        }
      }
      if(contract.setLNDRStaking) {
        try {
          await contract.setLNDRStaking(this.lndrContracts.lndrStaking.address);
        } catch (e) {
          console.log(`${key}.setLNDRStaking() failed!`);
        }
      }
    }
  }

  async loadCoreContracts() {
    let previousDeployment = {};
    if (fs.existsSync(this.coreConfig.OUTPUT_FILE)) {
      console.log(
        `Loading previous deployment from ${this.coreConfig.OUTPUT_FILE}...`
      );
      previousDeployment = JSON.parse(
        fs.readFileSync(this.coreConfig.OUTPUT_FILE, "utf-8")
      );
    }
    this.coreState = previousDeployment;

    const activePool = await this.loadContract("ActivePool", true);
    const adminContract = await this.loadContract("AdminContract", true);
    const borrowerOperations = await this.loadContract(
      "BorrowerOperations", true
    );
    const collSurplusPool = await this.loadContract("CollSurplusPool", true);
    const defaultPool = await this.loadContract("DefaultPool", true);
    const feeCollector = await this.loadContract("FeeCollector", true);
    const sortedVessels = await this.loadContract("SortedVessels", true);
    const timelock = await this.loadContract("TimelockTester", false);
    const vesselManager = await this.loadContract("VesselManager", true);
    const vesselManagerOperations = await this.loadContract(
      "VesselManagerOperations", true
    );

    const gasPool = await this.loadContract("GasPool", false);
    const priceFeed = await this.loadContract("PriceFeedTestnet", false);
    const debtToken = await this.loadContract("DebtToken", false);
    const stakedDebtToken = await this.loadContract("StakedDebtToken", true);

    this.coreContracts = {
      activePool,
      adminContract,
      borrowerOperations,
      collSurplusPool,
      debtToken,
      defaultPool,
      feeCollector,
      gasPool,
      priceFeed,
      timelock,
      sortedVessels,
      stakedDebtToken,
      vesselManager,
      vesselManagerOperations
    };
  }

  async loadContract(contractName: string, isUpgradeable: boolean) {
    const factory = await this.getFactory(contractName);
    const address = this.coreState[contractName]?.address;
    const alreadyDeployed = this.coreState[contractName] && address;

    if (!isUpgradeable) {
      if (alreadyDeployed) {
        // Existing non-upgradeable contract
        console.log(`Using previous deployment: ${address} -> ${contractName}`);
        return factory.attach(address);
      } else {
        throw Error(`ERROR: Unable to load contract ${contractName}, it is not deployed.`);
      }
    } else {
      if (alreadyDeployed) {
        // Existing upgradeable contract
        const existingContract = factory.attach(address);
        console.log(`Using previous deployment: ${address} -> ${contractName}`);
        return existingContract;
      } else {
        throw Error(`ERROR: Unable to load contract ${contractName}, it is not deployed.`);
      }
    }
  }
}
