// e.g. npx hardhat run scripts/prepare-upgrade.js --network rinkeby
const { defender } = require('hardhat')
const { UpalaConstants } = require('@upala/constants')

const UPALA_MANAGER = "0x525437F0C66A85fABf922B2aF642dfBc6BF9EeD5"  // todo move to constants

async function main() {
  // get Upala address from constants
  const wallets = await ethers.getSigners()
  const chainId = await wallets[0].getChainId()
  const upalaConst = new UpalaConstants(chainId)
  const upalaAddress = upalaConst.getAddress('Upala')
  // deploy upgrade
  const nextVersionUpala = await ethers.getContractFactory('Upala')
  const proposal = await defender.proposeUpgrade(
    upalaAddress, 
    nextVersionUpala,
    { description: "Testing upgrade",
      multisig: UPALA_MANAGER})
  console.log('Upgrade proposal created at:', proposal.url)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
