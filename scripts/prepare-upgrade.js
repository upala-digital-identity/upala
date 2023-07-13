// unlock secrets
// nvm use v16.12.0 (if hardhat not upgraded yet - ERR_OSSL_EVP_UNSUPPORTED error)
// npx hardhat run scripts/prepare-upgrade.js --network rinkeby (rinkeby is depricated)
// follow link from terminal to OpenZeppelin Defender
// repeat for live network

const { defender } = require('hardhat')
const { UpalaConstants } = require('@upala/constants')

// const UPALA_MANAGER = '0x525437F0C66A85fABf922B2aF642dfBc6BF9EeD5' // todo move to constants
// WARNING!!! different manager for xDAI an Rinkeby! Move to constants ASAP
const UPALA_MANAGER = '0xddB1CB4EdBCD83066Abf26E7102dc0e88009DEAB'

async function main() {
  // get Upala address from constants
  const wallets = await ethers.getSigners()
  const chainId = await wallets[0].getChainId()
  const upalaConst = new UpalaConstants(chainId)
  const upalaAddress = upalaConst.getAddress('Upala')
  console.log('Upgrade proposal for Upala at:', upalaAddress)
  // deploy upgrade
  const nextVersionUpala = await ethers.getContractFactory('Upala')
  const proposal = await defender.proposeUpgrade(upalaAddress, nextVersionUpala, {
    description: 'UIP-26. Deterministic UpalaIDs',
    multisig: UPALA_MANAGER,
  })
  console.log('Upgrade proposal created at:', proposal.url)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
