/*
Testing both Signed scores pool and it's parent BundledScoresPool as
there's not much difference.
*/

const { ethers } = require('hardhat')
const { expect } = require('chai')
const { BigNumber, utils } = require('ethers')
const { setupProtocol } = require('../src/upala-admin.js')
const { deployPool, attachToPool, PoolManager } = require('@upala/group-manager')
const { newIdentity } = require('@upala/unique-human')

// const PoolManager = require('@upala/group-manager')
const poolAbi = require('../artifacts/contracts/pools/signed-scores-pool.sol/SignedScoresPool.json')
let oneETH = BigNumber.from(10).pow(18)
//const scoreChange = oneETH.mul(42).div(100)
const ZERO_BYTES32 = '0x0000000000000000000000000000000000000000000000000000000000000000'
const RANDOM_SCORE_42 = 42 // do not use 42 anywhere else
const RANDOM_ADDRESS = '0x0c2788f417685706f61414e4Cb6F5f672eA79731'
/***********
MANAGE GROUP
************/

describe('MANAGE GROUP', function () {
  let upalaAdmin, manager1, nobody
  let signedScoresPool

  before('setup protocol', async () => {
    let env = await setupProtocol({ isSavingConstants: false })
    ;[upalaAdmin, manager1, nobody] = env.wallets
    signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
  })

  it('group manager can publish new bundle', async function () {
    await expect(signedScoresPool.connect(nobody).publishScoreBundleId(ZERO_BYTES32)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    tx = await signedScoresPool.connect(manager1).publishScoreBundleId(ZERO_BYTES32)
    let txTimestamp = (await ethers.provider.getBlock(tx.blockNumber)).timestamp
    let bundleTimestamp = await signedScoresPool.scoreBundleTimestamp(ZERO_BYTES32)
    expect(bundleTimestamp).to.eq(txTimestamp)
  })
})
/*
  it('group manager can publish group meta', async function () {
    assert.fail('actual', 'expected', 'Error message')
    // db_url, description, etc. - from future
  })

  it('group manager can set base score', async function () {
    // initializing Upala manager
    let env = await setupProtocol({ isSavingConstants: false })
    upala = env.upala
    ;[upalaAdmin, nobody] = env.wallets

    // inititalizing pool poolManagerWallet
    // var poolManager = new PoolManager({
    //   wallet: poolManagerWallet,
    //   overrideAddresses: upalaManager.getAddresses(),
    // })
    // console.log('decrease')
    // console.log(await poolManager.deployPool('SignedScoresPool'))
    // const hash = events[0].args[0];

    expect(1).to.be.equal(2)
  })

  it('group manager can delete bundle', async function () {
    // todo
  })

  it('group manager can withdraw money from pool', async function () {
    // todo
  })

  /*
  it('OWNERSHIP', function () {
  // can setGroupManager
  // only owner can setGroupManager
  // old manager can now manage new group
  // still got access to pool
})
*/

/*********************
SCORING AND BOT ATTACK
**********************/
// strategy:
// use myScore function to check most of the require conditions
// then use userScore to check if dapps can querry scores
// then use attack to check funds distribution
// persona - use this name to describe Eth address with score
// nobody - not registered person
describe('SCORING AND BOT ATTACK', function () {
  let upalaAdmin, manager1, nobody
  let persona1id
  let upala
  let signedScoresPool
  let emptyScoreBundle = '0x0000000000000000000000000000000000000000000000000000000000000001'

  before('setup protocol, register users', async () => {
    let env = await setupProtocol({ isSavingConstants: false })
    ;[upalaAdmin, manager1, persona1, nobody] = env.wallets
    signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
    // register empty score bundle
    await signedScoresPool.connect(manager1).publishScoreBundleId(emptyScoreBundle)
    persona1id = await newIdentity(persona1.address, persona1, env.upalaConstants)
  })

  it('cannot verify scores over non-existent score bundle', async function () {
    await expect(
      signedScoresPool
        .connect(nobody)
        .myScore(RANDOM_ADDRESS, RANDOM_ADDRESS, RANDOM_SCORE_42, ZERO_BYTES32, ZERO_BYTES32)
    ).to.be.revertedWith('Provided score bundle does not exist or deleted')
  })

  it('cannot verify scores without UpalaID', async function () {
    // no UpalaID at all
    await expect(
      signedScoresPool
        .connect(nobody)
        .myScore(RANDOM_ADDRESS, RANDOM_ADDRESS, RANDOM_SCORE_42, emptyScoreBundle, ZERO_BYTES32)
    ).to.be.revertedWith(
      'Upala: No such id, not an owner or not a delegate of the id' // todo better 'No Upala ID'?
    )
    // todo existing UpalaID but not an owner
    // await expect(signedScoresPool.connect(nobody).myScore(
    //   RANDOM_ADDRESS,
    //   RANDOM_ADDRESS,
    //   RANDOM_SCORE_42,
    //   emptyScoreBundle,
    //   ZERO_BYTES32
    // )).to.be.revertedWith(
    //   'Upala: No such id, not an owner or not a delegate of the id'  // todo better 'No Upala ID'?
    // )
    // existing UpalaID and valid owner but score assigned to non-existant delegate
  })

  // register UpalaID for the persona
  // try myScore on non-existent persona delegate
  //
  // should throw
  // register persona delegate
  // try myScore on empty pool
  // should throw "Pool balance is lower than the total score"
  // fund pool
  // try myScore on random proof
  // should throw with "Can't validate that scoreAssignedTo-score pair is in the bundle"
  // create valid proof
  // try myScore with valid proof
  // assign scores both to UpalaId and delegate address
  // try checking scores both for UpalaID and delegate address
  // this should work
  // try userScore
  // it('DApp can verify user score by Upala ID or delegate', async function () {
  // try checking scores both for UpalaID and delegate address
  // try attack by UpalaID
  // explode by UpalaID
  // check reward
  // check UpalaID is deleted
  // try attack by delegate address
})
/*
describe('SCORING AND BOT ATTACK', function () {
  before('register users', async () => {
    ;[upala, fakeDai, wallets] = await setupProtocol()
    ;[upalaAdmin, manager1] = wallets.slice(0, 2)
    ;[signedScoresPoolFactory, signedScoresPool] = await setUpPoolFactoryAndPool(
      upala,
      fakeDai,
      'SignedScoresPoolFactory',
      upalaAdmin,
      manager1
    )
  })



  })

  it('you can explode, you can explode, you can explode, anyone can exploooooode', async function () {
    ///function attack(uint160 groupID, uint160 identityID, uint8 score, bytes32[] calldata proof)

    /// hack

    const TEST_MESSAGE = web3.utils.sha3('Human')
    // Create the signature
    // web3 adds "\x19Ethereum Signed Message:\n32" to the hashed message
    const signature = await web3.eth.sign(TEST_MESSAGE, manager1.address)

    // Recover the signer address from the generated message and signature.
    const recovered = await signedScoresPool.hack_recover(TEST_MESSAGE, signature)
    expect(recovered).to.equal(manager1.address)
  })

  it('cannot explode from an arbitrary address', async function () {})

  it('cannot explode using delegate address', async function () {})

  it('Upala ID owner can explode (check fees and rewards)', async function () {})
})
*/
