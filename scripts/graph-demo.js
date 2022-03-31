// Script to test subgraph
// The subgraph itself is in this repo - https://github.com/upala-digital-identity/subgraph
// As of March 10 2022 the draft subgraph is already deployed to graph studio
// and tired to Rinkeby contract.
// This script will test that all info gets into graph properly.
// Should cover all cases from Requirements for the subgraph -
// https://github.com/upala-digital-identity/subgraph-schema

const fs = require('fs')
const { ethers } = require('hardhat')
const { expect } = require('chai')
const { utils } = require('ethers')
const { setupProtocol } = require('../src/upala-admin.js')
const { deployPool, PoolManager } = require('@upala/group-manager')
const { newIdentity } = require('@upala/unique-human')

const ZERO_BYTES32 = '0x0000000000000000000000000000000000000000000000000000000000000000'
const A_SCORE_BUNDLE = '0x0000000000000000000000000000000000000000000000000000000000000001'
const USER_RATING_42 = 42 // do not use 42 anywhere else
const BASE_SCORE = ethers.utils.parseEther('2.5')
const RANDOM_ADDRESS = '0x0c2788f417685706f61414e4Cb6F5f672eA79731'

async function main() {
  // GROUP MANAGER ACTIONS
  let env = await setupProtocol({ isSavingConstants: false })
  let upalaAdmin, manager1, persona1, persona2, persona3, persona4, delegate11, dapp, nobody
  ;[upalaAdmin, manager1, persona1, persona2, persona3, persona4, delegate11, dapp, nobody] = env.wallets

  let upala = env.upala
  let fakeDAI = env.dai

  // create pool
  let signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
  // transfer DAI to pool address
  await fakeDAI.connect(manager1).freeDaiToTheWorld(signedScoresPool.address, BASE_SCORE.mul(USER_RATING_42))

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
    { address: persona1.address, score: USER_RATING_42 },
    { address: persona2.address, score: USER_RATING_42 + 1 },
  ]
  let users2 = [
    { address: persona3.address, score: USER_RATING_42 + 2 },
    { address: persona4.address, score: USER_RATING_42 + 3 },
  ]
  let subBundle1 = await poolManager1.publishNew(users1)
  let subBundle2 = await poolManager2.publishNew(users2)

  // delete bundle
  await poolManager1.deleteScoreBundleId(subBundle2.public.bundleID)
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
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
