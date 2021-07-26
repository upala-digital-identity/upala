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

async function resetProtocol() {
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

async function setUpPool() {
    signedScoresPoolFactory = await deployContract('SignedScoresPoolFactory', upala.address, fakeDai.address)
}

  module.exports = {
    resetProtocol,
    deployContract,
  };