// Upala admin tools
// all upala admin functions go here - both for testing and production
// other scripts (like deploy-to-rinkeby or similar) will use this lib

const { UpalaConstants } = require('@upala/constants')
const { BigNumber, utils } = require('ethers')
const { upgrades, hre } = require('hardhat')
const chalk = require('chalk')

async function deployContract(contractName, ...args) {
  const contractFactory = await ethers.getContractFactory(contractName)
  const contractInstance = await contractFactory.deploy(...args)
  await contractInstance.deployTransaction.wait() // todo wait(2) for real nets
  await contractInstance.deployed()
  return contractInstance
}

// UPALA deployer
async function deployUpgradableUpala(adminWallet) {
  // const chainChainID = await adminWallet.getChainId()
  const Upala = await ethers.getContractFactory('Upala')
  let upala = await upgrades.deployProxy(Upala, [], { gasPrice: utils.parseUnits('1.3', 'gwei') })
  await upala.deployTransaction.wait() // todo wait(2) for real nets
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
    let poolFactory = await deployContract(poolType, upalaContract.address, upConsts.getAddress('DAI'))
    await upalaContract.approvePoolFactory(poolFactory.address, 'true') // todo production .then((tx) => tx.wait())
    return poolFactory
  }
}

/**************
DEPLOY SEQUENCE
***************/

// deploy sequence for any network
// publishes addresses and ABIs if needed to Upala constants
// todo see production sequence below for live ethereum network
async function setupProtocol(params) {
  // Upala constants
  const wallets = await ethers.getSigners()
  const adminWallet = wallets[0]
  const upalaConstants = new UpalaConstants(await adminWallet.getChainId(), { loadFromDisk: false })

  // Deploy Upala
  const upala = await deployUpgradableUpala()
  // const upala = await deployContract('Upala')  // non-upgradable (debugging)
  upalaConstants.addContract('Upala', upala)
  // console.log('upala', upala.address)

  // Deploy DAI
  const fakeDai = await deployContract('FakeDai', 'FakeDai', 'DAI')
  upalaConstants.addContract('DAI', fakeDai)
  // console.log('fakeDai', fakeDai.address)

  // Deploy Pool Factory
  const upalaManager = new UpalaManager(adminWallet, { upalaConstants: upalaConstants })
  // upalaManager grabs DAI contract from Upala Constants
  const poolFactory = await upalaManager.setUpPoolFactory('SignedScoresPoolFactory')
  upalaConstants.addContract('SignedScoresPoolFactory', poolFactory)
  upalaConstants.addABI('SignedScoresPool', (await artifacts.readArtifact('SignedScoresPool')).abi)

  // Save Upala constants if needed (when deploying to production)
  if (params.hasOwnProperty('isSavingConstants') && params.isSavingConstants == true) {
    upalaConstants.save()
    console.log('Upala-admin: saving Upala constants')
  }

  // Fake DAI giveaway (deprecate if not used in upala.js tests)
  // wallets.map(async (wallet, ix) => {
  //   if (ix <= 5) {
  //     // console.log("minted 1000 fakeDAI to", wallet.address)
  //     const tx = await fakeDai.freeDaiToTheWorld(wallet.address, BigNumber.from('1000000000000000000000'))
  //     await tx.wait(2)
  //   }
  // })

  // return the whole environment
  return {
    upalaConstants: upalaConstants,
    wallets: wallets,
    upala: upala,
    dai: fakeDai,
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
  const poolFactory = await setUpPoolFactory('SignedScoresPoolFactory', upala, fakeDai)
  //save constants
  // catch
  // finally
  // updateUpalaConstants
  // store status
}

module.exports = { setupProtocol }
