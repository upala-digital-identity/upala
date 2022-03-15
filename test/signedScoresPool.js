/*
Testing both Signed scores pool and it's parent BundledScoresPool as
there's not much difference.
*/

const { expect } = require('chai')
const { BigNumber, utils } = require('ethers')
const { setupProtocol } = require('../src/upala-admin.js')
// const PoolManager = require('@upala/group-manager')
const poolAbi = require('../artifacts/contracts/pools/signed-scores-pool.sol/SignedScoresPool.json')
let oneETH = BigNumber.from(10).pow(18)
console.log('GROUP')

/***********
MANAGE GROUP
************/

describe('MANAGE GROUP', function () {
  let upala
  let unusedFakeDai
  let wallets
  //const scoreChange = oneETH.mul(42).div(100)
  it('group manager can publish new bundle', async function () {
    // todo check that only owner can publish a bundle
    await upala.connect(manager1).publishRoot(someRoot)
    expect(await upala.roots(manager1Group, someRoot)).to.eq((await time.latest()).toString())
  })

  it('group manager can publish group meta', async function () {
    assert.fail('actual', 'expected', 'Error message')
    // db_url, description, etc. - from future
  })

  it('group manager can set base score', async function () {
    // initializing Upala manager
    let environment = await setupProtocol({ isSavingConstants: false })
    upala = environment.upala
    ;[upalaAdmin, nobody] = environment.wallets

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
})

/*********************
SCORING AND BOT ATTACK
**********************/

describe('SCORING AND BOT ATTACK', function () {
  // todo setup protocol
  let upala
  let fakeDai
  let signedScoresPoolFactory
  let signedScoresPool
  let wallets
  let upalaAdmin
  let manager1

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

  describe('VERIFYING SCORES', function () {
    // strategy:
    // use myScore function to check most of the require conditions
    // then use userScore to check if dapps can querry scores
    // then use attack to check funds distribution

    // persona - use this name to describe Eth address with score
    // nobody - not registered person

    // setup protocol

    // try myScore on non-existent score bundle
    // should throw "Provided score bundle does not exist or deleted"
    // register a score bundle

    // try myScore on persona address withou UpalaID
    // should throw
    // register UpalaID for the persona

    // try myScore on non-existent persona delegate
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
