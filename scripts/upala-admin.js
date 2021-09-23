// all upala admin functions go here - both for testing and production
// other scripts (like deploy-to-rinkeby or similar) will use this lib
const upalaConstants = require('upala-constants')
const { BigNumber, utils } = require('ethers')
const { upgrades } = require('hardhat')
const FormatTypes = ethers.utils.FormatTypes
const fs = require('fs')
const _ = require('lodash')
const chalk = require('chalk')

let oneETH = BigNumber.from(10).pow(18)
let fakeUBI = oneETH.mul(100)
async function deployContract(contractName, ...args) {
  const contractFactory = await ethers.getContractFactory(contractName)
  const contractInstance = await contractFactory.deploy(...args)
  await contractInstance.deployed()
  return contractInstance
}

class UpalaManager {
  constructor(initArgs) {}

  async setupProtocol() {
    this.fakeDai = await deployContract('FakeDai')
    this.wallets = await this._setupWallets()
    this.upala = await this._deployUpala()
    // todo production: introduce other options for pool factory types
    this.poolFactory = await this._setUpPoolFactory('SignedScoresPoolFactory', this.upala, this.fakeDai)
    await this.exportUpalaConstants()
  }

  async exportUpalaConstants() {
    // Export ABIs
    let abis = {
      Upala: this.upala.interface.format(FormatTypes.json),
      Dai: this.fakeDai.interface.format(FormatTypes.json),
      SignedScoresPoolFactory: this.poolFactory.interface.format(FormatTypes.json),
      SignedScoresPool: (await artifacts.readArtifact('SignedScoresPool')).abi,
    }
    let savedAbis = upalaConstants.getAbis()
    if (!_.isEqual(savedAbis, abis)) {
      console.log(chalk.red("\n\n\nWarning ABIs changed.\n\n\n"))
      fs.writeFileSync(upalaConstants.getAbisFilePath(), JSON.stringify(abis));
    }

    // Export addresses
    let addresses = {
      Upala: this.upala.address,
      Dai: this.fakeDai.address,
      SignedScoresPoolFactory: this.poolFactory.address,
    }
    let chainID = await this.wallets[0].getChainId()
    let savedAddresses = upalaConstants.getAddresses({chainID: chainID})
    if (!_.isEqual(savedAddresses, addresses) && chainID != 31337) {
      fs.writeFileSync(upalaConstants.getAddressesFilePath({chainID: chainID}), JSON.stringify(addresses));
      console.log(
        'Wrote addresses to:', 
        chalk.green(upalaConstants.getAddressesFilePath({chainID: chainID})))
    }
  }

  async _setupWallets() {
    let wallets = await ethers.getSigners()

    // fake DAI giveaway
    wallets.map(async (wallet, ix) => {
      if (ix <= 10) {
        await this.fakeDai.freeDaiToTheWorld(wallet.address, fakeUBI)
      }
    })
    return wallets
  }

  async _deployUpala() {
    // deploy upgradable upala
    const Upala = await ethers.getContractFactory('Upala')
    let upala = await upgrades.deployProxy(Upala)
    await upala.deployed()
    return upala
  }

  async _setUpPoolFactory(poolType, upalaContract, tokenContract) {
    // deploy Pool factory and approve in Upala
    let poolFactory = await deployContract(poolType, upalaContract.address, tokenContract.address)
    await upalaContract
      // .connect(upalaAdmin)
      .approvePoolFactory(poolFactory.address, 'true')
      .then((tx) => tx.wait())
    return poolFactory
  }

  // todo now returns only 'SignedScoresPoolFactory'
  getPoolFactory(factoryType) {
    return this.poolFactory
  }
}

// this function is used for testing
async function main() {
  let upalaManager = new UpalaManager()
  await upalaManager.setupProtocol()
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })

module.exports = UpalaManager
