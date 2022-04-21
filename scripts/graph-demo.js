// Script to test subgraph
// The subgraph itself is in this repo - https://github.com/upala-digital-identity/subgraph
// As of March 10 2022 the draft subgraph is already deployed to graph studio
// and tired to Rinkeby contract.
// This script will test that all info gets into graph properly.
// Should cover all cases from Requirements for the subgraph -
// https://github.com/upala-digital-identity/subgraph-schema

// Bot manager testing
// Same script is used to test bot manager cli locally

// npx hardhat run scripts/graph-demo.js --network rinkeby
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
  let upalaAdmin,
    manager1,
    persona1,
    persona2,
    persona3,
    persona4,
    delegate11,
    dapp,
    nobody

    // BEGIN. SETUP ENVIRONMENT (comment if loading from upala constants)
    // let env = await setupProtocol({ isSavingConstants: false })
    // ;[upalaAdmin, manager1, persona1, persona2, persona3, persona4, delegate11, dapp, nobody] = env.wallets
    // let upala = env.upala
    // let fakeDAI = env.dai
    // let upalaConstants = env.upalaConstants
    // END

    // BEGIN. LOAD ENVIRONMENT FROM UPALA CONSTANTS (comment if deploying anew)
  ;[upalaAdmin, manager1, persona1, persona2, persona3, persona4, delegate11, dapp, nobody] = await ethers.getSigners()
  let upalaConstants = new UpalaConstants(await upalaAdmin.getChainId())
  let upala = upalaConstants.getContract('Upala', upalaAdmin)
  let fakeDAI = upalaConstants.getContract('DAI', upalaAdmin)
  // END

  console.log(
    chalk.green.bold('\nProtocol: '),
    chalk.green('\nupalaAdmin: '),
    upalaAdmin.address,
    chalk.green('\nupala:'),
    upala.address,
    chalk.green('\nDAI:'),
    fakeDAI.address
  )

  // create pool
  console.log(chalk.green.bold('\nPool: '), chalk.green('\nmanager1: '), manager1.address)
  let signedScoresPool = await deployPool('SignedScoresPool', manager1, upalaConstants)
  console.log(chalk.green('signedScoresPool:'), signedScoresPool.address)
  // transfer DAI to pool address
  await fakeDAI.connect(manager1).freeDaiToTheWorld(signedScoresPool.address, POOL_FUNDING)
  console.log(chalk.gray('fakeDAI sent'))

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
  console.log(chalk.green('Base score: '), BASE_SCORE)
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

  // change owner
  // update metadata
  // more delegates to test reverse lookup

  // USER ACTIONS
  // create id
  console.log(
    chalk.green.bold('\nUsers: '),
    chalk.green('\npersona1: '),
    persona1.address,
    chalk.green('\ndelegate11: '),
    delegate11.address
  )
  let persona1id = await newIdentity(persona1.address, persona1, upalaConstants)
  console.log(chalk.green('persona1id'), persona1id)
  let persona2id = await newIdentity(persona2.address, persona2, upalaConstants)
  console.log(chalk.green('persona2id'), persona2id)

  // // register persona1 delegate
  tx = await upala.connect(delegate11).approveDelegation(persona1id)
  await tx.wait(numConfirmations(await delegate11.getChainId()))
  console.log(chalk.gray('delegate11 approved delegation'))

  tx = await upala.connect(persona1).approveDelegate(delegate11.address)
  await tx.wait(numConfirmations(await delegate11.getChainId()))
  console.log(chalk.gray('persona1 approved delegate11 as delegate'))

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
/* output 20.04.2022 (constants not saved)
Protocol:  
upalaAdmin:  0xa88630300706488e9d31597ccC4394206F4D4C6C 
upala: 0x59FcEd8395A4d97F0b9F9e1Fd43C4B0C9ff71e53 
DAI: 0xbC0dFaA78fe7bc8248b9F857292f680a1630b0C5

Pool:  
manager1:  0xb94f953f389c45AD3fb71dC917f09eE9DF89e722
signedScoresPool: 0xe9b4513cec3FA62027A922fA4b56E3023BE89980
fakeDAI sent
Base score:  BigNumber { _hex: '0x1bc16d674ec80000', _isBigNumber: true }
subBundle1: 0x00000000000000000000000000000000598de248af93c7b853abcc219893cd07
subBundle2: 0x00000000000000000000000000000000389f83dcc81ef8f024ab3b9814105e2f
subBundle1 deleted

Users:  
persona1:  0xd6287A66771aD5Ff1E56a4aA21F5B424b90A7fAF 
delegate11:  0x613bb366C1C14E506e077fF71B8537B9877F8c76
persona1id 0x242D51Ff0d2190A71A3f9C25D299F99b0f17f926
persona2id 0x8F799CF0Adec53947813d3fd3E3D90056Faf2b67
delegate11 approved delegation
persona1 approved delegate11 as delegate

Bot attack payload example:  
poolAddress:  0xe9b4513cec3FA62027A922fA4b56E3023BE89980 
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
