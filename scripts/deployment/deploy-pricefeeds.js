const wstETH_address = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0"
const stETH_to_USD_oracleAddress = "0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8"
const deployerPrivateKey = process.env.DEPLOYER_PRIVATEKEY

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error)
		process.exit(1)
	})

async function main() {
	const txConfirmations = 1
	const timeout = 600_000 // milliseconds
	const deployerWallet = new ethers.Wallet(deployerPrivateKey, ethers.provider)

	// First deployment: a FixedPriceAggregator that always returns 1 (with 8 digits as decimals)
  console.log(`\r\nDeploying FixedPriceAggregator...`)
	const fixedPrice = (1_0000_0000).toString()
	const factory1 = await ethers.getContractFactory("FixedPriceAggregator", deployerWallet)
	const contract1 = await factory1.deploy(fixedPrice)
	await deployerWallet.provider.waitForTransaction(contract1.deployTransaction.hash, txConfirmations, timeout)
  console.log(`${contract1.address} -> set as oracleAddress of the bLUSD collateral on the config file`)

	// Second deployment: price aggregator for the wstETH collateral
  console.log(`\r\nDeploying WstEth2UsdPriceAggregator...`)
	const factory2 = await ethers.getContractFactory("WstEth2UsdPriceAggregator", deployerWallet)
	const contract2 = await factory2.deploy(wstETH_address, stETH_to_USD_oracleAddress)
	await deployerWallet.provider.waitForTransaction(contract2.deployTransaction.hash, txConfirmations, timeout)
  console.log(`${contract2.address} -> set as oracleAddress of the wstETH collateral on the config file\r\n`)
}
