import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  getImplementationAddress,
  getImplementationAddressFromProxy,
  EthereumProvider,
} from "@openzeppelin/upgrades-core";
import { BigNumber, Overrides, Wallet, constants, utils } from "ethers";
import fs from "fs";
import { ethers } from "ethers";

/**
 * Available target networks; each should have a matching file in the config folder.
 */
export enum DeploymentTarget {
  Hardhat = "hardhat",
  Arbitrum = "arbitrum",
  HoleskyTestnet = "holesky",
  Linea = "linea",
  Mainnet = "mainnet",
  Mantle = "mantle",
  Optimism = "optimism",
  PolygonZkEvm = "polygon-zkevm",
  ArbitrumSepolia = "arbitrum-sepolia",
  BscTestnet = "tbsc",
  Sepolia = "sepolia",
  Fuji = "fuji",
}

/**
 * Exported deployment class, invoked from hardhat tasks defined on hardhat.config.ts
 */
export class CoreDeployer {
  config: any;
  coreContracts: any;
  deployerBalance: BigNumber = utils.parseUnits("0");
  deployerWallet: Wallet;
  hre: HardhatRuntimeEnvironment;
  state: any;
  targetNetwork: DeploymentTarget;
  feeData: Overrides | undefined;

  constructor(hre: HardhatRuntimeEnvironment, targetNetwork: DeploymentTarget) {
    this.targetNetwork = targetNetwork;
    const configParams = require(`./config/${this.targetNetwork}`);
    if (!process.env.DEPLOYER_PRIVATEKEY) {
      throw Error("Provide a value for DEPLOYER_PRIVATEKEY in your .env file");
    }
    this.config = configParams;
    this.hre = hre;
    this.deployerWallet = new Wallet(
      process.env.DEPLOYER_PRIVATEKEY,
      this.hre.ethers.provider
    );
  }

  isLocalhostDeployment = () => DeploymentTarget.Hardhat == this.targetNetwork;
  isTestnetDeployment = () =>
    [
      DeploymentTarget.BscTestnet,
      DeploymentTarget.Sepolia,
      DeploymentTarget.ArbitrumSepolia,
    ].includes(this.targetNetwork);
  isLayer2Deployment = () =>
    [
      DeploymentTarget.Sepolia,
      // DeploymentTarget.Arbitrum,
      DeploymentTarget.ArbitrumSepolia,
    ].includes(this.targetNetwork);

  /**
   * Main function that is invoked by the deployment process.
   */
  async run() {
    console.log(`Deploying Lendr Core on ${this.targetNetwork}...`);

    const feeData = await this.hre.ethers.provider.getFeeData();

    this.feeData = <Overrides>{
      maxFeePerGas: feeData.maxFeePerGas, //utils.parseUnits("20", "gwei"),
      maxPriorityFeePerGas: feeData.maxPriorityFeePerGas, //utils.parseUnits('4', 'gwei'),
    };

    await this.printDeployerBalance();

    await this.loadOrDeployCoreContracts();
    await this.connectCoreContracts();
    await this.addCollaterals();

    // do not hand off from admin to timelock for now
    // await this.toggleContractSetupInitialization(this.coreContracts.adminContract)

    await this.verifyCoreContracts();

    // do not transfer ownership for now
    // await this.transferContractsOwnerships(this.coreContracts)

    await this.printDeployerBalance();
  }

