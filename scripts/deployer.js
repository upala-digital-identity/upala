const { setupProtocol } = require('../src/upala-admin.js')

async function main() {
  // const upala = await hre.ethers.getContractAt("Upala", "0xD74Ce6D4eA2b11BDC0E0A1CbD9156A3FD50c7870")
  // console.log(await upala.attackWindow())
  const env = await setupProtocol({ isSavingConstants: false })
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
