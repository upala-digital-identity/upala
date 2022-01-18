import { task } from 'hardhat/config'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-truffle5'
import '@openzeppelin/hardhat-upgrades'
import '@nomiclabs/hardhat-web3'
import '@nomiclabs/hardhat-etherscan'
// const os = require('os');

// This is a sample Buidler task. To learn how to create your own go to
// https://buidler.dev/guides/create-task.html
task('accounts', 'Prints the list of accounts', async (args, hre) => {
  const accounts = await hre.ethers.getSigners()

  for (const account of accounts) {
    console.log(await account.getAddress())
  }
})

// store your secrets in a secure (cyphered) directory. 
// uses defaults when secrets vault locked (for local developement)
let secrets = { mnemonic: 'test', etherscanKey: 'none', alchemyKey: 'none', infuraKey: 'none' }
try {
  secrets = require('/Volumes/Secrets/dev/ah-token/Ah-mnemonic.js')
} catch {
  console.log('No secrets provided (local developement mode)')
}

export default {
  defaultNetwork: 'localhost',
  networks: {
    localhost: {
      url: 'http://localhost:8545',
    },
    kovan: {
      url: 'https://kovan.infura.io/v3/' + secrets.infuraKey,
      accounts: {
        mnemonic: secrets.mnemonic,
      },
      timeout: 60000,
    },
    rinkeby: {
      url: 'https://eth-rinkeby.alchemyapi.io/v2/' + secrets.alchemyKey,
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
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: secrets.etherscanKey
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
