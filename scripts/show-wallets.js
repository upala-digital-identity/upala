// show wallets when deploying to real nets to fund appropriately
// e.g. npx hardhat run scripts/show-wallets.js --network rinkeby

async function main() {
  const wallets = await ethers.getSigners()

  for (let i = 0; i <= 10; i++) {
    let balance = ethers.utils.formatEther(await wallets[i].getBalance())
    console.log('%s: %s, eth: %s', i, wallets[i].address, balance)
  }

  // fund wallets
  // for (let i = 1; i <= 1; i++) {
  //     let tx = await wallets[0].sendTransaction({
  //         to: wallets[i].address,
  //         value: ethers.utils.parseEther("0.1")
  //         });
  //     await tx.wait(2)
  // }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
