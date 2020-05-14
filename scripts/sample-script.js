// We require the Buidler Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `buidler run <script>` you'll find the Buidler
// Runtime Environment's members available in the global scope.
const bre = require("@nomiclabs/buidler");
const fs = require('fs');
const chalk = require('chalk');

async function main() {
  // Buidler always runs the compile task when running scripts through it. 
  // If this runs in a standalone fashion you may want to call compile manually 
  // to make sure everything is compiled
  // await bre.run('compile');

  // const publishDir = "../react-app-artifacts"
  const publishDir =  "../scaffold-eth/rad-new-dapp/packages/react-app/src/contracts"
  if (!fs.existsSync(publishDir)){
    fs.mkdirSync(publishDir);
  }
  let finalContractList = []

  console.log("📡 Deploy \n")
  // let contractList = fs.readdirSync("./contracts")

  async function deployContract(contractName, ...args) {
    const contractFactory = await ethers.getContractFactory(contractName);
    const contractInstance = await contractFactory.deploy(...args);
    await contractInstance.deployed();
    console.log(chalk.cyan(contractName),"deployed to:", chalk.magenta(contractInstance.address));
    // fs.writeFileSync("artifacts/"+contractName+".address",contractInstance.address);
    // console.log("\n")
    try {
        let contract = fs.readFileSync(bre.config.paths.artifacts+"/"+contractName+".json").toString()
        // let address = fs.readFileSync(bre.config.paths.artifacts+"/"+contractName+".address").toString()
        let address = contractInstance.address;
        contract = JSON.parse(contract)
        console.log(contractFactory.abi);

        // Publish
        fs.writeFileSync(publishDir+"/"+contractName+".address.js","module.exports = \""+address+"\"");
        fs.writeFileSync(publishDir+"/"+contractName+".abi.js","module.exports = "+JSON.stringify(contract.abi));
        // fs.writeFileSync(publishDir+"/"+contractName+".bytecode.js","module.exports = \""+contract.bytecode+"\"");
        fs.writeFileSync(publishDir+"/"+contractName+".bytecode.js","module.exports = \""+contractFactory.bytecode+"\"");
        
        finalContractList.push(contractName)
        console.log(contractName, " Published  \n")
      }catch(e){console.log(e)}
  }

  await deployContract("SmartContractWallet", "0xf53bbfbff01c50f2d42d542b09637dca97935ff7");
  await deployContract("Upala");

  console.log("📡 Publishing \n")
  fs.writeFileSync(publishDir+"/contracts.js","module.exports = "+JSON.stringify(finalContractList))
  // We get the contract to deploy
  // const SmartContractWallet = await ethers.getContractFactory("SmartContractWallet");
  // const scw = await SmartContractWallet.deploy("0xf53bbfbff01c50f2d42d542b09637dca97935ff7");
  // await scw.deployed();

  // console.log("SmartContractWallet deployed to:", scw.address);
}



// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
