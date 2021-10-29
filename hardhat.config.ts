import { task } from 'hardhat/config'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-truffle5'
import '@openzeppelin/hardhat-upgrades'
import '@nomiclabs/hardhat-web3'
// const os = require('os');

// This is a sample Buidler task. To learn how to create your own go to
// https://buidler.dev/guides/create-task.html
task('accounts', 'Prints the list of accounts', async (args, hre) => {
  const accounts = await hre.ethers.getSigners()

  for (const account of accounts) {
    console.log(await account.getAddress())
  }
})

// You have to export an object to set up your config
// This object can have the following optional entries:
// defaultNetwork, networks, solc, and paths.
// Go to https://buidler.dev/config/ to learn more
// 
let secrets = { mnemonic: "test" }
try {
  secrets = require('./secrets.js')
} catch {
  console.log("No secrets provided (local developement mode)")
}

// const secrets = require(os.homedir() + "/gocrypt/dev/ah-token/Ah-mnemonic.js");
// const gateway = require(os.homedir() + "/gocrypt/dev/ah-token/gateway.js");

export default {
  defaultNetwork: 'localhost',
  networks: {
    localhost: {
      //url: 'https://rinkeby.infura.io/v3/2717afb6bf164045b5d5468031b93f87',
      url: 'http://localhost:8545',
    },
    kovan: {
      url: 'https://kovan.infura.io/v3/3b076e7d293041b684349d436904ccdb', //+infura_project_id,
      accounts: {
        mnemonic: secrets.mnemonic,
      },
      timeout: 60000,
    },
    rinkeby: {
      url: 'https://rinkeby.infura.io/v3/3b076e7d293041b684349d436904ccdb', //+infura_project_id,
      accounts: {
        mnemonic: secrets.mnemonic,
      },
      timeout: 60000,
    },
    bnbTestnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      chainId: 97,
      gasPrice: 20000000000,
      accounts: {
        mnemonic: secrets.mnemonic,
      },
    },
    mumbai: {
      //provider: () => new HDWalletProvider(mnemonic, `https://rpc-mumbai.matic.today`),
      network_id: 80001,
      url: `https://rpc-mumbai.matic.today`,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      accounts: {
        mnemonic: secrets.mnemonic,
      },
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.6.6',
      },
      {
        version: '0.8.0',
      },
    ],
    // version: '0.8.0',
    settings: {
      optimizer: {
        enabled: true,
      },
    },
  },
}
