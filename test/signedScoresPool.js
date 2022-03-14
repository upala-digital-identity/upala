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

  it('group manager can delete bundle at any time', async function () {
    // todo
  })

  it('group manager can withdraw money from pool at any time', async function () {
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
    // strategy
    // persona - use this name to describe Eth address with score
    // nobody - not registered person
    // use myScore function to check most of the require conditions
    // then use userScore to check if dapps can querry scores
    // then use attack to check funds distribution

    // todo setup protocol

    // An existing score bundle is needed
    // try non-existent score bundle
    // "Provided score bundle does not exist or deleted"

    // isOwnerOrDelegate
    // try nobody - get error
    // register UpalaID for the persona
    //

    it('can verify own score', async function () {
      //  function verifyMyScore (uint160 groupID, uint160 identityID, address holder, uint8 score, bytes32[] calldata proof) external {
    })

    it('cannot approve scores from an arbitrary address', async function () {})
  })

  describe('DAPPS VERIFYING SCORES', function () {
    // todo setup protocol

    it('DApp can verify user score', async function () {
      // function verifyUserScore (uint160 groupID, uint160 identityID, address holder, uint8 score, bytes32[] calldata proof) external {
    })

    it('An address approved by Upala ID owner can approve scores to DApps', async function () {})
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
