const { expect } = require('chai')
const { BigNumber, utils } = require('ethers')
const { resetProtocol, deployContract, setUpPoolFactoryAndPool } = require('./deploy-helper.js');

let oneETH = BigNumber.from(10).pow(18)
// let fakeUBI = oneETH.mul(100)



/************************
          GROUPS
*************************/

describe('GROUPS', function () {
  let upala
  let fakeDai
  let signedScoresPoolFactory
  let wallets

  before('register users', async () => {
    [upala, fakeDai, wallets] = await resetProtocol()
    ;[upalaAdmin, user1, user2, user3, manager1, manager2, delegate1, delegate2, delegate3, nobody] = wallets
    signedScoresPoolFactory = await deployContract('SignedScoresPoolFactory', upala.address, fakeDai.address)
  })


  describe('registration', function () {
    it('can only register an approved pool', async function () {
      // approve pool factory
      await upala.connect(upalaAdmin).setApprovedPoolFactory(signedScoresPoolFactory.address, 'true').then((tx) => tx.wait())
      expect(await upala.approvedPoolFactories(signedScoresPoolFactory.address)).to.eq(true)
      // todo only Upala admin 


      // spawn a new pool by the factory
      const tx = await signedScoresPoolFactory.connect(manager1).createPool()
      const receipt = await tx.wait(1)
      const newPoolEvent = receipt.events.filter((x) => {
        return x.event == 'NewPool'
      })
      const newPoolAddress = newPoolEvent[0].args.poolAddress
      const poolContract = (await ethers.getContractFactory('SignedScoresPool')).attach(newPoolAddress)

      expect(await upala.approvedPools(newPoolAddress)).to.eq(signedScoresPoolFactory.address)

      // try to spawn a pool from a not approved factory
      // await expect(signedScoresPoolFactory2.connect(manager1).createPool()).to.be.revertedWith('Pool factory is not approved')

    })

    // it('only owner can increase score', async function () {
    //   const signedScoresPool = await newPool(signedScoresPoolFactory, manager1);

    //   await signedScoresPool.connect(manager1).increaseBaseScore(1);
    //   await expect(signedScoresPool.connect(manager2).increaseBaseScore(2)).to.be.revertedWith(
    //     'Ownable: caller is not the owner'
    //   )
    // })
  })
})

  /*
  describe('commitments', function () {
    it('a group can issue a commitment', async function () {
      const someHash = utils.formatBytes32String('First commitment!')
      await upala.connect(manager1).commitHash(someHash)
      const now = await time.latest()
      expect(await upala.commitsTimestamps(manager1Group, someHash)).to.eq(now.toString())
      // fast-forward
      await time.increase(1000)
      const otherHash = utils.formatBytes32String('Second commitment!')
      await upala.connect(manager1).commitHash(otherHash)
      const then = await time.latest()
      expect(await upala.commitsTimestamps(manager1Group, otherHash)).to.eq(then.toString())
    })

    it("two groups can issue identical commitments (cannot overwrite other group's commitment)", async function () {
      const someHash = utils.formatBytes32String('We have identical commitments!')
      await upala.connect(manager1).commitHash(someHash)
      await upala.connect(manager2).commitHash(someHash)
      const timestamp1 = await upala.commitsTimestamps(manager1Group, someHash)
      const timestamp2 = await upala.commitsTimestamps(manager2Group, someHash)
      expect(timestamp2.sub(timestamp1)).to.eq(1)
    })
  })

  describe('score management', function () {
    let attackWindow
    let executionWindow
    let hash
    const scoreChange = oneETH.mul(42).div(100)
    const secret = utils.formatBytes32String('Zuckerberg is a human')
    const wrongSecret = utils.formatBytes32String('dfg')

    before('register users', async () => {
      attackWindow = await upala.attackWindow()
      executionWindow = await upala.executionWindow()
      if (attackWindow.toNumber() < 600 || executionWindow < 600) {
        throw 'attackWindow or executionWindow are too short for the tests!'
      }
    })

    describe('increase base score', function () {
      it('Group manager can increase base score immediately', async function () {
        const scoreBefore = await upala.connect(manager1).groupBaseScore(manager1Group)
        await upala.connect(manager1).increaseBaseScore(scoreBefore.add(scoreChange))
        const scoreAfter = await upala.connect(manager1).groupBaseScore(manager1Group)
        expect(scoreAfter.sub(scoreBefore)).to.eq(scoreChange)
      })

      it('cannot decrease base score immediately', async function () {
        await expect(upala.connect(manager1).increaseBaseScore(scoreChange)).to.be.revertedWith(
          'To decrease score, make a commitment first'
        )
      })

      // only group manager todo
    })

    describe('decrease base score', function () {
      let newScore
      before('Commit hash', async () => {
        // scoreBefore =
        newScore = (await upala.connect(manager1).groupBaseScore(manager1Group)).sub(1)
        hash = utils.solidityKeccak256(['string', 'uint256', 'bytes32'], ['setBaseScore', newScore, secret])
        await upala.connect(manager1).commitHash(hash)
      })

      it('cannot decrease score immediately after commitment', async function () {
        await expect(upala.connect(manager1).setBaseScore(newScore, secret)).to.be.revertedWith(
          'Attack window is not closed yet'
        )
      })

      it('cannot decrease score after execution window', async function () {
        await time.increase(executionWindow.add(attackWindow).toNumber())
        await expect(upala.connect(manager1).setBaseScore(newScore, secret)).to.be.revertedWith(
          'Execution window is already closed'
        )
      })

      it('cannot decrease score with wrong secret', async function () {
        await upala.connect(manager1).commitHash(hash)
        await time.increase(attackWindow.toNumber())
        await expect(upala.connect(manager1).setBaseScore(newScore, wrongSecret)).to.be.revertedWith(
          'No such commitment hash'
        )
      })

      it('can decrease score after attack window and before execution window', async function () {
        await expect(upala.connect(nobody).setBaseScore(newScore, secret)).to.be.revertedWith('No such commitment hash')
        await upala.connect(manager1).setBaseScore(newScore, secret)
        const scoreAfter = await upala.connect(manager1).groupBaseScore(manager1Group)
        expect(scoreAfter).to.eq(newScore)
      })
    })

    describe('publish/delete merkle roots', function () {
      let someRoot
      let delRootCommitHash
      before('Commit hash', async () => {
        someRoot = utils.formatBytes32String('Decentralize the IDs')
        delRootCommitHash = utils.solidityKeccak256(['string', 'uint256', 'bytes32'], ['deleteRoot', someRoot, secret])
      })

      it('group manager can publish new merkle root immediately', async function () {
        await upala.connect(manager1).publishRoot(someRoot)
        expect(await upala.roots(manager1Group, someRoot)).to.eq((await time.latest()).toString())
      })

      it('cannot delete during attack window', async function () {
        await upala.connect(manager1).commitHash(delRootCommitHash) // +1 second to "mine" transaction
        await time.increase(attackWindow.sub(2).toNumber()) // +1s if next transaction is mined
        await expect(upala.connect(manager1).deleteRoot(someRoot, secret)).to.be.revertedWith(
          'Attack window is not closed yet'
        )
      })

      it('cannot delete after execution window', async function () {
        await time.increase(executionWindow.add(2).toNumber())
        await expect(upala.connect(manager1).deleteRoot(someRoot, secret)).to.be.revertedWith(
          'Execution window is already closed'
        )
      })

      it('cannot publish commit before root', async function () {
        await upala.connect(manager1).commitHash(delRootCommitHash)
        await upala.connect(manager1).publishRoot(someRoot)
        await time.increase(attackWindow.toNumber())
        await expect(upala.connect(manager1).deleteRoot(someRoot, secret)).to.be.revertedWith(
          'Commit is submitted before root'
        )
      })

      it('cannot delete with wrong secret', async function () {
        await upala.connect(manager1).publishRoot(someRoot)
        await upala.connect(manager1).commitHash(delRootCommitHash)
        await time.increase(attackWindow.toNumber())
        await expect(upala.connect(manager1).deleteRoot(someRoot, wrongSecret)).to.be.revertedWith(
          'No such commitment hash'
        )
      })

      it('can delete after attack window and before execution window', async function () {
        await upala.connect(manager1).deleteRoot(someRoot, secret)
        expect(await upala.commitsTimestamps(manager1Group, delRootCommitHash)).to.eq(0)
        expect(await upala.roots(manager1Group, someRoot)).to.eq(0)
      })
    })
  })

  describe('basic pool', function () {
    it('anyone can deposit', async function () {
      const transferAmount = oneETH.mul(23)
      const balBefore = await fakeDai.balanceOf(manager1Pool)
      await fakeDai.connect(nobody).transfer(manager1Pool, transferAmount)
      const balAfter = await fakeDai.balanceOf(manager1Pool)
    })

    // cannot withdraw without commitment
  })

  describe('ownership', function () {
    // can setGroupManager
    // only owner can setGroupManager
    // old manager can now manage new group
    // still got access to pool
  })

  describe('group details (misc)', function () {
    it('group manager can publish group meta', async function () {
      assert.fail('actual', 'expected', 'Error message')
      // db_url, description, etc. - from future
    })
  })

  // todo test signedScoresPool in a separate file
})

describe('SCORING', function () {
  // todo setup protocol

  it('can verify own score', async function () {
    //  function verifyMyScore (uint160 groupID, uint160 identityID, address holder, uint8 score, bytes32[] calldata proof) external {
  })

  it('DApp can verify user score', async function () {
    // function verifyUserScore (uint160 groupID, uint160 identityID, address holder, uint8 score, bytes32[] calldata proof) external {
  })

  it('cannot approve scores from an arbitrary address', async function () {})

  it('An address approved by Upala ID owner can approve scores to DApps', async function () {})
})
 */
