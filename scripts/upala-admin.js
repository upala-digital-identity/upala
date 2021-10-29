// all upala admin functions go here - both for testing and production
// other scripts (like deploy-to-rinkeby or similar) will use this lib
const upalaConstants = require('@upala/constants')
const { BigNumber, utils } = require('ethers')
const { upgrades } = require('hardhat')
const FormatTypes = ethers.utils.FormatTypes
const fs = require('fs')
const _ = require('lodash')
const chalk = require('chalk')

async function deployContract(contractName, ...args) {
  const contractFactory = await ethers.getContractFactory(contractName)
  const contractInstance = await contractFactory.deploy(...args)
  await contractInstance.deployed()
  return contractInstance
}

class UpalaManager {
  // todo add chainID as parameter - would simplify a lot
  // will move contract initialization and upala constants to constructor
  constructor(adminWallet, overrides) {
    this.adminWallet = adminWallet
    if (overrides && overrides.upalaConstants) {
      this.upalaConstants = upalaConstants
    }
  }

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
  }

  async getUpalaContract() {
    if (!this.upalaContract) {
      this.upalaContract = upConsts.getContract('Upala', this.adminWallet)
    }
    return this.upalaContract
  }

  // deploy Pool factory and approve in Upala
  async setUpPoolFactory(poolType) {
    const upConsts = this.getUpalaConstants()
    const upalaContract = this.getUpalaContract()
    let poolFactory = await deployContract(poolType, upalaContract.address, upConsts.getAddress('DAI'))
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
  this.fakeDai = await deployContract('FakeDai')
  this.wallets = await this._setupWallets()
  const adminWallet = this.wallets[0]
  this.upala = await this._deployUpgradableUpala()
  const upalaConstants = new UpalaConstants(chainID, { loadFromDisk: false })
  upalaConstants.addContract('Upala', upala)
  upalaConstants.addContract('DAI', fakeDai)

  // managing - adding new Pool Factory (...prototyping production flow)
  const upalaManager = new UpalaManager(adminWallet, { upalaConstants: upalaConstants })
  this.poolFactory = await upalaManager.setUpPoolFactory('SignedScoresPoolFactory')
  upalaConstants.addContract('SignedScoresPoolFactory'.poolFactory)
  upalaConstants.addABI('SignedScoresPool', (await artifacts.readArtifact('SignedScoresPool')).abi)

  // save Upala constants if needed (...prototyping production flow)
  if (isSavingConstants) {
    upalaConstants.save()
  }
  return 1 // return all contracts and wallets
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
  let upalaManager = new UpalaTestEnvironment({ writeAddresses: true })
  await upalaManager.setupProtocol()
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })

module.exports = UpalaTestEnvironment
