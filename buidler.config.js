usePlugin("@nomiclabs/buidler-waffle");
usePlugin("@nomiclabs/buidler-truffle5");

// This is a sample Buidler task. To learn how to create your own go to
// https://buidler.dev/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(await account.getAddress());
  }
});

// You have to export an object to set up your config
// This object can have the following optional entries:
// defaultNetwork, networks, solc, and paths.
// Go to https://buidler.dev/config/ to learn more
const secrets = require("./secrets.js");


module.exports = {
  defaultNetwork: 'localhost',
  networks: {
    localhost: {
      //url: 'https://rinkeby.infura.io/v3/2717afb6bf164045b5d5468031b93f87',
      url: 'http://localhost:8545',
      /*accounts: {
        mnemonic: "**SOME MNEMONIC**"
      },*/
    },
    kovan: {
      url: 'https://kovan.infura.io/v3/3b076e7d293041b684349d436904ccdb',//+infura_project_id,
      accounts: {
        mnemonic: secrets.mnemonic
      },
      timeout: 60000,
    },
    rinkeby: {
      url: 'https://rinkeby.infura.io/v3/3b076e7d293041b684349d436904ccdb',//+infura_project_id,
      accounts: {
        mnemonic: secrets.mnemonic
      },
      timeout: 60000,
    },
    matic: {
      //provider: () => new HDWalletProvider(mnemonic, `https://rpc-mumbai.matic.today`),
      network_id: 80001,
      url: `https://rpc-mumbai.matic.today`,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      accounts: {
        mnemonic: secrets.mnemonic
      },
    },
  },
  solc: {
    version : "0.6.6",
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
};
