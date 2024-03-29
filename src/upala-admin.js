// Upala admin tools
// all upala admin functions go here - both for testing and production
// other scripts (like deploy-to-rinkeby or similar) will use this lib

const { UpalaConstants, numConfirmations } = require('@upala/constants')
const { utils } = require('ethers')
const { upgrades } = require('hardhat')
const chalk = require('chalk')
const { runInNewContext } = require('vm')

async function deployContract(contractName, ...args) {
  const contractFactory = await ethers.getContractFactory(contractName)
  const contractInstance = await contractFactory.deploy(...args)
  const chainId = await (await ethers.getSigner()).getChainId()
  await contractInstance.deployTransaction.wait(numConfirmations(chainId))
  await contractInstance.deployed()
  return contractInstance
}

// UPALA deployer
async function deployUpgradableUpala() {
  const chainId = await (await ethers.getSigner()).getChainId()
  let numConf = numConfirmations(chainId)
  const Upala = await ethers.getContractFactory('Upala')
  let upala = await upgrades.deployProxy(Upala, [], {
    kind: 'uups',
  })
  await upala.deployTransaction.wait(numConf)
  await upala.deployed()
  return upala
}

/************
UPALA MANAGER
*************/
// Manager deals with an already deployed protocol
// All deploy and initial setup functions are beyond this class
// Upgrade functionality should be here though

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

  // todo why we need this? What is the use-case?
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
    let poolFactory = await this.deployPoolFactory(poolType, upalaContract.address, upConsts.getAddress('DAI'))
    let tx = await upalaContract.approvePoolFactory(poolFactory.address, 'true')
    await tx.wait(numConfirmations(await this.getChainID()))
    return poolFactory
  }

  async deployPoolFactory(poolType, upalaContractAddress, DaiAddress) {
    return deployContract(poolType, upalaContractAddress, DaiAddress)
  }
}

/**************
DEPLOY SEQUENCE
***************/

// deploy sequence for any network
// publishes addresses and ABIs if needed to Upala constants
// todo see production sequence below for live ethereum network
async function setupProtocol(params) {
  let verbose = false
  if (params.hasOwnProperty('isVerbose') && params.isVerbose == true) {
    verbose = true
  }

  // Upala constants
  const wallets = await ethers.getSigners()
  // const otherWallets = await hre.ethers.getSigners();
  const adminWallet = wallets[0]
  let chainID = await adminWallet.getChainId()
  const upalaConstants = new UpalaConstants(chainID, { loadFromDisk: false }) // todo loadFromDisk option renamed.
  // ↑↑↑ But rename it even better and describe. Something like forceNewEntity () ↑↑↑
  if (verbose) {
    console.log('chainID:', chainID, '\nadmin:', adminWallet.address)
  }

  // Deploy Upala
  const upala = await deployUpgradableUpala()
  // const upala = await deployContract('Upala')  // non-upgradable (debugging)
  upalaConstants.addContract('Upala', upala)
  if (verbose) {
    console.log('Upala:', upala.address)
  }

  // Deploy DAI
  let dai
  if (params.hasOwnProperty('daiAdress') && params.daiAdress != null) {
    dai = upalaConstants.getContract('DAI', adminWallet, params.daiAdress)
  } else {
    dai = await deployContract('FakeDai', 'FakeDai', 'DAI')
  }
  upalaConstants.addContract('DAI', dai)
  // todo check if dai works correctly
  if (verbose) {
    console.log('DAI:', dai.address)
  }

  let poolFactory
  if (params.hasOwnProperty('skipPoolFactorySetup') && params.skipPoolFactorySetup == true) {
  } else {
    // Deploy Pool Factory
    const upalaManager = new UpalaManager(adminWallet, { upalaConstants: upalaConstants })
    // upalaManager grabs DAI contract from Upala Constants
    poolFactory = await upalaManager.setUpPoolFactory('SignedScoresPoolFactory')
    upalaConstants.addContract('SignedScoresPoolFactory', poolFactory)
    upalaConstants.addABI('SignedScoresPool', (await artifacts.readArtifact('SignedScoresPool')).abi)
    if (verbose) {
      console.log('poolFactory:', poolFactory.address)
    }
  }

  // Save Upala constants if needed (when deploying to production)
  if (params.hasOwnProperty('isSavingConstants') && params.isSavingConstants == true) {
    upalaConstants.save()
    console.log('Upala-admin: saving Upala constants')
  }

  // return the whole environment
  return {
    upalaConstants: upalaConstants,
    wallets: wallets,
    upala: upala,
    dai: dai,
    poolFactory: poolFactory,
  }
}

// prototyping production deployment sequence...
// todo move to setupProtocol function
async function productionDeployment(wallet) {
  // try
  const dai = attachToRealDai()
  const adminWallet = wallet
  const upala = await _deployUpgradableUpala()
  // <<-- deploy poolFactory
  const poolFactory = await setUpPoolFactory('SignedScoresPoolFactory', upala, dai)
  //save constants
  // catch
  // finally
  // updateUpalaConstants
  // store status
}

module.exports = { setupProtocol, UpalaManager }
