// all upala admin functions go here - both for testing and production
// other scripts (like deploy-to-rinkeby or similar) will use this lib
const { UpalaConstants } = require('@upala/constants')
const { BigNumber, utils } = require('ethers')
const { upgrades } = require('hardhat')
const chalk = require('chalk')
const { Cipher } = require('crypto')

async function deployContract(contractName, ...args) {
  const contractFactory = await ethers.getContractFactory(contractName)
  const contractInstance = await contractFactory.deploy(...args)
  await contractInstance.deployed()
  return contractInstance
}

// UPALA deployer
async function deployUpgradableUpala(adminWallet) {
  // const chainChainID = await adminWallet.getChainId()
  const Upala = await ethers.getContractFactory('Upala')
  let upala = await upgrades.deployProxy(Upala)
  await upala.deployed()
  return upala
}

/************
UPALA MANAGER
*************/

class UpalaManager {
  constructor(adminWallet, overrides) {
    this.adminWallet = adminWallet
    if (overrides && overrides.upalaConstants) {
      this.upalaConstants = overrides.upalaConstants
    }
  }
  // async initialize
  async getChainID() {
    if (!this.chainID) {
      this.chainID = await this.adminWallet.getChainId()
    }
    return this.chainID
  }

  async getUpalaConstants() {
    if (!this.upalaConstants) {
      this.upalaConstants = new UpalaConstants(await this.getChainID())
    }
    return this.upalaConstants
  }

  async getUpalaContract() {
    if (!this.upalaContract) {
      this.upalaContract = (await this.getUpalaConstants()).getContract('Upala', this.adminWallet)
    }
    return this.upalaContract
  }

  // deploy Pool factory and approve in Upala
  async setUpPoolFactory(poolType) {
    const upConsts = await this.getUpalaConstants() // todo introduce initialize function instead
    const upalaContract = await this.getUpalaContract()
    let poolFactory = await deployContract(poolType, upalaContract.address, upConsts.getAddress('DAI'))
    console.log('poolFactory.address', poolFactory.address)
    await upalaContract.approvePoolFactory(poolFactory.address, 'true').then((tx) => tx.wait())
    return poolFactory
  }
}

/***************
TEST ENVIRONMENT 
****************/

// TODO should live somewhere separate
async function _setupWallets(fakeDai) {
  let wallets = await ethers.getSigners()

  // fake DAI giveaway
  wallets.map(async (wallet, ix) => {
    if (ix <= 10) {
      await fakeDai.freeDaiToTheWorld(wallet.address, BigNumber.from(1000).pow(18))
    }
  })
  return wallets
}

// deploy setupTestEnvironment
async function setupProtocol(isSavingConstants) {
  // depoly Upala
  const fakeDai = await deployContract('FakeDai')
  const wallets = await _setupWallets(fakeDai)
  const adminWallet = wallets[0]
  const upala = await deployUpgradableUpala()
  const upalaConstants = new UpalaConstants(await adminWallet.getChainId(), { loadFromDisk: false })
  upalaConstants.addContract('Upala', upala)
  upalaConstants.addContract('DAI', fakeDai)

  // managing - adding new Pool Factory (...prototyping production flow)
  const upalaManager = new UpalaManager(adminWallet, { upalaConstants: upalaConstants })
  const poolFactory = await upalaManager.setUpPoolFactory('SignedScoresPoolFactory')
  upalaConstants.addContract('SignedScoresPoolFactory', poolFactory)
  upalaConstants.addABI('SignedScoresPool', (await artifacts.readArtifact('SignedScoresPool')).abi)

  // save Upala constants if needed (...prototyping production flow)
  if (isSavingConstants) {
    upalaConstants.save()
  }
  return { wallets: wallets } // return all contracts and wallets
}

/*********
PRODUCTION
**********/

// prototyping production deployment sequence...
async function productionDeployment(wallet) {
  // try
  const dai = attachToRealDai()
  const adminWallet = wallet
  const upala = await _deployUpgradableUpala()
  // <<-- deploy poolFactory
  const poolFactory = await setUpPoolFactory('SignedScoresPoolFactory', upala, fakeDai)
  //save constants
  // catch
  // finally
  // updateUpalaConstants
  // store status
}

async function main() {
  const protocol = await setupProtocol(true)
  console.log(protocol.wallets[0])
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