describe('EXPLOSIONS', function () {
  // todo setup protocol
  let upala
  let fakeDai
  let signedScoresPoolFactory
  let signedScoresPool
  let wallets
  let upalaAdmin
  let manager1

  before('register users', async () => {
    ;[upala, fakeDai, wallets] = await resetProtocol()
    ;[upalaAdmin, manager1] = wallets.slice(0,2)
    ;[signedScoresPoolFactory, signedScoresPool] = 
      await setUpPoolFactoryAndPool(
        upala, fakeDai, 'SignedScoresPoolFactory', upalaAdmin, manager1)
  })

  describe('EXPLOSIONS', function () {
    it('you can explode, you can explode, you can explode, anyone can exploooooode', async function () {
      ///function attack(uint160 groupID, uint160 identityID, uint8 score, bytes32[] calldata proof)

      /// hack 

      const TEST_MESSAGE = web3.utils.sha3('Human');
      // Create the signature
      // web3 adds "\x19Ethereum Signed Message:\n32" to the hashed message
      const signature = await web3.eth.sign(TEST_MESSAGE, manager1.address);

      // Recover the signer address from the generated message and signature.
      const recovered = await signedScoresPool.hack_recover(
        TEST_MESSAGE,
        signature,
      )
      expect(recovered).to.equal(manager1.address);
    })

    it('cannot explode from an arbitrary address', async function () {})

    it('cannot explode using delegate address', async function () {})

    it('Upala ID owner can explode (check fees and rewards)', async function () {})
  })

})
