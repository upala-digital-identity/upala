// README
// Testing upala.sol with this

// TODO
/*
- make all 'it's work
- think where before/beforeEach could be placed best (and what they would do)
- try preserve ordering of tests
- remove unnecessary wallets from tests and all unnecessary code in general
- add events testing
- ignore production todos
*/
const { ethers } = require('hardhat')
const { utils } = require('ethers')
const { expect } = require('chai')
const { setupProtocol, UpalaManager } = require('../src/upala-admin.js')
const { deployPool } = require('@upala/group-manager')

const {
  BN, // Big Number support
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers')

const NULL_ADDRESS = '0x0000000000000000000000000000000000000000'
const EXPLODED_ADDRESS = '0x0000000000000000000000006578706c6f646564'
const A_SCORE_BUNDLE = '0x0000000000000000000000000000000000000000000000000000000000000001'
const ZERO_REWARD = 0

async function getProof(userId, poolContract, managerWallet, bundleId, reward, baseScore = 1) {
  await poolContract.connect(managerWallet).setBaseScore(baseScore)
  await poolContract.connect(managerWallet).publishScoreBundleId(bundleId)
  return await managerWallet.signMessage(
    ethers.utils.arrayify(utils.solidityKeccak256(['address', 'uint8', 'bytes32'], [userId, reward, bundleId]))
  )
}

// await signedScoresPool.connect(user1).attack(user1Id, user1Id, ZERO_REWARD, A_SCORE_BUNDLE, proof)

/*
describe('PROTOCOL MANAGEMENT', function () {
  let upala
  let unusedFakeDai
  let wallets

  before('setup protocol', async () => {
    let environment = await setupProtocol({ isSavingConstants: false })
    upala = environment.upala
    ;[upalaAdmin, nobody] = environment.wallets



  })

  it('onlyOwner guards are set', async function () {
    // approvePoolFactory(address poolFactory, bool isApproved)
    // setAttackWindow(uint256 newWindow)
    // setExecutionWindow(uint256 newWindow)
    // setExplosionFeePercent(uint8 newFee)
    // setTreasury(address newTreasury)
    // pause()
    // unpause()
    // _authorizeUpgrade(address)
  })

  it('owner can set attack window', async function () {
    const oldAttackWindow = await upala.attackWindow()
    const newAttackWindow = oldAttackWindow + 1000
    await expect(upala.connect(nobody).setAttackWindow(newAttackWindow)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    await upala.connect(upalaAdmin).setAttackWindow(newAttackWindow)
    expect(await upala.attackWindow()).to.be.eq(newAttackWindow)
  })

  it('owner can set execution window', async function () {
    const oldExecutionWindow = await upala.executionWindow()
    const newExecutionWindow = oldExecutionWindow + 1000
    await expect(upala.connect(nobody).setExecutionWindow(newExecutionWindow)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    await upala.connect(upalaAdmin).setExecutionWindow(newExecutionWindow)
    expect(await upala.executionWindow()).to.be.eq(newExecutionWindow)
  })

  // todo setExplosionFeePercent(uint8 newFee)

  // todo setTreasury(address newTreasury)

  // pause() unpause()

  it('owner can change owner', async function () {
    await expect(upala.connect(nobody).transferOwnership(nobody.address)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    await upala.connect(upalaAdmin).transferOwnership(nobody.address)
    expect(await upala.owner()).to.be.eq(await nobody.address)
  })

  // check paused functions
})
*/
// USERS
describe('USERS', function () {
  let upala
  let upalaAdmin, user1, user2, user3, delegate1, delegate2, manager1, nobody
  let environment
  // helper function for calculating Ids
  async function calculateUpalaId(txOfIdCreation, userAddress) {
    const blockTimestamp = (await ethers.provider.getBlock(txOfIdCreation.blockNumber)).timestamp
    return utils.getAddress(
      '0x' + utils.solidityKeccak256(['address', 'uint256'], [userAddress, blockTimestamp]).substring(26)
    )
  }
  // helper function to register upala id for a wallet (returns upala id)
  async function registerUpalaId(userWallet) {
    tx = await upala.connect(userWallet).newIdentity(userWallet.address)
    return calculateUpalaId(tx, userWallet.address)
  }

  async function createIdAndDelegate(userWallet, delegateWallet) {
    const upalaId = await registerUpalaId(userWallet)
    await upala.connect(delegateWallet).askDelegation(upalaId)
    await upala.connect(userWallet).approveDelegate(delegateWallet.address)
    return upalaId
  }

  beforeEach('setup protocol, register users', async () => {
    //todo beforeEach
    environment = await setupProtocol({ isSavingConstants: false })
    upala = environment.upala
    ;[upalaAdmin, user1, user2, user3, delegate1, delegate2, manager1, nobody] = environment.wallets
  })
  /*
  describe('creating upala id', function () {
    it('registers non-deterministic Upala ID', async function () {
      const tx = await upala.connect(user1).newIdentity(user1.address)
      const expectedId = await calculateUpalaId(tx, user1.address)
      const receivedId = await upala.connect(user1).myId()
      expect(receivedId).to.eq(expectedId)
      expect(await upala.connect(user1).myIdOwner()).to.eq(user1.address)
      await expect(tx).to.emit(upala, 'NewIdentity').withArgs(expectedId, user1.address)
    })

    it('registers Upala ID for a third party address', async function () {
      // cannot register to an empty address
      await expect(upala.connect(user2).newIdentity(NULL_ADDRESS)).to.be.revertedWith('Cannot use an empty addess')
      // cannot register to taken address
      await upala.connect(user1).newIdentity(user1.address)
      await expect(upala.connect(user2).newIdentity(user1.address)).to.be.revertedWith(
        'Address is already an owner or delegate'
      )
      // can register a third party address
      tx = await upala.connect(user1).newIdentity(user2.address)
      const expectedId = await calculateUpalaId(tx, user2.address)
      expect(await upala.connect(user2).myId()).to.eq(expectedId)
      await expect(tx).to.emit(upala, 'NewIdentity').withArgs(expectedId, user2.address)
    })

    it('cannot register an Upala id for an existing delegate', async function () {
      const user1Id = await createIdAndDelegate(user1, delegate1)
      await expect(upala.connect(delegate1).newIdentity(delegate1.address)).to.be.revertedWith(
        'Address is already an owner or delegate'
      )
    })
  })
/*
  describe('creating delegates', function () {
    it('any address can ask for delegation', async function () {
      const user1Id = await registerUpalaId(user1)
      const askDelegationTx = await upala.connect(delegate1).askDelegation(user1Id)
      await expect(askDelegationTx).to.emit(upala, 'NewCandidateDelegate').withArgs(user1Id, delegate1.address)
    })

    it('can cancel delegation request (GDPR)', async function () {
      const user1Id = await registerUpalaId(user1)
      await upala.connect(delegate1).askDelegation(user1Id)
      const askDelegationTx = await upala.connect(delegate1).askDelegation(NULL_ADDRESS)
      await expect(askDelegationTx).to.emit(upala, 'NewCandidateDelegate').withArgs(NULL_ADDRESS, delegate1.address)
    })

    it('id owner can register a delegate', async function () {
      await expect(upala.connect(nobody).approveDelegate(delegate1.address)).to.be.revertedWith(
        'Upala: Only identity owner can manage delegates and ownership'
      )
      const user1Id = await registerUpalaId(user1)
      await expect(upala.connect(user1).approveDelegate(delegate1.address)).to.be.revertedWith(
        'Delegatee must confirm delegation first'
      )
      // register new delegate
      await upala.connect(delegate1).askDelegation(user1Id)
      await expect(upala.connect(user1).approveDelegate(NULL_ADDRESS)).to.be.revertedWith('Cannot use an empty addess')
      await expect(upala.connect(user1).approveDelegate(user1.address)).to.be.revertedWith(
        'Cannot approve oneself as delegate'
      )
      const createDelegateTx = upala.connect(user1).approveDelegate(delegate1.address)
      await expect(createDelegateTx).to.emit(upala, 'NewDelegate').withArgs(user1Id, delegate1.address)
    })

    it('delegates and owner can query Upala ID and owner address', async function () {
      const user1Id = await createIdAndDelegate(user1, delegate1)
      expect(await upala.connect(nobody).myId()).to.eq(NULL_ADDRESS)
      expect(await upala.connect(nobody).myIdOwner()).to.eq(NULL_ADDRESS)
      expect(await upala.connect(user1).myId()).to.eq(user1Id)
      expect(await upala.connect(delegate1).myId()).to.eq(user1Id)
      expect(await upala.connect(user1).myIdOwner()).to.eq(user1.address)
      expect(await upala.connect(delegate1).myIdOwner()).to.eq(user1.address)
    })

    it('cannot approve same delegate twice', async function () {
      const user1Id = await createIdAndDelegate(user1, delegate1)

      // try again for the same delegate candidate
      await expect(upala.connect(user1).approveDelegate(delegate1.address)).to.be.revertedWith(
        'Delegatee must confirm delegation first'
      )
      await expect(upala.connect(delegate1).askDelegation(user1Id)).to.be.revertedWith('Already a delegate')
      // try use same delegate for another UpalaId
      const user2Id = await registerUpalaId(user2)
      await expect(upala.connect(delegate1).askDelegation(user2Id)).to.be.revertedWith('Already a delegate')
    })

    it('cannot APPROVE delegate from a delegate address (only owner)', async function () {
      const user1Id = await createIdAndDelegate(user1, delegate1)
      await upala.connect(delegate2).askDelegation(user1Id)
      await expect(upala.connect(delegate1).approveDelegate(delegate2.address)).to.be.revertedWith(
        'Upala: Only identity owner can manage delegates and ownership'
      )
    })
  })
*/
  describe('deleting delegates and upala id', function () {
    it('cannot REMOVE delegate from a delegate address (only owner)', async function () {
      const user1Id = await createIdAndDelegate(user1, delegate1)
      await upala.connect(delegate2).askDelegation(user1Id)
      await expect(upala.connect(delegate1).removeDelegate(delegate2.address)).to.be.revertedWith(
        'Upala: Only identity owner can manage delegates and ownership'
      )
    })

    it('cannot remove the only delegate (owner is a speial case of delegate)', async function () {
      const user1Id = await registerUpalaId(user1)
      await expect(upala.connect(user1).removeDelegate(user1.address)).to.be.revertedWith(
        'Upala: Cannot remove identity owner'
      )
    })

    it('Id owner can remove a delegate', async function () {
      const user1Id = await createIdAndDelegate(user1, delegate1)
      await expect(upala.connect(nobody).removeDelegate(delegate1.address)).to.be.revertedWith(
        'Upala: Only identity owner can manage delegates and ownership'
      )
      const removalTx = await upala.connect(user1).removeDelegate(delegate1.address)
      await expect(removalTx).to.emit(upala, 'DelegateDeleted').withArgs(user1Id, delegate1.address)
    })

    it('delegate can drop delegation rights (GDPR)', async function () {
      const user1Id = await createIdAndDelegate(user1, delegate1)
      const droplTx = await upala.connect(delegate1).dropDelegation()
      await expect(droplTx).to.emit(upala, 'DelegateDeleted').withArgs(user1Id, delegate1.address)
    })

    it('cannot query Upala ID from a removed address', async function () {
      const user1Id = await createIdAndDelegate(user1, delegate1)
      await upala.connect(delegate1).dropDelegation()
      expect(await upala.connect(delegate1).myId()).to.eq(NULL_ADDRESS)
      expect(await upala.connect(delegate1).myIdOwner()).to.eq(NULL_ADDRESS)
    })

    it('liquidated id has no link to owner address, delegates can be removed', async function () {
      const user1Id = await createIdAndDelegate(user1, delegate1)
      // exlode (remove upala Id by exploding with zero reward)
      const signedScoresPool = await deployPool('SignedScoresPool', manager1, environment.upalaConstants)
      const proof = getProof(user1Id, signedScoresPool, manager1, A_SCORE_BUNDLE, ZERO_REWARD)
      await signedScoresPool.connect(user1).attack(user1Id, user1Id, ZERO_REWARD, A_SCORE_BUNDLE, proof)

      await upala.connect(delegate1).dropDelegation()
      expect(await upala.connect(delegate1).myId()).to.eq(NULL_ADDRESS)
      expect(await upala.connect(user1).myId()).to.eq(NULL_ADDRESS)
      expect(await upala.connect(user1).isExploded(user1Id)).to.eq(true)
    })
  })
})
// todo test onlyOwner (one owner tries to access anoher)
/*
  describe('ownership', function () {
    it('cannot pass ownership to another account owner or delegate', async function () {
      const user1Id = await createIdAndDelegate(user1, delegate1)
      const user2Id = await createIdAndDelegate(user2, delegate2)
      await expect(upala.connect(user1).setIdentityOwner(user2.address)).to.be.revertedWith(
        'Upala: Address must be a delegate for the current UpalaId'
      )
      await expect(upala.connect(user1).setIdentityOwner(delegate2.address)).to.be.revertedWith(
        'Upala: Address must be a delegate for the current UpalaId'
      )
    })

    it('delegate cannot pass ownership', async function () {
      const user1Id = await createIdAndDelegate(user1, delegate1)
      await upala.connect(delegate2).askDelegation(user1Id)
      await upala.connect(user1).approveDelegate(delegate2.address)
      await expect(upala.connect(delegate2).setIdentityOwner(delegate1.address)).to.be.revertedWith(
        'Upala: Only identity owner can manage delegates and ownership'
      )
    })

    it('cannot transfer ownership to a non-delegate (create delegate first)', async function () {
      const user1Id = await createIdAndDelegate(user1, delegate1)
      await expect(upala.connect(user1).setIdentityOwner(delegate2.address)).to.be.revertedWith(
        'Upala: Address must be a delegate for the current UpalaId'
      )
    })

    it('owner can pass ownership to own delegate (change owner address)', async function () {
      const user1Id = await createIdAndDelegate(user1, delegate1)
      const ownershipTransferTx = await upala.connect(user1).setIdentityOwner(delegate1.address)
      await expect(ownershipTransferTx)
        .to.emit(upala, 'NewIdentityOwner')
        .withArgs(user1Id, user1.address, delegate1.address)
      expect(await upala.connect(user1).myIdOwner()).to.eq(delegate1.address)
      expect(await upala.connect(user1).myId()).to.eq(user1Id)
      expect(await upala.connect(delegate1).myIdOwner()).to.eq(delegate1.address)
      expect(await upala.connect(delegate1).myId()).to.eq(user1Id)
    })
  })
})
*/

describe('POOL FACTORIES', function () {
  let upala
  let dai
  let environment
  let upalaManager

  // helpers
  // get newPoolAddress from event emitted at its creation
  async function getNewPoolAddress(tx) {
    const receipt = await tx.wait()
    const blockNumber = receipt.blockNumber
    const eventFilter = upala.filters.NewPool()
    const events = await upala.queryFilter(eventFilter, blockNumber, blockNumber)
    return events[0].args.poolAddress
  }

  beforeEach('setup protocol', async () => {
    environment = await setupProtocol({ isSavingConstants: false, skipPoolFactorySetup: true })
    upala = environment.upala
    dai = environment.dai
    ;[upalaAdmin, user1, manager1, manager2, delegate1, delegate2, manager1, nobody] = environment.wallets
    upalaManager = new UpalaManager(upalaAdmin, { upalaConstants: environment.upalaConstants })
  })

  it('owner (and only owner) can approve and disapprove pool factories', async function () {
    const poolFactory = await upalaManager.deployPoolFactory('SignedScoresPoolFactory', upala.address, dai.address)
    await expect(upala.connect(nobody).approvePoolFactory(poolFactory.address, true)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    const approvalTx = await upala.connect(upalaAdmin).approvePoolFactory(poolFactory.address, true)
    expect(await upala.connect(nobody).isApprovedPoolFactory(poolFactory.address)).to.eq(true)
    await expect(approvalTx).to.emit(upala, 'NewPoolFactoryStatus').withArgs(poolFactory.address, true)
    const disApproveTx = await upala.connect(upalaAdmin).approvePoolFactory(poolFactory.address, false)
    expect(await upala.connect(nobody).isApprovedPoolFactory(poolFactory.address)).to.eq(false)
    await expect(disApproveTx).to.emit(upala, 'NewPoolFactoryStatus').withArgs(poolFactory.address, false)
  })

  it('only approved pool factory can register new pools', async function () {
    // not yet approved
    const poolFactory = await upalaManager.deployPoolFactory('SignedScoresPoolFactory', upala.address, dai.address)
    await expect(poolFactory.connect(nobody).createPool()).to.be.revertedWith('Upala: Pool factory is not approved')
    // approved
    await upala.connect(upalaAdmin).approvePoolFactory(poolFactory.address, true)
    const poolCreationTx = await poolFactory.connect(manager1).createPool()
    const newPoolAddress = await getNewPoolAddress(poolCreationTx)
    await expect(poolCreationTx)
      .to.emit(upala, 'NewPool')
      .withArgs(newPoolAddress, manager1.address, poolFactory.address)
    // disapporved
    await upala.connect(upalaAdmin).approvePoolFactory(poolFactory.address, false)
    await expect(poolFactory.connect(nobody).createPool()).to.be.revertedWith('Upala: Pool factory is not approved')
    // approved again
    await upala.connect(upalaAdmin).approvePoolFactory(poolFactory.address, true)
    const poolCreationTx2 = await poolFactory.connect(manager1).createPool()
    const newPoolAddress2 = await getNewPoolAddress(poolCreationTx2)
    await expect(poolCreationTx2)
      .to.emit(upala, 'NewPool')
      .withArgs(newPoolAddress2, manager1.address, poolFactory.address)
  })

  // production todo 'requires isPoolFactory bool to be true'
})
/*
  
})

describe('POOLS', function () {

  let upala
  let upalaAdmin, user1, user2, user3, delegate1, delegate2, manager1, nobody
  let environment

  beforeEach('setup protocol, register users', async () => {
    //todo beforeEach
    environment = await setupProtocol({ isSavingConstants: false })
    upala = environment.upala
    ;[upalaAdmin, user1, user2, user3, delegate1, delegate2, manager1, nobody] = environment.wallets
  })

  it('registered pools can validate and explode users', async function () {
    // 'nobody' cannot read isOwnerOrDelegate - "Parent pool factory is disapproved"
    // 'nobody' cannot explode - "Parent pool factory is disapproved"
    // a registered one can do those
  })

  it('disapproved pool factory child pool cannot validate or liquidate users', async function () {
    const user1Id = await createIdAndDelegate(user1, delegate1)
    const poolFactory = await upalaManager.deployPoolFactory('SignedScoresPoolFactory', upala.address, dai.address)
    const approvalTx = await upala.connect(upalaAdmin).approvePoolFactory(poolFactory.address, true)

    // exlode (remove upala Id by exploding with zero reward)
    const signedScoresPool = await deployPool('SignedScoresPool', manager1, environment.upalaConstants)
    const proof = getProof(user1Id, signedScoresPool, manager1, A_SCORE_BUNDLE, ZERO_REWARD)
    await signedScoresPool.connect(user1).attack(user1Id, user1Id, ZERO_REWARD, A_SCORE_BUNDLE, proof)

    // disapprove
    // fails to validate or explode
    // approve
    // can validate or explode again
  })
})

describe('DAPPS MANAGEMENT', function () {
  // todo dapps can regiter in Upala
  // todo dapss can unregister in Upala (only registered ones)
})
*/
// todo check treasury
// todo check explosionFee settings
// todo whenNot paused
