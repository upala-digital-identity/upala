// Script to test subgraph
// The subgraph itself is in this repo - https://github.com/upala-digital-identity/subgraph
// As of March 10 2022 the draft subgraph is already deployed to graph studio
// and tired to Rinkeby contract.
// This script will test that all info gets into graph properly.
// Should cover all cases from Requirements for the subgraph -
// https://github.com/upala-digital-identity/subgraph-schema

// Bot manager testing
// Same script is used to test bot manager cli locally
const fs = require('fs')
const chalk = require('chalk')
const { ethers } = require('hardhat')
const { utils } = require('ethers')
const { setupProtocol } = require('../src/upala-admin.js')
const { deployPool, PoolManager } = require('@upala/group-manager')
const { newIdentity } = require('@upala/unique-human')

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
  //   await manager1.sendTransaction({
  //     to: BOT_ADDRESS,
  //     value: ethers.utils.parseEther("0.001")
  //     });
  // create pool
  let signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
  // transfer DAI to pool address
  await fakeDAI.connect(manager1).freeDaiToTheWorld(signedScoresPool.address, POOL_FUNDING)

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
  let subBundle2 = await poolManager2.publishNew(users2)

  // delete bundle
  await poolManager1.deleteScoreBundleId(subBundle1.public.bundleID)
  // todo create another pool

  // USER ACTIONS
  // create id
  let persona1id = await newIdentity(persona1.address, persona1, env.upalaConstants)
  let persona2id = await newIdentity(persona2.address, persona2, env.upalaConstants)

  // // register persona1 delegate
  await upala.connect(delegate11).approveDelegation(persona1id)
  await upala.connect(persona1).approveDelegate(delegate11.address)

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

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
