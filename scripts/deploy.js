const fs = require('fs');
const chalk = require('chalk');

async function main() {

  console.log("📡 Deploy \n")
  // let contractList = fs.readdirSync("./contracts")

  async function deployContract(contactName, ...args) {
    const contractArtifacts = artifacts.require(contactName);
    console.log("📄 "+contactName)
    const contract = await contractArtifacts.new(...args)
    console.log(chalk.cyan(contactName),"deployed to:", chalk.magenta(contract.address));
    fs.writeFileSync("artifacts/"+contactName+".address",contract.address);
    console.log("\n")
  }

  // await deployContract("SmartContractWallet", "0xf53bbfbff01c50f2d42d542b09637dca97935ff7");
  await deployContract("Upala");

}

main()
.then(() => process.exit(0))
.catch(error => {
  console.error(error);
  process.exit(1);
});
