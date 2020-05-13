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
  },
  solc: {
    version : "0.6.6",
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
};
