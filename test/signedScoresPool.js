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
const exp = require('constants')
let oneETH = BigNumber.from(10).pow(18)
//const scoreChange = oneETH.mul(42).div(100)
const ZERO_BYTES32 = '0x0000000000000000000000000000000000000000000000000000000000000000'
const emptyScoreBundle = '0x0000000000000000000000000000000000000000000000000000000000000001'
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
  let upalaAdmin, manager1, persona1, delegate11, nobody
  let persona1id
  let upala, fakeDAI
  let signedScoresPool
  let env

  beforeEach('setup protocol, register users', async () => {
    env = await setupProtocol({ isSavingConstants: false })
    ;[upalaAdmin, manager1, persona1, delegate11, nobody] = env.wallets
    upala = env.upala
    fakeDAI = env.dai
  })
  /*
  it('cannot verify scores with zero baseScore', async function () {
    zeroBaseScorePool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
    await expect(
      zeroBaseScorePool
        .connect(nobody)
        .myScore(RANDOM_ADDRESS, RANDOM_ADDRESS, RANDOM_SCORE_42, ZERO_BYTES32, ZERO_BYTES32)
    ).to.be.revertedWith('Pool baseScore is 0')
  })

  // publish random score bundle
  it('cannot verify scores over non-existent score bundle', async function () {
    signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
    await signedScoresPool.connect(manager1).setBaseScore(1)
    
    await expect(
      signedScoresPool
        .connect(nobody)
        .myScore(RANDOM_ADDRESS, RANDOM_ADDRESS, RANDOM_SCORE_42, ZERO_BYTES32, ZERO_BYTES32)
    ).to.be.revertedWith('Provided score bundle does not exist or deleted')
  })

  // register UpalaID and delegate
  it('cannot verify scores without valid UpalaID or delegate', async function () {
    // deploy Pool and set baseScore
    signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
    await signedScoresPool.connect(manager1).setBaseScore(1)
    // register empty score bundle
    await signedScoresPool.connect(manager1).publishScoreBundleId(emptyScoreBundle)
    // register persona1 id
    persona1id = await newIdentity(persona1.address, persona1, env.upalaConstants)

    let badInput = [
      // [caller, upalaID, scoreAssignedTo]
      [nobody, RANDOM_ADDRESS, RANDOM_ADDRESS], // 000 no UpalaID at all
      [nobody, RANDOM_ADDRESS, persona1.address], // 001
      [nobody, persona1id, RANDOM_ADDRESS], // 010 existing UpalaID, but called by nobody
      [nobody, persona1id, persona1.address], // 011 existing UpalaID, existing delegate, but called by nobody
      [persona1, RANDOM_ADDRESS, RANDOM_ADDRESS], // 100 no UpalaID at all
      [persona1, RANDOM_ADDRESS, persona1.address], // 101
      [persona1, persona1id, RANDOM_ADDRESS], // 110 existing UpalaID, valid owner but score assigned to non-existant delegate
      // [persona1, persona1id, persona1.address],  // 111 valid
    ]
    for (const args of badInput) {
      await expect(
        signedScoresPool.connect(args[0]).myScore(args[1], args[2], RANDOM_SCORE_42, emptyScoreBundle, ZERO_BYTES32)
      ).to.be.revertedWith('Upala: No such id, not an owner or not a delegate of the id')
    }
  })

  // register persona delegate, try myScore on empty pool
  it('should throw if pool has insufficient funds', async function () {
    // deploy Pool and set baseScore
    signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
    await signedScoresPool.connect(manager1).setBaseScore(1)
    // register empty score bundle
    await signedScoresPool.connect(manager1).publishScoreBundleId(emptyScoreBundle)
    // register persona1 id
    persona1id = await newIdentity(persona1.address, persona1, env.upalaConstants)
    // register persona1 delegate
    await upala.connect(persona1).approveDelegate(delegate11.address)

    let validScoreAssignedTo = [persona1.address, persona1id, delegate11.address]
    for (const scoreAssignedTo of validScoreAssignedTo) {
      await expect(
        signedScoresPool
          .connect(persona1)
          .myScore(persona1id, scoreAssignedTo, RANDOM_SCORE_42, emptyScoreBundle, ZERO_BYTES32)
      ).to.be.revertedWith('Pool balance is lower than the total score')
    }
  })
*/

  // quick way to check the right soup that makes recover work correclty
  it('signes and recovers address correctly', async function () {
    const message = utils.solidityKeccak256(
      ['address', 'uint8', 'bytes32'],
      [RANDOM_ADDRESS, RANDOM_SCORE_42, ZERO_BYTES32]
    )
    // note the arrayify function here!!!
    let proof = await manager1.signMessage(ethers.utils.arrayify(message))
    signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
    let signer = await signedScoresPool.hack_recover(message, proof)
    expect(signer).to.be.equal(manager1.address)
  })

  // fund pool
  // try myScore on random proof
  // try myScore on empty pool
  it('should throw with invalid proof', async function () {
    // deploy Pool and set baseScore
    signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
    await signedScoresPool.connect(manager1).setBaseScore(1)
    // register empty score bundle
    await signedScoresPool.connect(manager1).publishScoreBundleId(emptyScoreBundle)
    // register persona1 id
    persona1id = await newIdentity(persona1.address, persona1, env.upalaConstants)
    // register persona1 delegate
    await upala.connect(persona1).approveDelegate(delegate11.address)
    // fill the pool
    await fakeDAI.connect(manager1).freeDaiToTheWorld(signedScoresPool.address, RANDOM_SCORE_42)
    // sign user
    const message = utils.solidityKeccak256(
      ['address', 'uint8', 'bytes32'],
      [persona1id, RANDOM_SCORE_42, emptyScoreBundle]
    )
    let proof = await manager1.signMessage(ethers.utils.arrayify(message))

    // (await signedScoresPool
    //     .connect(persona1)
    //     .myScore(persona1id, persona1id, RANDOM_SCORE_42, emptyScoreBundle, proof)).toNumber()

    await expect(
      signedScoresPool
        .connect(persona1)
        .myScore(persona1id, persona1id, 41, emptyScoreBundle, proof)
    ).to.be.revertedWith('Can\'t validate that scoreAssignedTo-score pair is in the bundle')
  })

  // leaving it here for now, because it is not clear how it works
  it('you can explode, you can explode, you can explode, anyone can exploooooode', async function () {
    const TEST_MESSAGE = web3.utils.sha3('Human')
    // Create the signature
    // web3 adds "\x19Ethereum Signed Message:\n32" to the hashed message
    const signature = await web3.eth.sign(TEST_MESSAGE, manager1.address)
    // Recover the signer address from the generated message and signature.
    const recovered = await signedScoresPool.hack_recover(TEST_MESSAGE, signature)
    expect(recovered).to.equal(manager1.address)
  })

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

  it('cannot explode from an arbitrary address', async function () {})

  it('cannot explode using delegate address', async function () {})

  it('Upala ID owner can explode (check fees and rewards)', async function () {})
})
*/