  /**
   * Deploys all Lendr's Core contracts to the target network.
   * If any of the contracts have already been deployed and contain a matching entry in the JSON
   *     "state" file, the existing address is attached to the contract instead.
   */
  async loadOrDeployCoreContracts() {
    console.log(`Deploying core contracts...`);
    this.loadPreviousDeployment();

    const activePool = await this.deployUpgradeable("ActivePool");
    const adminContract = await this.deployUpgradeable("AdminContract");
    const borrowerOperations = await this.deployUpgradeable(
      "BorrowerOperations"
    );
    const collSurplusPool = await this.deployUpgradeable("CollSurplusPool");
    const defaultPool = await this.deployUpgradeable("DefaultPool");
    const feeCollector = await this.deployUpgradeable("FeeCollector");
    const sortedVessels = await this.deployUpgradeable("SortedVessels");
    // const stabilityPool = await this.deployUpgradeable("StabilityPool");
    
    const vesselManager = await this.deployUpgradeable("VesselManager");
    const vesselManagerOperations = await this.deployUpgradeable(
      "VesselManagerOperations"
    );

    const gasPool = await this.deployNonUpgradeable("GasPool");

    let priceFeed: any;
    if (this.isLocalhostDeployment()) {
      priceFeed = await this.deployNonUpgradeable("PriceFeedTestnet");
    } else {
      priceFeed = await this.deployNonUpgradeable("PriceFeedTestnet");
      //priceFeed = await this.deployUpgradeable("PriceFeed");
    }

    let timelockDelay: number;
    let timelockFactoryName: string;
    if (this.isTestnetDeployment()) {
      timelockDelay = 5 * 60; // 5 minutes
      timelockFactoryName = "TimelockTester";
    } else {
      timelockDelay = 2 * 86_400; // 2 days
      timelockFactoryName = "Timelock";
    }
    const timelockParams = [timelockDelay, this.config.SYSTEM_PARAMS_ADMIN];
    const timelock = await this.deployNonUpgradeable(
      timelockFactoryName,
      timelockParams
    );

    let debtToken: any;
    if (this.config.DEBT_TOKEN_ADDRESS) {
      console.log(
        `Using existing DebtToken from ${this.config.DEBT_TOKEN_A542DDRESS}`
      );
      debtToken = await this.hre.ethers.getContractAt(
        "DebtToken",
        this.config.DEBT_TOKEN_ADDRESS
      );
    } else {
      const debtTokenParams = [
        this.config.DEBT_TOKEN_NAME,
        this.config.DEBT_TOKEN_SYMBOL,
      ];
      debtToken = await this.deployNonUpgradeable("DebtToken", debtTokenParams);
    }

    const stakedDebtTokenParams = [debtToken.address];
    const stakedDebtToken = await this.deployUpgradeable("StakedDebtToken", stakedDebtTokenParams);

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
      sortedVessels,
      stakedDebtToken,
      timelock,
      vesselManager,
      vesselManagerOperations
    };
  }

  async deployUpgradeable(contractName: string, params: string[] = []) {
    const isUpgradeable = true;
    return await this.loadOrDeploy(contractName, isUpgradeable, params);
  }

  async deployNonUpgradeable(contractName: string, params: string[] = []) {
    const isUpgradeable = false;
    return await this.loadOrDeploy(contractName, isUpgradeable, params);
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
    const timeout = 600_000; // 10 minutes
    const factory = await this.getFactory(contractName);
    const address = this.state[contractName]?.address;
    const alreadyDeployed = this.state[contractName] && address;

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
            await this.updateState(contractName, contract, isUpgradeable);
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
          await newContract.deployed();

          await this.updateState(contractName, newContract, isUpgradeable);
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

  /**
   * Calls setAddresses() on all Addresses-inherited contracts.
   */
  async connectCoreContracts() {
    const setAddresses = async (contract: any) => {
      const coreAddresses = [
        await this.coreContracts.activePool.address,
        await this.coreContracts.adminContract.address,
        await this.coreContracts.borrowerOperations.address,
        await this.coreContracts.collSurplusPool.address,
        await this.coreContracts.debtToken.address,
        await this.coreContracts.defaultPool.address,
        await this.coreContracts.feeCollector.address,
        await this.coreContracts.gasPool.address,
        await this.coreContracts.priceFeed.address,
        await this.coreContracts.sortedVessels.address,
        // await this.coreContracts.stabilityPool.address,
        await this.coreContracts.stakedDebtToken.address,
        await this.coreContracts.timelock.address,
        this.config.TREASURY_WALLET,
        await this.coreContracts.vesselManager.address,
        await this.coreContracts.vesselManagerOperations.address,
      ];


      // @ts-ignore
      for (const [i, addr] of coreAddresses.entries()) {
        if (!addr || addr == constants.AddressZero) {
          throw new Error(`setAddresses :: Invalid address for index ${i}`);
        }
      }
      await contract.setAddresses(coreAddresses, { ...this.feeData });
    };
    for (const key in this.coreContracts) {
      const contract = this.coreContracts[key];
      if (contract.setAddresses && contract.isAddressSetupInitialized) {
        const isAddressSetupInitialized =
          await contract.isAddressSetupInitialized();
        if (!isAddressSetupInitialized) {
          console.log(`${key}.setAddresses()...`);
          try {
            await setAddresses(contract);
          } catch (e) {
            console.error(e);
            console.log(`${key}.setAddresses() failed!`);
            console.error(e);
          }
        } else {
          console.log(`${key}.setAddresses() already set!`);
        }
      } else {
        console.log(
          `(${key} has no setAddresses() or isAddressSetupInitialized() function)`
        );
      }
    }
    try {
      console.log(`DebtToken.setAddresses()...`);
      await this.coreContracts.debtToken.setAddresses(
        this.coreContracts.borrowerOperations.address,
        this.coreContracts.stakedDebtToken.address,
        this.coreContracts.vesselManager.address
      );
    } catch (e) {
      console.log(`DebtToken.setAddresses() failed!`);
    }

    try {
      console.log("Add feeCollector to whitelist");
      await this.coreContracts.debtToken.addWhitelist(this.coreContracts.feeCollector.address);
    } catch (e) {
      console.log(`DebtToken.addWhitelist() failed!`);
    }

    try {
      console.log("Setting RedemptionSofteningParam");
      await this.coreContracts.vesselManagerOperations.setRedemptionSofteningParam(ethers.utils.parseUnits("9900", 0));
    } catch (e) {
      console.log(e)
      console.log(`VesselManagerOperations.setRedemptionSofteningParam() failed!`);
    }
  }

  async addCollaterals() {
    console.log("Adding Collateral...");
    for (const coll of this.config.COLLATERAL) {
      if (!coll.address || coll.address == "") {
        console.log(`[${coll.name}] WARNING: No address setup for collateral`);
        continue;
      }
      if (!coll.oracleAddress || coll.oracleAddress == "") {
        console.log(
          `[${coll.name}] WARNING: No price feed oracle address setup for collateral`
        );
        continue;
      }
      await this.addPriceFeedOracle(coll);

      console.log("addPriceFeedOracle.....");
      await this.addCollateral(coll);
      if (coll.name == "wETH") {
        // use the same oracle for wETH and ETH
        await this.addPriceFeedOracle({
          ...coll,
          name: "ETH",
          address: constants.AddressZero,
        });
      }
    }
  }

  /**
   * Calls AdminContract.addNewCollateral() and AdminContract.setCollateralParams()
   *     using default values + parameters from the config file.
   */
  async addCollateral(coll: any) {
    const collExists =
      (await this.coreContracts.adminContract.getMcr(coll.address)) > 0;
    if (collExists) {
      console.log(
        `[${coll.name}] NOTICE: collateral has already been added before`
      );
    } else {
      const decimals = 18;
      console.log(`[${coll.name}] AdminContract.addNewCollateral() ...`);
      await this.sendAndWaitForTransaction(
        this.coreContracts.adminContract.addNewCollateral(
          coll.address,
          coll.gasCompensation,
          decimals,
          {
            ...this.feeData,
          }
        )
      );
      console.log(`[${coll.name}] Collateral added @ ${coll.address}`);
    }
    const isActive = await this.coreContracts.adminContract.getIsActive(
      coll.address
    );
    if (isActive) {
      console.log(
        `[${coll.name}] NOTICE: collateral params have already been set`
      );
    } else {
      console.log(`[${coll.name}] Setting collateral params...`);
      const defaultPercentDivisor =
        await this.coreContracts.adminContract.PERCENT_DIVISOR_DEFAULT();
      const defaultRedemptionFeeFloor =
        await this.coreContracts.adminContract.REDEMPTION_FEE_FLOOR_DEFAULT();
      await this.sendAndWaitForTransaction(
        this.coreContracts.adminContract.setCollateralParameters(
          coll.address,
          coll.borrowingFee,
          coll.CCR,
          coll.MCR,
          coll.minNetDebt,
          coll.mintCap,
          defaultPercentDivisor,
          defaultRedemptionFeeFloor,
          { ...this.feeData }
        )
      );

      await this.sendAndWaitForTransaction(
        this.coreContracts.adminContract.setRedemptionBlockTimestamp(
          coll.address,
          coll.redemptionBlockTimestamp
        )
      );
      console.log(
        `[${coll.name}] AdminContract.setCollateralParameters() -> ok`
      );
    }
  }

  /**
   * Calls PriceFeed.setOracle()
   */
  async addPriceFeedOracle(coll: any) {
    return;
    if (this.isLocalhostDeployment()) return;

    const oracleRecord = await this.coreContracts.priceFeed.oracles(
      coll.address
    );
    if (oracleRecord.decimals == 0) {
      const owner = await this.coreContracts.priceFeed.owner();
      if (owner != this.deployerWallet.address) {
        console.log(
          `[${coll.name}] WARNING: Cannot call PriceFeed.setOracle(): deployer = ${this.deployerWallet.address}, owner = ${owner}`
        );
        return;
      }
      console.log(`[${coll.name}] PriceFeed.setOracle()`);
      const oracleProviderType = BigNumber.from(0); // IPriceFeed.sol :: enum ProviderType.Chainlink
      const isFallback = false;
      console.log(coll);
      await this.sendAndWaitForTransaction(
        this.coreContracts.priceFeed.setOracle(
          coll.address,
          coll.oracleAddress,
          oracleProviderType,
          coll.oracleTimeoutSeconds,
          coll.oracleIsEthIndexed,
          isFallback,
          { ...this.feeData }
        )
      );
      console.log(
        `[${coll.name}] Oracle Price Feed has been set @ ${coll.oracleAddress}`
      );
    } else {
      if (oracleRecord.oracleAddress == coll.oracleAddress) {
        console.log(
          `[${coll.name}] Oracle Price Feed had already been set @ ${coll.oracleAddress}`
        );
      } else {
        console.log(
          `[${coll.name}] WARNING: another oracle had already been set, please update via Timelock.setOracle()`
        );
      }
    }
  }

  /**
   * Transfers the ownership of all Ownable contracts to the address defined on config's CONTRACT_UPGRADES_ADMIN.
   */
  async transferContractsOwnerships() {
    const upgradesAdmin = this.config.CONTRACT_UPGRADES_ADMIN;
    if (!upgradesAdmin || upgradesAdmin == constants.AddressZero) {
      throw Error(
        "Provide an address for CONTRACT_UPGRADES_ADMIN in the config file before transferring the ownerships."
      );
    }
    console.log(`\r\nTransferring contract ownerships to ${upgradesAdmin}...`);
    for (const contract of Object.values(this.coreContracts)) {
      let name = await this.getContractName(contract);
      if (!(contract as any).transferOwnership) {
        console.log(` - ${name} is NOT Ownable`);
      } else {
        const currentOwner = await (contract as any).owner();
        if (currentOwner == upgradesAdmin) {
          console.log(
            ` - ${name} -> Owner had already been set to @ ${upgradesAdmin}`
          );
        } else {
          try {
            await this.sendAndWaitForTransaction(
              (contract as any).transferOwnership(upgradesAdmin, {
                ...this.feeData,
              })
            );
            console.log(
              ` - ${name} -> Owner set to CONTRACT_UPGRADES_ADMIN @ ${upgradesAdmin}`
            );
          } catch (e: any) {
            console.error(e);
            console.log(` - ${name} -> ERROR [owner = ${currentOwner}]`);
          }
        }
      }
    }
  }

  /**
   * If contract has an isSetupInitialized flag, set it to true via setSetupIsInitialized()
   */
  async toggleContractSetupInitialization(contract: any) {
    let name = await this.getContractName(contract);
    if (!contract.isSetupInitialized) {
      console.log(`[NOTICE] ${name} does not have an isSetupInitialized flag!`);
      return;
    }
    const isSetupInitialized = await contract.isSetupInitialized();
    if (isSetupInitialized) {
      console.log(`${name} is already initialized!`);
    } else {
      await this.sendAndWaitForTransaction(
        contract.setSetupIsInitialized({ ...this.feeData })
      );
      console.log(`${name} has been initialized`);
    }
  }

  async getContractName(contract: any): Promise<string> {
    try {
      return await contract.NAME();
    } catch (e) {
      return "?";
    }
  }

  async printDeployerBalance() {
    const prevBalance = this.deployerBalance;
    this.deployerBalance = await this.hre.ethers.provider.getBalance(
      this.deployerWallet.address
    );
    const cost = parseFloat(utils.formatUnits(prevBalance))
      ? parseFloat(utils.formatUnits(prevBalance)) -
        parseFloat(utils.formatUnits(this.deployerBalance))
      : 0;
    console.log(
      `${this.deployerWallet.address} Balance: ${utils.formatUnits(
        this.deployerBalance!
      )} ${cost ? `(Deployment cost: ${cost})` : ""}`
    );
  }

  async sendAndWaitForTransaction(txPromise: any) {
    const tx = await txPromise;
    await tx.wait(this.config.TX_CONFIRMATIONS);
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

  async updateState(
    contractName: string,
    contract: any,
    isUpgradeable: boolean
  ) {
    console.log(`(Updating state...)`);
    this.state[contractName] = {
      address: await contract.address,
      txHash: contract.deployTransaction.hash,
    };
    if (isUpgradeable) {
      try {
        const provider: EthereumProvider = this.deployerWallet
          .provider as unknown as EthereumProvider;

        const contractAddr =await contract.address;
        const implAddress = await this.getImplementationAddressFromProxyWithRetry(
          provider,
          contractAddr
        );
        console.log(`(ImplAddress: ${implAddress})`);
        this.state[contractName].implAddress = implAddress;
      } catch (e: any) {
        console.error(e);
        console.log(`Unable to find implAddress for ${contractName}`);
      }
    }
    this.saveDeployment();
  }

  async getImplementationAddressFromProxyWithRetry(
    provider: EthereumProvider,
    proxyAddress: string,
    maxRetries: number = 5,
    delay: number = 2000
  ): Promise<string | undefined> {
    let implementationAddress: string | undefined;
  
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        implementationAddress = await getImplementationAddress(provider, proxyAddress);
        if (implementationAddress) {
          console.log(`Implementation address found: ${implementationAddress}`);
          return implementationAddress;
        }
      } catch (error) {
        console.error(`Attempt ${attempt}: Failed to get implementation address, retrying...`, error);
      }
  
      // Wait for a short delay before retrying
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  
    throw new Error(`Failed to get implementation address after ${maxRetries} retries`);
  }

  async logContractObjects(contracts: { [name: string]: any }) {
    const names: string[] = [];
    Object.keys(contracts).forEach((name) => names.push(name));
    names.sort();
    for (let name of names) {
      const contract = contracts[name];
      try {
        name = await contract.NAME();
      } catch (e) {}
      console.log(`Contract deployed: ${await contract.address} -> ${name}`);
    }
  }

  async verifyCoreContracts() {
    if (!this.config.ETHERSCAN_BASE_URL) {
      console.log("(No Etherscan URL defined, skipping contract verification)");
    } else {
      await this.verifyContract("ActivePool")
      await this.verifyContract("AdminContract")
      await this.verifyContract("BorrowerOperations")
      await this.verifyContract("CollSurplusPool")
      await this.verifyContract("DebtToken", [
        this.config.DEBT_TOKEN_NAME,
        this.config.DEBT_TOKEN_SYMBOL,
      ]);
      await this.verifyContract("DefaultPool")
      await this.verifyContract("FeeCollector")
      await this.verifyContract("GasPool")
      await this.verifyContract("PriceFeedTestnet")
      // await this.verifyContract("PriceFeed")

      let timelockDelay: number;
      if (this.isTestnetDeployment()) {
        timelockDelay = 5 * 60; // 5 minutes
      } else {
        timelockDelay = 2 * 86_400; // 2 days
      }
      const timelockParams = [timelockDelay, this.config.SYSTEM_PARAMS_ADMIN];
      await this.verifyContract("TimelockTester", timelockParams);

      await this.verifyContract("SortedVessels")
      await this.verifyContract("StakedDebtToken")
      await this.verifyContract("VesselManager")
      await this.verifyContract("VesselManagerOperations")
    }
  }

  async verifyContract(name: string, constructorArguments: string[] = []) {
    if (!this.state[name] || !this.state[name].address) {
      console.error(`  --> No deployment state for contract ${name}!!`);
      return;
    }
    if (this.state[name].verification) {
      console.log(`Contract ${name} already verified`);
      return;
    }
    try {
      // if(this.state[name].implAddress) {
      //   await this.hre.run("verify:verify", {
      //     address: this.state[name].implAddress,
      //     constructorArguments,
      //   });
      // }
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
    ].verification = `${this.config.ETHERSCAN_BASE_URL}/${this.state[name].address}#code`;
    this.saveDeployment();
  }
}

