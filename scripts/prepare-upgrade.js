// e.g. npx hardhat run scripts/prepare-upgrade.js --network rinkeby
const { defender } = require('hardhat')
const { UpalaConstants } = require('@upala/constants')

async function main() {
    // get Upala address from constants
    const wallets = await ethers.getSigners()
    const chainId = await wallets[0].getChainId()
    const upalaConst = new UpalaConstants(chainId)
    const upalaAddress = upalaConst.getAddress('Upala')
    // deploy upgrade
    const nextVersionUpala = await ethers.getContractFactory('Upala');
    const proposal = await defender.proposeUpgrade(upalaAddress, nextVersionUpala);
    console.log("Upgrade proposal created at:", proposal.url);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error)
      process.exit(1)
    })
  