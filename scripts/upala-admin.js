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


async function setupProtocol() {
    // wallets and DAI mock
    fakeDai = await deployContract('FakeDai')
    wallets = await ethers.getSigners()

    // fake DAI giveaway
    wallets.map(async (wallet, ix) => {
      if (ix <= 10) {
        await fakeDai.freeDaiToTheWorld(wallet.address, fakeUBI)
      }
    })
  
    // deploy upgradable upala
    const Upala = await ethers.getContractFactory('Upala')
    let upala = await upgrades.deployProxy(Upala)
    await upala.deployed()
  
    return [upala, fakeDai, wallets]
}

async function setUpPoolFactoryAndPool(upalaContract, tokenContract, poolFactoryName, upalaAdmin, managerWallet) {

  poolFactory = await deployContract(poolFactoryName, upalaContract.address, tokenContract.address)
  await upalaContract.connect(upalaAdmin).approvePoolFactory(poolFactory.address, 'true').then((tx) => tx.wait())

  // spawn a new pool by the factory
  const tx = await poolFactory.connect(managerWallet).createPool()
  const receipt = await tx.wait(1)
  const newPoolEvent = receipt.events.filter((x) => {
    return x.event == 'NewPool'
  })
  const newPoolAddress = newPoolEvent[0].args.poolAddress
  const poolContract = (await ethers.getContractFactory('SignedScoresPool')).attach(newPoolAddress)

  return [poolFactory, poolContract]
}

  module.exports = {
    setupProtocol,
    deployContract,
    setUpPoolFactoryAndPool,
  };