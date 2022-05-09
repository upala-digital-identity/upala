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
const { setupProtocol } = require('../src/upala-admin.js')
const {
  BN, // Big Number support
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers')

const NULL_ADDRESS = '0x0000000000000000000000000000000000000000'
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
    await expect(upala.connect(nobody).transferOwnership(nobody.getAddress())).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    await upala.connect(upalaAdmin).transferOwnership(nobody.getAddress())
    expect(await upala.owner()).to.be.eq(await nobody.getAddress())
  })

  // check paused functions
})
*/


describe('USERS', function () {
  let upala
  let upalaAdmin, user1, user2, user3, delegate1, delegate2, delegate3, nobody
  before('setup protocol, register users', async () => {
    //todo beforeEach
    let environment = await setupProtocol({ isSavingConstants: false })
    upala = environment.upala
    ;[upalaAdmin, user1, user2, user3, delegate1, delegate2, delegate3, nobody] = environment.wallets
  })


  describe('registration', function () {
    // helper function for calculating Ids
    async function calculateUpalaId(txOfIdCreation, userAddress) {
      const blockTimestamp = (await ethers.provider.getBlock(txOfIdCreation.blockNumber)).timestamp
      return utils.getAddress(
        '0x' + utils.solidityKeccak256(
          ['address', 'uint256'], 
          [userAddress, blockTimestamp])
        .substring(26)
      )
    }

    it('registers an Upala id and the id is non-deterministic', async function () {
      const tx = await upala.connect(user1).newIdentity(user1.getAddress())
      const expectedId = await calculateUpalaId(tx, user1.address)
      const receivedId = await upala.connect(user1).myId()
      expect(receivedId).to.eq(expectedId)
      expect(await upala.connect(user1).myIdOwner()).to.eq(user1.address)
      await expect(tx).to.emit(upala, 'NewIdentity').withArgs(expectedId, user1.address)
    })

    it('registers Upala ID for another address', async function () {
      // cannot register to an empty address
      await expect(upala.connect(user2).newIdentity(NULL_ADDRESS)).to.be.revertedWith(
        'Cannot use an empty addess'
      )
      // cannot register to taken address
      await expect(upala.connect(user2).newIdentity(user1.address)).to.be.revertedWith(
        'Address is already an owner or delegate'
      )
      // can register a third party address
      tx = await upala.connect(user1).newIdentity(user2.address)
      const expectedId = await calculateUpalaId(tx, user2.address)
      expect(await upala.connect(user2).myId()).to.eq(expectedId)
      await expect(tx).to.emit(upala, 'NewIdentity').withArgs(expectedId, user2.address)
    })
  })

  
  describe('delegation', function () {
    before('register users', async () => {
      await upala.connect(user1).newIdentity(user1.getAddress())
      await upala.connect(user1).newIdentity(user2.getAddress())
      await upala.connect(user1).approveDelegate(delegate1.getAddress());
    })
    // before
    // await upala.connect(user1).newIdentity(user1.getAddress())
    // await upala.connect(user1).newIdentity(user2.getAddress())
    // todo
    // before('create delegate', async () => {
    //   await upala.connect(user1).approveDelegate(delegate1.getAddress());
    //   })
    // todo cannot register an Upala id for an existing delegate
    it('cannot remove the only delegate', async function () {
      await expect(upala.connect(user1).removeDelegate(user1.getAddress())).to.be.revertedWith(
        'Cannot remove oneself')
    })

    it('can query Upala ID and owner address from an approved address', async function () {
      // todo expect 'nobody' to fail 0x0 in return
      // todo get ownerID
      await upala.connect(user1).approveDelegate(delegate1.getAddress())
      expect(await upala.connect(delegate1).myId()).to.eq(await upala.connect(user1).myId())
    })

    it('cannot register an address approved by another Upala ID as a delegate', async function () {
      await expect(upala.connect(user2).newIdentity(delegate1.getAddress())).to.be.revertedWith(
        'Address is already an owner or delegate'
      )
    })

    it('cannot APPROVE delegate from a delegate address (only owner)', async function () {
      await expect(upala.connect(delegate1).approveDelegate(delegate2.getAddress())).to.be.revertedWith(
        'Only identity holder can add or remove delegates'
      )
    })

    it('cannot REMOVE delegate from a delegate address (only owner)', async function () {
      await upala.connect(user1).approveDelegate(delegate2.getAddress())
      await expect(upala.connect(delegate1).removeDelegate(delegate2.getAddress())).to.be.revertedWith(
        'Only identity holder can add or remove delegates'
      )
    })

    it('cannot query Upala ID from a removed address', async function () {
      await upala.connect(user1).removeDelegate(delegate2.getAddress())
      await expect(upala.connect(delegate2).myId()).to.be.revertedWith('no id registered for the address')
    })
  })
/*
  describe('ownership', function () {
    it('cannot pass ownership to another account OWNER', async function () {
      await expect(upala.connect(user3).setIdentityOwner(user2.getAddress())).to.be.revertedWith(
        'Address is already an owner or delegate'
      )
    })

    it('cannot pass ownership to another account DELEGATE', async function () {
      await upala.connect(user2).approveDelegate(delegate2.getAddress())
      await expect(upala.connect(user3).setIdentityOwner(delegate2.getAddress())).to.be.revertedWith(
        'Address is already an owner or delegate'
      )
    })

    it('delegate cannot change ownership', async function () {
      await upala.connect(user3).approveDelegate(delegate3.getAddress())
      await expect(upala.connect(delegate3).setIdentityOwner(user1.getAddress())).to.be.revertedWith(
        'Only identity holder can add or remove delegates'
      )
    })

    it('cannot transfer ownership to a non-delegate (create delegate first)', async function () {
      // todo to.be.revertedWith("Address is not a delegate for current UpalaId")
    })

    it('a non-owner cannot transfer ownership', async function () {
      // todo to.be.revertedWith("Only identity holder can add or remove delegates")
    })

    it('owner can pass ownership to own delegate (change owner address)', async function () {
      // todo probably bad code here
      const upalaId = await upala.connect(user1).myId()
      await upala.connect(user3).setIdentityOwner(delegate3.getAddress())
      expect(await upala.connect(delegate3).myIdOwner()).to.eq(await delegate3.getAddress())
      // id sticks
      expect(await upala.connect(user3).myId()).to.eq(upalaId)
      // delegates sticks
      expect(await upala.connect(delegate1).myIdOwner()).to.eq(await user3.getAddress())
      // owner becomes delegate
      expect(await upala.connect(user1).myIdOwner()).to.eq(await user3.getAddress())
    })
  })
  */
})
/*
describe('POOL FACTORIES', function () {
  let upala
  let fakeDai
  let signedScoresPoolFactory
  let wallets

  before('setup protocol', async () => {
    let environment = await setupProtocol({ isSavingConstants: false })
    upala = environment.upala
    fakeDai = environment.dai
    ;[upalaAdmin, user1, user2, user3, manager1, manager2, delegate1, delegate2, delegate3, nobody] =
      environment.wallets
    signedScoresPoolFactory = environment.poolFactory
  })

  it('owner can manage pool factories', async function () {
    // approvePoolFactory(addr, true) fails for nobody - see ownable for
    // approvePoolFactory(addr, true) works for owner (event fired, record changed)
  })

  // production todo 'requires isPoolFactory bool to be true'

  it('only approved pool factory can register new pools', async function () {
    // todo 'nobody' cannot approve pools
    // fails with "Not an owner" (see Ownbale contract)

    // approve pool factory
    await upala
      .connect(upalaAdmin)
      .approvePoolFactory(signedScoresPoolFactory.address, 'true')
      .then((tx) => tx.wait())
    expect(await upala.approvedPoolFactories(signedScoresPoolFactory.address)).to.eq(true)
    // todo only Upala admin

    // spawn a new pool by the factory
    const tx = await signedScoresPoolFactory.connect(manager1).createPool()
    // retrieve new pool address from Upala event (todo - is there an easier way?)
    const blockNumber = (await tx.wait(1)).blockNumber
    const eventFilter = upala.filters.NewPool()
    const events = await upala.queryFilter(eventFilter, blockNumber, blockNumber)
    const newPoolAddress = events[0].args.poolAddress

    const poolContract = (await ethers.getContractFactory('SignedScoresPool')).attach(newPoolAddress)
    // expect(await upala.approvedPools(newPoolAddress)).to.eq(signedScoresPoolFactory.address)

    // try to spawn a pool from a not approved factory
    // await expect(signedScoresPoolFactory2.connect(manager1).createPool()).to.be.revertedWith('Pool factory is not approved')
  })

  it('pool factories can be switched on and off', async function () {
    // approvePoolFactory(addr, true)
    // pool factory can register pools again
    // approvePoolFactory(addr, false)
    // pool factory cannot register pools
    // approvePoolFactory(addr, true)
    // pool factory can register pools again
  })
})

describe('POOLS', function () {
  // before
  //    setup protocol
  //    setup pool (approve pool factory and spawn a pool)
  //

  it('only registered pools can validate and explode users', async function () {
    // 'nobody' cannot read isOwnerOrDelegate - "Parent pool factory is disapproved"
    // 'nobody' cannot explode - "Parent pool factory is disapproved"
    // a registered one can do those
  })

  it('disapproved pool factory child pool cannot validate or explode users', async function () {
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
