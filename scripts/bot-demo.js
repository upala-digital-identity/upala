// Bot manager testing
// copied from graph-demo (remove unnecessary stuff)

// npx hardhat run scripts/bot-demo.js --network rinkeby
const fs = require('fs')
const chalk = require('chalk')
const { ethers } = require('hardhat')
const { utils } = require('ethers')
const { setupProtocol } = require('../src/upala-admin.js')
const { deployPool, PoolManager } = require('@upala/group-manager')
const { newIdentity } = require('@upala/unique-human')
const { UpalaConstants, numConfirmations } = require('@upala/constants')

const USER_RATING_42 = 42 // do not use 42 anywhere else
const BASE_SCORE = ethers.utils.parseEther('2')
// using address from bot-manager
const BOT_ADDRESS = '0x1633092577b6e789863E8284d3db1393259e5D08'
const BOT_RATING = '50'
const POOL_FUNDING = ethers.utils.parseEther('1000')

async function main() {
  // SETUP ENVIRONMENT
  let env = await setupProtocol({ isSavingConstants: true })
  let upalaAdmin, manager1, persona1, persona2, persona3, persona4, delegate11, dapp, nobody
  ;[upalaAdmin, manager1, persona1, persona2, persona3, persona4, delegate11, dapp, nobody] = env.wallets

  console.log(
    chalk.green.bold('\nAddresses: '),
    chalk.green('\nupalaAdmin: '),
    upalaAdmin.address,
    chalk.green('\nmanager1: '),
    manager1.address
  )

  let upala = env.upala
  let fakeDAI = env.dai
  console.log(chalk.green('upala:'), upala.address)

  //   await manager1.sendTransaction({
  //     to: BOT_ADDRESS,
  //     value: ethers.utils.parseEther("0.001")
  //     });
  // create pool
  let signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
  console.log(chalk.green('signedScoresPool:'), signedScoresPool.address)
  // transfer DAI to pool address
  await fakeDAI.connect(manager1).freeDaiToTheWorld(signedScoresPool.address, POOL_FUNDING)
  console.log(chalk.green('fakeDAI sent'))

  // INIT POOL MANAGER
  // a hack to keep project dir clean
  // (creates temporary folder to store bundles info)
  let localDBdir = 'local-db-mock'
  let scoreExplorerDBdir = 'score-exp-mock'
  if (fs.existsSync(localDBdir)) {
    fs.rmSync(localDBdir, { recursive: true, force: true })
  }
  if (fs.existsSync(scoreExplorerDBdir)) {
    fs.rmSync(scoreExplorerDBdir, { recursive: true, force: true })
  }
  // todo HACK initializing 2 pool managers because of a bug (see group manager _requireCleanQueue)
  let poolManager1 = new PoolManager(signedScoresPool, localDBdir, scoreExplorerDBdir)
  let poolManager2 = new PoolManager(signedScoresPool, localDBdir, scoreExplorerDBdir)
  // set base score
  await poolManager1.setBaseScore(BASE_SCORE)
  console.log(chalk.green('BASE_SCORE set'))
  // publish 2 score bundles
  // register users
  // todo let persona2 be one of the addresses under bot-manager control
  let users1 = [
    { address: persona3.address, score: USER_RATING_42 + 2 },
    { address: persona4.address, score: USER_RATING_42 + 3 },
  ]
  let users2 = [
    { address: persona1.address, score: USER_RATING_42 },
    { address: BOT_ADDRESS, score: BOT_RATING },
  ]
  let subBundle1 = await poolManager1.publishNew(users1)
  console.log(chalk.green('subBundle1:'), subBundle1.public.bundleID)
  let subBundle2 = await poolManager2.publishNew(users2)
  console.log(chalk.green('subBundle2:'), subBundle2.public.bundleID)

  // delete bundle
  await poolManager1.deleteScoreBundleId(subBundle1.public.bundleID)
  console.log(chalk.green('subBundle1 deleted'))
  // todo create another pool

  // USER ACTIONS
  // create id
  let persona1id = await newIdentity(persona1.address, persona1, env.upalaConstants)
  console.log(chalk.green('persona1id'), persona1id)
  let persona2id = await newIdentity(persona2.address, persona2, env.upalaConstants)
  console.log(chalk.green('persona2id'), persona2id)

  // // register persona1 delegate
  tx = await upala.connect(delegate11).askDelegation(persona1id)
  await tx.wait(numConfirmations(await delegate11.getChainId()))
  console.log(chalk.green('delegate11 approved delegation'))

  tx = await upala.connect(persona1).approveDelegate(delegate11.address)
  await tx.wait(numConfirmations(await delegate11.getChainId()))
  console.log(chalk.green('persona1 approved delegate11 as delegate'))

  // change owner

  // DAPPS ACTIONS
  // register dapp

  console.log(
    chalk.green.bold('\nBot attack payload example: '),
    chalk.green('\npoolAddress: '),
    signedScoresPool.address,
    chalk.green('\nscoreAssignedTo: '),
    subBundle2.public.signedUsers[1].address,
    chalk.green('\nscore: '),
    subBundle2.public.signedUsers[1].score,
    chalk.green('\nbundleId: '),
    subBundle2.public.bundleID,
    chalk.green('\nproof: '),
    subBundle2.public.signedUsers[1].signature
  )
}
/* output 06.04.2022 (constants not saved)
Upala constants: networkID undefined
Upala constants: networkID undefined
Upala constants: networkID undefined
Upala constants: networkID undefined

Addresses:  
upalaAdmin:  0xa88630300706488e9d31597ccC4394206F4D4C6C 
manager1:  0xb94f953f389c45AD3fb71dC917f09eE9DF89e722
Upala constants: networkID 4
signedScoresPool: 0xa513E588238b69f4A87c79ebD4EB41CDE00EFC45
fakeDAI sent
BASE_SCORE set
Upala constants: networkID 4
subBundle1: 0x00000000000000000000000000000000598de248af93c7b853abcc219893cd07
Upala constants: networkID 4
subBundle2: 0x00000000000000000000000000000000389f83dcc81ef8f024ab3b9814105e2f
Upala constants: networkID 4
subBundle1 deleted
Upala constants: networkID 4
persona1id 0xCeaC9a972bD28cf8f8100ab861C6b9fBD7b8140D
Upala constants: networkID 4
persona2id 0xE135a1338BB4dc3fcB7Bc1D98712B81649C24e24
Upala constants: networkID 4
delegate11 approved delegation
Upala constants: networkID 4
persona1 approved delegate11 as delegate

Bot attack payload example:  
poolAddress:  0xa513E588238b69f4A87c79ebD4EB41CDE00EFC45 
scoreAssignedTo:  0x1633092577b6e789863E8284d3db1393259e5D08 
score:  50 
bundleId:  0x00000000000000000000000000000000389f83dcc81ef8f024ab3b9814105e2f 
proof:  0x08523a8f75f081afcc061d712af75c1abd8c94b59c2827257cd08763fd41904738522f8159e4496b17212c01d027a66014e509ee858ea2ffad4550dcbbe88e511c
*/

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
