// e.g. npx hardhat run scripts/deployer.js --network rinkeby
const { setupProtocol } = require('../src/upala-admin.js')
const { getDaiAddress, numConfirmations } = require('@upala/constants')

/* deploy and update logic for Upala
Deploy Upala policy:
- deploy proxy and first Upala implementation from local wallet
- Transfer ownership for proxy and Upala to cold wallet (or multisig)

Manage Upala:
- Use OpenZeppelin Defender to manage Upala

Update Upala:
- Deploy proposal implementation from local wallret
- Confirm upgrade from Upala admin using OZ Defender

*/

const UPALA_MANAGER = '0x525437F0C66A85fABf922B2aF642dfBc6BF9EeD5'

async function main() {
  const wallets = await ethers.getSigners()
  const chainId = await wallets[0].getChainId()

  const env = await setupProtocol({
    daiAdress: getDaiAddress(chainId),
    isVerbose: true,
    isSavingConstants: true,
  })

  // transfer ownership from deployer wallet to Upala manager (cold wallet or Multisig)
  let tx = await env.upala.transferOwnership(UPALA_MANAGER)
  await tx.wait(numConfirmations(chainId))
  console.log('Onership transferred to:', UPALA_MANAGER)
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
