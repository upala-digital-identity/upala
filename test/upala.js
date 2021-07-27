const { expect } = require('chai')
const { resetProtocol } = require('./deploy-helper.js');

describe('PROTOCOL MANAGEMENT', function () {
  let upala
  let unusedFakeDai
  let wallets
  before('set protocol', async () => {
    [upala, unusedFakeDai, wallets] = await resetProtocol()
    ;[upalaAdmin, nobody] = wallets
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

  it('owner can change owner', async function () {
    await expect(upala.connect(nobody).transferOwnership(nobody.getAddress())).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    await upala.connect(upalaAdmin).transferOwnership(nobody.getAddress())
    expect(await upala.owner()).to.be.eq(await nobody.getAddress())
  })

  // todo owner can approve pool factories
  // todo owner can remove pool factories
})

describe('USER', function () {
  let upala
  let unusedFakeDai
  let wallets
  before('register users', async () => {
    [upala, unusedFakeDai, wallets] = await resetProtocol()
    ;[upalaAdmin, user1, user2, user3, delegate1, delegate2, delegate3, nobody] = wallets
  
    await upala.connect(user2).newIdentity(user1.getAddress())
    await upala.connect(user2).newIdentity(user2.getAddress())
  })

  describe('registration', function () {
    // the only delegate situation (ccheck that it works)
    // it("registers Upala ID", async function() {
    //   expect(await upala.connect(user1).myId()).to.eq(1)
    // });

    it('Upala ID owner address cannot be used to register another Upala ID', async function () {
      await expect(upala.connect(user2).newIdentity(user1.getAddress())).to.be.revertedWith(
        'Address is already an owner or delegate'
      )
    })

    it('cannot query Upala ID from an arbitrary address', async function () {
      await expect(upala.connect(nobody).myId()).to.be.revertedWith('no id registered for the address')
    })

    // utils.id("Hello World");
    // todo can register from another address
    // todo can remove id (just explode with 0 reward)
    // todo only delegates or owner can get identity owner
  })

  describe('delegation', function () {
    // before('create delegate', async () => {
    //   await upala.connect(user1).approveDelegate(delegate1.getAddress());
    //   })

    it('cannot remove the only delegate', async function () {
      await expect(upala.connect(user1).removeDelegate(user1.getAddress())).to.be.revertedWith('Cannot remove oneself')
    })

    it('can query Upala ID from an approved address', async function () {
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

  describe('ownership', function () {
    it('owner can change Upala ID ownership (change owner address)', async function () {
      const upalaId = await upala.connect(user1).myId()
      await upala.connect(user1).setIdentityOwner(user3.getAddress())
      // id sticks
      expect(await upala.connect(user3).myId()).to.eq(upalaId)
      // delegates stick
      expect(await upala.connect(delegate1).myIdOwner()).to.eq(await user3.getAddress())
      // owner becomes delegate
      expect(await upala.connect(user1).myIdOwner()).to.eq(await user3.getAddress())
    })

    it('arbitrary address cannot change Upala ID ownership', async function () {
      await expect(upala.connect(nobody).setIdentityOwner(user3.getAddress())).to.be.revertedWith(
        'no id registered for the address'
      )
    })

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

    it('can pass ownership to own delegate', async function () {
      await upala.connect(user3).setIdentityOwner(delegate3.getAddress())
      expect(await upala.connect(delegate3).myIdOwner()).to.eq(await delegate3.getAddress())
    })
  })
})