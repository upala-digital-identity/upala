// all upala admin functions go here - both for testing and production
// other scripts (like deploy-to-rinkeby or similar) will use this lib

const { BigNumber, utils } = require('ethers')
const { upgrades } = require('hardhat')

let oneETH = BigNumber.from(10).pow(18)
let fakeUBI = oneETH.mul(100)
async function deployContract(contractName, ...args) {
  const contractFactory = await ethers.getContractFactory(contractName)
  const contractInstance = await contractFactory.deploy(...args)
  await contractInstance.deployed()
  return contractInstance
}

class UpalaManager {

  constructor(initArgs) {
  }

  async setupProtocol() {
    this.fakeDai = await deployContract('FakeDai')
    this.wallets = await this._setupWallets()
    this.upala = await this._deployUpala()
    // todo production: introduce other options for pool factory types
    this.poolFactory = await this._setUpPoolFactory('SignedScoresPoolFactory', this.upala, this.fakeDai)
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

module.exports = UpalaManager