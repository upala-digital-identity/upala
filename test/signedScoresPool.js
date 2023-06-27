/*
Testing both Signed scores pool and it's parent BundledScoresPool as
there's not much difference.
*/

const fs = require('fs')
const { ethers } = require('hardhat')
const { expect } = require('chai')
const { utils } = require('ethers')
const { setupProtocol } = require('../src/upala-admin.js')
const { deployPool, PoolManager } = require('@upala/group-manager')
const { newIdentity } = require('@upala/unique-human')

//const scoreChange = oneETH.mul(42).div(100)
const ZERO_BYTES32 = '0x0000000000000000000000000000000000000000000000000000000000000000'
const A_SCORE_BUNDLE = '0x0000000000000000000000000000000000000000000000000000000000000001'
const USER_RATING_42 = 42 // do not use 42 anywhere else
const BASE_SCORE = ethers.utils.parseEther('2.5')
const RANDOM_ADDRESS = '0x0c2788f417685706f61414e4Cb6F5f672eA79731'

/***********
MANAGE GROUP
************/

describe('MANAGE GROUP', function () {
  let upalaAdmin, manager1, manager2, nobody
  let signedScoresPool
  let fakeDAI

  before('setup protocol', async () => {
    let env = await setupProtocol({ isSavingConstants: false })
    ;[upalaAdmin, manager1, manager2, nobody] = env.wallets
    fakeDAI = env.dai
    signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
  })

  it('group manager can publish and delete bundle', async function () {
    // publish
    await expect(signedScoresPool.connect(nobody).publishScoreBundleId(ZERO_BYTES32)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    const tx = await signedScoresPool.connect(manager1).publishScoreBundleId(ZERO_BYTES32)
    let txTimestamp = (await ethers.provider.getBlock(tx.blockNumber)).timestamp
    let bundleTimestamp = await signedScoresPool.scoreBundleTimestamp(ZERO_BYTES32)
    expect(bundleTimestamp).to.eq(txTimestamp)
    await expect(tx).to.emit(signedScoresPool, 'NewScoreBundleId').withArgs(ZERO_BYTES32, bundleTimestamp)

    // cannot publish again
    await expect(signedScoresPool.connect(manager1).publishScoreBundleId(ZERO_BYTES32)).to.be.revertedWith(
      'Pool: Score bundle id already exists'
    )

    // delete bundle
    await expect(signedScoresPool.connect(manager1).deleteScoreBundleId(A_SCORE_BUNDLE)).to.be.revertedWith(
      "Score bundle id does't exists"
    )
    await expect(signedScoresPool.connect(nobody).deleteScoreBundleId(ZERO_BYTES32)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    const delTx = await signedScoresPool.connect(manager1).deleteScoreBundleId(ZERO_BYTES32)
    await expect(delTx).to.emit(signedScoresPool, 'ScoreBundleIdDeleted').withArgs(ZERO_BYTES32)
    let deletedBundleTimestamp = await signedScoresPool.scoreBundleTimestamp(ZERO_BYTES32)
    expect(deletedBundleTimestamp).to.eq(0)
  })

  it('group manager can publish group meta', async function () {
    let newMeta = 'If you are reading this you are the resistance'
    await expect(signedScoresPool.connect(nobody).updateMetadata(newMeta)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    const metaTx = await signedScoresPool.connect(manager1).updateMetadata(newMeta)
    expect(await signedScoresPool.metaData()).to.be.equal(newMeta)
    await expect(metaTx).to.emit(signedScoresPool, 'MetaDataUpdate').withArgs(newMeta)
  })

  it('group manager can withdraw money from pool', async function () {
    // fill the pool
    let totalFunding = ethers.utils.parseEther('234')
    await fakeDAI.connect(nobody).freeDaiToTheWorld(signedScoresPool.address, totalFunding)
    let poolBalBefore = await fakeDAI.balanceOf(signedScoresPool.address)
    let manager1BalBefore = await fakeDAI.balanceOf(manager1.address)
    await expect(signedScoresPool.connect(nobody).withdrawFromPool(manager1.address, poolBalBefore)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )

    // try withdraw part of the pool funds
    let smallWithdrawal = ethers.utils.parseEther('2')
    await signedScoresPool.connect(manager1).withdrawFromPool(manager1.address, smallWithdrawal)
    let poolBalAfter = await fakeDAI.balanceOf(signedScoresPool.address)
    let manager1BalAfter = await fakeDAI.balanceOf(manager1.address)
    expect(smallWithdrawal).to.be.equal(poolBalBefore.sub(poolBalAfter))
    expect(smallWithdrawal).to.be.equal(manager1BalAfter.sub(manager1BalBefore))

    // try withdraw more than there is in the pool
    let exceedingWithdrawal = poolBalBefore.mul(2)
    await signedScoresPool.connect(manager1).withdrawFromPool(manager1.address, exceedingWithdrawal)
    let poolBalAfterAfter = await fakeDAI.balanceOf(signedScoresPool.address)
    let manager1BalAfterAfter = await fakeDAI.balanceOf(manager1.address)
    expect(poolBalAfterAfter).to.be.equal(0)
    expect(manager1BalAfterAfter).to.be.equal(poolBalBefore.add(manager1BalBefore))
  })

  it('group manager can change owner', async function () {
    await expect(signedScoresPool.connect(nobody).transferOwnership(manager2.address)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    await signedScoresPool.connect(manager1).transferOwnership(manager2.address)
    expect(await signedScoresPool.owner()).to.be.equal(manager2.address)
    await expect(signedScoresPool.connect(manager1).transferOwnership(manager1.address)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    await signedScoresPool.connect(manager2).transferOwnership(manager1.address)
    expect(await signedScoresPool.owner()).to.be.equal(manager1.address)
  })

  // TODO when changing owner scores will stop working (create a warning in CLI for that too)
})

/*********************
SCORING AND BOT ATTACK
**********************/
// strategy:
// use myScore function to check most of the require conditions
// then use userScore to check if dapps can querry scores
// then use attack to check funds distribution
// persona - use this name to describe Eth address with score
// nobody - not registered person

describe('SCORING AND BOT ATTACK BASIC', function () {
  let upalaAdmin, manager1, persona1, delegate11, dapp, nobody
  let persona1id
  let upala, fakeDAI
  let signedScoresPool
  let env

  beforeEach('setup protocol', async () => {
    env = await setupProtocol({ isSavingConstants: false })
    ;[upalaAdmin, manager1, persona1, delegate11, dapp, nobody] = env.wallets
    upala = env.upala
    fakeDAI = env.dai
  })

  it('cannot verify scores with zero baseScore', async function () {
    zeroBaseScorePool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
    await expect(
      zeroBaseScorePool
        .connect(nobody)
        .myScore(RANDOM_ADDRESS, RANDOM_ADDRESS, USER_RATING_42, ZERO_BYTES32, ZERO_BYTES32)
    ).to.be.revertedWith('Pool baseScore is 0')
  })

  // publish random score bundle
  it('cannot verify scores over non-existent score bundle', async function () {
    signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
    await signedScoresPool.connect(manager1).setBaseScore(1)

    await expect(
      signedScoresPool
        .connect(nobody)
        .myScore(RANDOM_ADDRESS, RANDOM_ADDRESS, USER_RATING_42, ZERO_BYTES32, ZERO_BYTES32)
    ).to.be.revertedWith('Pool: Provided score bundle does not exist or deleted')
  })

    // quick way to check the right soup that makes recover work correclty
  it('signes and recovers address correctly', async function () {
    const message = utils.solidityKeccak256(
      ['address', 'uint8', 'bytes32'],
      [RANDOM_ADDRESS, USER_RATING_42, ZERO_BYTES32]
    )
    const wrongMessage = utils.solidityKeccak256(
      ['address', 'uint8', 'bytes32'],
      [RANDOM_ADDRESS, USER_RATING_42 + 1, ZERO_BYTES32]
    )
    // note the arrayify function here!!!
    let proof = await manager1.signMessage(ethers.utils.arrayify(message))
    signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
    // rigth message and proof
    let signer = await signedScoresPool.testRecover(message, proof)
    expect(signer).to.be.equal(manager1.address)
    // wrong message, right proof
    signer = await signedScoresPool.testRecover(wrongMessage, proof)
    expect(signer).to.not.equal(manager1.address)
    // right message, wrong proof
    let wrongProof = await manager1.signMessage(ethers.utils.arrayify(wrongMessage))
    signer = await signedScoresPool.testRecover(message, wrongProof)
    expect(signer).to.not.equal(manager1.address)
  })

})


describe('SCORING AND BOT ATTACK ADVANCED', function () {
  let upalaAdmin, manager1, persona1, delegate11, dapp, nobody
  let persona1id
  let upala, fakeDAI
  let signedScoresPool
  let env

  beforeEach('setup protocol', async () => {
    env = await setupProtocol({ isSavingConstants: false })
    ;[upalaAdmin, manager1, persona1, delegate11, dapp, nobody] = env.wallets
    upala = env.upala
    fakeDAI = env.dai
    // deploy Pool and set baseScore
    signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
    await signedScoresPool.connect(manager1).setBaseScore(BASE_SCORE)
    // register empty score bundle
    await signedScoresPool.connect(manager1).publishScoreBundleId(A_SCORE_BUNDLE)
  })
  // register UpalaID and delegate

  it('cannot verify scores without valid UpalaID or delegate', async function () {
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
        signedScoresPool.connect(args[0]).myScore(args[1], args[2], USER_RATING_42, A_SCORE_BUNDLE, ZERO_BYTES32)
      ).to.be.revertedWith('Upala: No such id, not an owner or not a delegate of the id')
    }
  })

  // register persona delegate, try myScore on empty pool
  it('should throw if pool has insufficient funds', async function () {
    // register persona1 id
    persona1id = await newIdentity(persona1.address, persona1, env.upalaConstants)
    // register persona1 delegate
    await upala.connect(delegate11).askDelegation(persona1id)
    await upala.connect(persona1).approveDelegate(delegate11.address)

    let validScoreAssignedTo = [persona1.address, persona1id, delegate11.address]
    for (const scoreAssignedTo of validScoreAssignedTo) {
      await expect(
        signedScoresPool
          .connect(persona1)
          .myScore(persona1id, scoreAssignedTo, USER_RATING_42, A_SCORE_BUNDLE, ZERO_BYTES32)
      ).to.be.revertedWith('Pool: Pool balance is lower than the total score')
    }
  })


  // fund pool
  // try myScore on random proof
  // try valid proof
  // try liquidate
  it('you can liquidate, you can liquidate, anyone can liquidaaaaate', async function () {
    // register persona1 id
    persona1id = await newIdentity(persona1.address, persona1, env.upalaConstants)

    // fill the pool
    await fakeDAI.connect(manager1).freeDaiToTheWorld(signedScoresPool.address, BASE_SCORE.mul(USER_RATING_42))

    // sign user
    let proof = await manager1.signMessage(
      ethers.utils.arrayify(
        utils.solidityKeccak256(['address', 'uint8', 'bytes32'], [persona1id, USER_RATING_42, A_SCORE_BUNDLE])
      )
    )
    // check valid proof requirement - no state change
    await expect(
      signedScoresPool.connect(persona1).myScore(persona1id, persona1id, USER_RATING_42 - 1, A_SCORE_BUNDLE, proof)
    ).to.be.revertedWith("Pool: Can't validate that scoreAssignedTo-score pair is in the bundle")
    // check myScore
    expect(
      await signedScoresPool.connect(persona1).myScore(persona1id, persona1id, USER_RATING_42, A_SCORE_BUNDLE, proof)
    ).to.be.equal(BASE_SCORE.mul(USER_RATING_42))
    // check useScore (a dapp call) - no state change
    expect(
      await signedScoresPool
        .connect(dapp)
        .userScore(persona1.address, persona1id, persona1id, USER_RATING_42, A_SCORE_BUNDLE, proof)
    ).to.be.equal(BASE_SCORE.mul(USER_RATING_42))

    // bot vs managers check
    // assign a score by address (a platform action)
    let delegateProof = await manager1.signMessage(
      ethers.utils.arrayify(
        utils.solidityKeccak256(['address', 'uint8', 'bytes32'], [delegate11.address, USER_RATING_42, A_SCORE_BUNDLE])
      )
    )
    // bot actions
    // 1. register UpalaID (no matter on which address, so using persona1 from above)
    // 2. register persona1 delegate (use address with score)
    await upala.connect(delegate11).askDelegation(persona1id)
    await upala.connect(persona1).approveDelegate(delegate11.address)
    // before
    let poolBalBefore = await fakeDAI.balanceOf(signedScoresPool.address)
    let botBalBefore = await fakeDAI.balanceOf(persona1.address)
    let upalaBalBefore = await fakeDAI.balanceOf(await upala.getTreasury())
    // liquidate
    await signedScoresPool
      .connect(persona1)
      .attack(persona1id, delegate11.address, USER_RATING_42, A_SCORE_BUNDLE, delegateProof)
    // after
    let poolBalAfter = await fakeDAI.balanceOf(signedScoresPool.address)
    let botBalAfter = await fakeDAI.balanceOf(persona1.address)
    let upalaBalAfter = await fakeDAI.balanceOf(await upala.getTreasury())
    // check rewards
    let totalScore = BASE_SCORE.mul(USER_RATING_42)
    let fee = totalScore.mul(await upala.getLiquidationFeePercent()).div(100)
    let reward = totalScore.sub(fee)
    expect(poolBalBefore.sub(poolBalAfter)).to.be.equal(totalScore) // pool balance decreased
    expect(botBalAfter.sub(botBalBefore)).to.be.equal(reward) // bot gets reward
    expect(upalaBalAfter.sub(upalaBalBefore)).to.be.equal(fee) // upala collects fee
    // try expolding again
    let validScoreAssignedTo = [persona1.address, persona1id, delegate11.address]
    for (const scoreAssignedTo of validScoreAssignedTo) {
      let prooof = await manager1.signMessage(
        ethers.utils.arrayify(
          utils.solidityKeccak256(['address', 'uint8', 'bytes32'], [scoreAssignedTo, USER_RATING_42, A_SCORE_BUNDLE])
        )
      )
      if (scoreAssignedTo == delegate11.address) {
        await expect(
          signedScoresPool
            .connect(delegate11)
            .attack(persona1id, scoreAssignedTo, USER_RATING_42, A_SCORE_BUNDLE, prooof)
        ).to.be.revertedWith('Upala: The id is already liquidated')
      } else {
        await expect(
          signedScoresPool.connect(persona1).attack(persona1id, scoreAssignedTo, USER_RATING_42, A_SCORE_BUNDLE, prooof)
        ).to.be.revertedWith('Upala: No such id, not an owner or not a delegate of the id')
      }
    }
  })

  // leaving it here for now, learn how it works!
  // (todo is web3.eth.sign deprecated?)
  // it('you can liquidate, you can liquidate, you can liquidate, anyone can liquidaaaaate', async function () {
  //   const TEST_MESSAGE = web3.utils.sha3('Human')
  //   // Create the signature
  //   // web3 adds "\x19Ethereum Signed Message:\n32" to the hashed message
  //   const signature = await web3.eth.sign(TEST_MESSAGE, manager1.address)
  //   // Recover the signer address from the generated message and signature.
  //   const recovered = await signedScoresPool.testRecover(TEST_MESSAGE, signature)
  //   expect(recovered).to.equal(manager1.address)
  // })
})


describe('POOL MANAGER', function () {
  let upalaAdmin, manager1, persona1, delegate11, persona2, nobody
  let upala, fakeDAI
  let signedScoresPool
  let env

  beforeEach('setup protocol', async () => {
    env = await setupProtocol({ isSavingConstants: false })
    ;[upalaAdmin, manager1, persona1, delegate11, persona2, nobody] = env.wallets
    upala = env.upala
    fakeDAI = env.dai
  })

  // quick check that main featrures of group manager work
  it('group manager can set base score', async function () {
    // deploy pool
    signedScoresPool = await deployPool('SignedScoresPool', manager1, env.upalaConstants)
    // fill the pool
    await fakeDAI.connect(manager1).freeDaiToTheWorld(signedScoresPool.address, BASE_SCORE.mul(USER_RATING_42 + 1))
    // set base score
    let localDBdir = 'local-db-mock'
    let scoreExplorerDBdir = 'score-exp-mock'
    if (fs.existsSync(localDBdir)) {
      fs.rmSync(localDBdir, { recursive: true, force: true })
    }
    if (fs.existsSync(scoreExplorerDBdir)) {
      fs.rmSync(scoreExplorerDBdir, { recursive: true, force: true })
    }

    let poolManager = new PoolManager(signedScoresPool, localDBdir, scoreExplorerDBdir)

    const baseScoreTx = await poolManager.setBaseScore(BASE_SCORE)
    await expect(baseScoreTx).to.emit(signedScoresPool, 'NewBaseScore').withArgs(BASE_SCORE)

    // register users
    let users = [
      { address: persona1.address, score: USER_RATING_42 },
      { address: persona2.address, score: USER_RATING_42 + 1 },
    ]
    let subBundle = await poolManager.publishNew(users)
    // persona1
    let persona1id = await newIdentity(persona1.address, persona1, env.upalaConstants)
    expect(
      await signedScoresPool
        .connect(persona1)
        .myScore(
          persona1id,
          persona1.address,
          USER_RATING_42,
          subBundle.public.bundleID,
          subBundle.public.signedUsers[0].signature
        )
    ).to.be.equal(BASE_SCORE.mul(USER_RATING_42))
    // persona2
    let persona2id = await newIdentity(persona2.address, persona2, env.upalaConstants)
    expect(
      await signedScoresPool
        .connect(persona2)
        .myScore(
          persona2id,
          persona2.address,
          USER_RATING_42 + 1,
          subBundle.public.bundleID,
          subBundle.public.signedUsers[1].signature
        )
    ).to.be.equal(BASE_SCORE.mul(USER_RATING_42 + 1))
  })
})
