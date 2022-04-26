// e.g. npx hardhat run scripts/deployer.js --network rinkeby
const { setupProtocol } = require('../src/upala-admin.js')
const { getDaiAddress } = require('@upala/constants')

/* deploy and update logic for Upala
Deploy Upala policy:
- deploy proxy and first Upala implementation from local wallet
- Transfer ownership for proxy and Upala to cold wallet (or multisig)

Manage Upala policy:
- Use OpenZeppelin defender to manage Upala

Update Upala policy:
- Deploy proposal implementation from local wallret 
- Confirm upgrade from Upala admin using defender

*/

async function main() {
  const wallets = await ethers.getSigners()
  const chainId = await wallets[0].getChainId()

  const env = await setupProtocol({
    daiAdress: getDaiAddress(chainId),
    isVerbose: true,
    isSavingConstants: true,
  })
  // ;[upalaAdmin, manager1, persona1, persona2, persona3, persona4, delegate11, dapp, nobody] = env.wallets
  // let upala = env.upala
  // let fakeDAI = env.dai
  // let upalaConstants = env.upalaConstants

  // const env = await setupProtocol({ isSavingConstants: false })
  // ;[upalaAdmin, manager1, persona1, persona2, persona3, persona4, delegate11, dapp, nobody] = env.wallets
  // let upala = env.upala
  // let fakeDAI = env.dai
  // let upalaConstants = env.upalaConstants

  // console.log("upala", env.upala.address)
  // console.log("fakeDai", env.dai.address)
  // console.log("SignedScoresPoolFactory", env.poolFactory.address)
  // console.log(protocol.wallets[0])
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
