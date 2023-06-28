// README
// Testing upala.sol with this

const { ethers } = require('hardhat')
const { utils } = require('ethers')
const { expect } = require('chai')
const { setupProtocol, UpalaManager } = require('../src/upala-admin.js')
const { deployPool } = require('@upala/group-manager')

const NULL_ADDRESS = '0x0000000000000000000000000000000000000000'
const A_SCORE_BUNDLE = '0x0000000000000000000000000000000000000000000000000000000000000001'
const B_SCORE_BUNDLE = '0x0000000000000000000000000000000000000000000000000000000000000002'
const ZERO_REWARD = 0

let upala
let environment
let dai
let upalaManager

// helpers

// helper function for calculating Ids
async function calculateUpalaId(txOfIdCreation, userAddress) {
  const blockTimestamp = (await ethers.provider.getBlock(txOfIdCreation.blockNumber)).timestamp
  return utils.getAddress(
    '0x' + utils.solidityKeccak256(['address', 'uint256'], [userAddress, blockTimestamp]).substring(26)
  )
}
// helper function to register upala id for a wallet (returns upala id)
async function registerUpalaId(upalaContract, userWallet) {
  tx = await upalaContract.connect(userWallet).newIdentity(userWallet.address)
  return userWallet.address // calculateUpalaId(tx, userWallet.address)
}

async function createIdAndDelegate(upalaContract, userWallet, delegateWallet) {
  const upalaId = await registerUpalaId(upalaContract, userWallet)
  await upalaContract.connect(delegateWallet).askDelegation(upalaId)
  await upalaContract.connect(userWallet).approveDelegate(delegateWallet.address)
  return upalaId
}

async function getProof(userId, poolContract, managerWallet, bundleId, reward, baseScore = 1) {
  await poolContract.connect(managerWallet).setBaseScore(baseScore)
  await poolContract.connect(managerWallet).publishScoreBundleId(bundleId)
  return await managerWallet.signMessage(
    ethers.utils.arrayify(utils.solidityKeccak256(['address', 'uint8', 'bytes32'], [userId, reward, bundleId]))
  )
}

// get newPoolAddress from event emitted at its creation
async function getNewPoolAddress(tx) {
  const receipt = await tx.wait()
  const blockNumber = receipt.blockNumber
  const eventFilter = upala.filters.NewPool()
  const events = await upala.queryFilter(eventFilter, blockNumber, blockNumber)
  return events[0].args.poolAddress
}

describe('PROTOCOL MANAGEMENT', function () {
  beforeEach('setup protocol', async () => {
    let environment = await setupProtocol({ isSavingConstants: false })
    upala = environment.upala
    ;[upalaAdmin, nobody, newAdmin, x] = environment.wallets
  })

  it('owner can set attack window', async function () {
    const oldAttackWindow = await upala.getAttackWindow()
    const newAttackWindow = oldAttackWindow + 1000
    await expect(upala.connect(nobody).setAttackWindow(newAttackWindow)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    const newAttWindowTx = await upala.connect(upalaAdmin).setAttackWindow(newAttackWindow)
    await expect(newAttWindowTx).to.emit(upala, 'NewAttackWindow').withArgs(newAttackWindow)
    expect(await upala.getAttackWindow()).to.be.eq(newAttackWindow)
  })

  it('owner can set execution window', async function () {
    const oldExecutionWindow = await upala.getExecutionWindow()
    const newExecutionWindow = oldExecutionWindow + 1000
    await expect(upala.connect(nobody).setExecutionWindow(newExecutionWindow)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    const newExWindowTx = await upala.connect(upalaAdmin).setExecutionWindow(newExecutionWindow)
    await expect(newExWindowTx).to.emit(upala, 'NewExecutionWindow').withArgs(newExecutionWindow)
    expect(await upala.getExecutionWindow()).to.be.eq(newExecutionWindow)
  })

  it('owner can set liquidation fee percent', async function () {
    const oldLiquidationFeePercent = await upala.getLiquidationFeePercent()
    const newLiquidationFeePercent = oldLiquidationFeePercent + 1
    await expect(upala.connect(nobody).setLiquidationFeePercent(newLiquidationFeePercent)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    const newFeeTX = await upala.connect(upalaAdmin).setLiquidationFeePercent(newLiquidationFeePercent)
    await expect(newFeeTX).to.emit(upala, 'NewLiquidationFeePercent').withArgs(newLiquidationFeePercent)
    expect(await upala.getLiquidationFeePercent()).to.be.eq(newLiquidationFeePercent)
  })

  it('owner can set treasury address', async function () {
    const newTreasury = newAdmin.address
    await expect(upala.connect(nobody).setTreasury(newTreasury)).to.be.revertedWith('Ownable: caller is not the owner')
    const newTreasuryTx = await upala.connect(upalaAdmin).setTreasury(newTreasury)
    await expect(newTreasuryTx).to.emit(upala, 'NewTreasury').withArgs(newAdmin.address)
    expect(await upala.getTreasury()).to.be.eq(newAdmin.address)
  })

  it('owner can pause/unpause contract', async function () {
    // Pause
    await expect(upala.connect(nobody).pause()).to.be.revertedWith('Ownable: caller is not the owner')
    const pausedTx = await upala.connect(upalaAdmin).pause()
    await expect(pausedTx).to.emit(upala, 'Paused').withArgs(upalaAdmin.address)
    expect(await upala.paused()).to.be.eq(true)
    // Unpause
    await expect(upala.connect(nobody).unpause()).to.be.revertedWith('Ownable: caller is not the owner')
    const unpausedTx = await upala.connect(upalaAdmin).unpause()
    await expect(unpausedTx).to.emit(upala, 'Unpaused').withArgs(upalaAdmin.address)
    expect(await upala.paused()).to.be.eq(false)
  })

  it('owner can change owner', async function () {
    await expect(upala.connect(nobody).transferOwnership(nobody.address)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )
    await upala.connect(upalaAdmin).transferOwnership(newAdmin.address)
    expect(await upala.owner()).to.be.eq(await newAdmin.address)
  })

  it("public functions don't work when contract is paused", async function () {
    await upala.connect(upalaAdmin).pause()
    await expect(upala.connect(x).newIdentity(x.address)).to.be.revertedWith('Pausable: paused')
    await expect(upala.connect(x).askDelegation(x.address)).to.be.revertedWith('Pausable: paused')
    await expect(upala.connect(x).approveDelegate(x.address)).to.be.revertedWith('Pausable: paused')
    await expect(upala.connect(x).dropDelegation()).to.be.revertedWith('Pausable: paused')
    await expect(upala.connect(x).removeDelegate(x.address)).to.be.revertedWith('Pausable: paused')
    await expect(upala.connect(x).registerPool(x.address, x.address)).to.be.revertedWith('Pausable: paused')
    await expect(upala.connect(x).liquidate(x.address)).to.be.revertedWith('Pausable: paused')
    await expect(upala.connect(x).setIdentityOwner(x.address)).to.be.revertedWith('Pausable: paused')
    await expect(upala.connect(x).registerDApp()).to.be.revertedWith('Pausable: paused')
    await expect(upala.connect(x).unRegisterDApp()).to.be.revertedWith('Pausable: paused')
  })
})

// USERS
describe('USERS', function () {
  beforeEach('setup protocol, register users', async () => {
    environment = await setupProtocol({ isSavingConstants: false })
    upala = environment.upala
    ;[upalaAdmin, user1, user2, user3, delegate1, delegate2, manager1, nobody] = environment.wallets
  })

  describe('creating upala id', function () {
    it('registers deterministic Upala ID', async function () {
      const tx = await upala.connect(user1).newIdentity(user1.address)
      const expectedId = user1.address // await calculateUpalaId(tx, user1.address)
      const receivedId = await upala.connect(user1).myId()
      expect(receivedId).to.eq(expectedId)
      expect(await upala.connect(user1).myIdOwner()).to.eq(user1.address)
      await expect(tx).to.emit(upala, 'NewIdentity').withArgs(expectedId, user1.address)
    })

    it('registers Upala ID for a third party address', async function () {
      // cannot register to an empty address
      await expect(upala.connect(user2).newIdentity(NULL_ADDRESS)).to.be.revertedWith(
        'Upala: Cannot use an empty addess'
      )
      // cannot register to taken address
      await upala.connect(user1).newIdentity(user1.address)
      await expect(upala.connect(user2).newIdentity(user1.address)).to.be.revertedWith(
        'Upala: Address is already an owner or delegate'
      )
      // can register a third party address
      tx = await upala.connect(user1).newIdentity(user2.address)
      const expectedId = user2.address  // await calculateUpalaId(tx, user2.address)
      expect(await upala.connect(user2).myId()).to.eq(expectedId)
      await expect(tx).to.emit(upala, 'NewIdentity').withArgs(expectedId, user2.address)
    })

    it('cannot register an Upala id for an existing delegate', async function () {
      const user1Id = await createIdAndDelegate(upala, user1, delegate1)
      await expect(upala.connect(delegate1).newIdentity(delegate1.address)).to.be.revertedWith(
        'Upala: Address is already an owner or delegate'
      )
    })
  })

  describe('creating delegates', function () {
    it('any address can ask for delegation', async function () {
      const user1Id = await registerUpalaId(upala, user1)
      const askDelegationTx = await upala.connect(delegate1).askDelegation(user1Id)
      await expect(askDelegationTx).to.emit(upala, 'NewCandidateDelegate').withArgs(user1Id, delegate1.address)
    })

    it('can cancel delegation request (GDPR)', async function () {
      const user1Id = await registerUpalaId(upala, user1)
      await upala.connect(delegate1).askDelegation(user1Id)
      const askDelegationTx = await upala.connect(delegate1).askDelegation(NULL_ADDRESS)
      await expect(askDelegationTx).to.emit(upala, 'NewCandidateDelegate').withArgs(NULL_ADDRESS, delegate1.address)
    })

    it('id owner can register a delegate', async function () {
      await expect(upala.connect(nobody).approveDelegate(delegate1.address)).to.be.revertedWith(
        'Upala: Only identity owner can manage delegates and ownership'
      )
      const user1Id = await registerUpalaId(upala, user1)
      await expect(upala.connect(user1).approveDelegate(delegate1.address)).to.be.revertedWith(
        'Upala: Delegatee must confirm delegation first'
      )
      // register new delegate
      await upala.connect(delegate1).askDelegation(user1Id)
      await expect(upala.connect(user1).approveDelegate(NULL_ADDRESS)).to.be.revertedWith(
        'Upala: Cannot use an empty addess'
      )
      await expect(upala.connect(user1).approveDelegate(user1.address)).to.be.revertedWith(
        'Upala: Cannot approve oneself as delegate'
      )
      const createDelegateTx = upala.connect(user1).approveDelegate(delegate1.address)
      await expect(createDelegateTx).to.emit(upala, 'NewDelegate').withArgs(user1Id, delegate1.address)
    })

    it('delegates and owner can query Upala ID and owner address', async function () {
      const user1Id = await createIdAndDelegate(upala, user1, delegate1)
      expect(await upala.connect(nobody).myId()).to.eq(NULL_ADDRESS)
      expect(await upala.connect(nobody).myIdOwner()).to.eq(NULL_ADDRESS)
      expect(await upala.connect(user1).myId()).to.eq(user1Id)
      expect(await upala.connect(delegate1).myId()).to.eq(user1Id)
      expect(await upala.connect(user1).myIdOwner()).to.eq(user1.address)
      expect(await upala.connect(delegate1).myIdOwner()).to.eq(user1.address)
    })

    it('cannot approve same delegate twice', async function () {
      const user1Id = await createIdAndDelegate(upala, user1, delegate1)

      // try again for the same delegate candidate
      await expect(upala.connect(user1).approveDelegate(delegate1.address)).to.be.revertedWith(
        'Upala: Delegatee must confirm delegation first'
      )
      await expect(upala.connect(delegate1).askDelegation(user1Id)).to.be.revertedWith('Upala: Already a delegate')
      // try use same delegate for another UpalaId
      const user2Id = await registerUpalaId(upala, user2)
      await expect(upala.connect(delegate1).askDelegation(user2Id)).to.be.revertedWith('Upala: Already a delegate')
    })

    it('cannot APPROVE delegate from a delegate address (only owner)', async function () {
      const user1Id = await createIdAndDelegate(upala, user1, delegate1)
      await upala.connect(delegate2).askDelegation(user1Id)
      await expect(upala.connect(delegate1).approveDelegate(delegate2.address)).to.be.revertedWith(
        'Upala: Only identity owner can manage delegates and ownership'
      )
    })
  })

  describe('deleting delegates and upala id', function () {
    it('cannot REMOVE delegate from a delegate address (only owner)', async function () {
      const user1Id = await createIdAndDelegate(upala, user1, delegate1)
      await upala.connect(delegate2).askDelegation(user1Id)
      await expect(upala.connect(delegate1).removeDelegate(delegate2.address)).to.be.revertedWith(
        'Upala: Only identity owner can manage delegates and ownership'
      )
    })

    it('cannot remove the only delegate (owner is a speial case of delegate)', async function () {
      const user1Id = await registerUpalaId(upala, user1)
      await expect(upala.connect(user1).removeDelegate(user1.address)).to.be.revertedWith(
        'Upala: Cannot remove identity owner'
      )
    })

    it('Id owner can remove a delegate', async function () {
      const user1Id = await createIdAndDelegate(upala, user1, delegate1)
      await expect(upala.connect(nobody).removeDelegate(delegate1.address)).to.be.revertedWith(
        'Upala: Only identity owner can manage delegates and ownership'
      )
      const removalTx = await upala.connect(user1).removeDelegate(delegate1.address)
      await expect(removalTx).to.emit(upala, 'DelegateDeleted').withArgs(user1Id, delegate1.address)
    })

    it('delegate can drop delegation rights (GDPR)', async function () {
      const user1Id = await createIdAndDelegate(upala, user1, delegate1)
      const droplTx = await upala.connect(delegate1).dropDelegation()
      await expect(droplTx).to.emit(upala, 'DelegateDeleted').withArgs(user1Id, delegate1.address)
    })

    // must drop or remove all delegations before liquidation
    it('delegate CANNOT drop delegation rights of a liquidated ID (UIP-24)', async function () {
      const user1Id = await createIdAndDelegate(upala, user1, delegate1)
      // exlode (remove upala Id by liquidating with zero reward)
      const signedScoresPool = await deployPool('SignedScoresPool', manager1, environment.upalaConstants)
      const proof = getProof(user1Id, signedScoresPool, manager1, A_SCORE_BUNDLE, ZERO_REWARD)
      await signedScoresPool.connect(user1).attack(user1Id, user1Id, ZERO_REWARD, A_SCORE_BUNDLE, proof)
      // UIP-24
      await expect(upala.connect(delegate1).dropDelegation()).to.be.revertedWith(
        'Upala: Cannot drop delegates of a liquidated ID'
      )
    })

    it('cannot query Upala ID from a removed address', async function () {
      const user1Id = await createIdAndDelegate(upala, user1, delegate1)
      await upala.connect(delegate1).dropDelegation()
      expect(await upala.connect(delegate1).myId()).to.eq(NULL_ADDRESS)
      expect(await upala.connect(delegate1).myIdOwner()).to.eq(NULL_ADDRESS)
    })

    // TODO why this matters? Descibe better
    it('liquidated id has no link to owner address (GDPR?)', async function () {
      const user1Id = await createIdAndDelegate(upala, user1, delegate1)
      // exlode (remove upala Id by liquidating with zero reward)
      const signedScoresPool = await deployPool('SignedScoresPool', manager1, environment.upalaConstants)
      const proof = getProof(user1Id, signedScoresPool, manager1, A_SCORE_BUNDLE, ZERO_REWARD)
      await signedScoresPool.connect(user1).attack(user1Id, user1Id, ZERO_REWARD, A_SCORE_BUNDLE, proof)
      expect(await upala.connect(user1).myId()).to.eq(NULL_ADDRESS)
      expect(await upala.connect(user1).isLiquidated(user1Id)).to.eq(true)
    })
  })

  describe('ownership', function () {
    it('cannot pass ownership to another account owner or delegate', async function () {
      const user1Id = await createIdAndDelegate(upala, user1, delegate1)
      const user2Id = await createIdAndDelegate(upala, user2, delegate2)
      await expect(upala.connect(user1).setIdentityOwner(user2.address)).to.be.revertedWith(
        'Upala: Address must be a delegate for the current UpalaId'
      )
      await expect(upala.connect(user1).setIdentityOwner(delegate2.address)).to.be.revertedWith(
        'Upala: Address must be a delegate for the current UpalaId'
      )
    })

    it('delegate cannot pass ownership', async function () {
      const user1Id = await createIdAndDelegate(upala, user1, delegate1)
      await upala.connect(delegate2).askDelegation(user1Id)
      await upala.connect(user1).approveDelegate(delegate2.address)
      await expect(upala.connect(delegate2).setIdentityOwner(delegate1.address)).to.be.revertedWith(
        'Upala: Only identity owner can manage delegates and ownership'
      )
    })

    it('cannot transfer ownership to a non-delegate (create delegate first)', async function () {
      const user1Id = await createIdAndDelegate(upala, user1, delegate1)
      await expect(upala.connect(user1).setIdentityOwner(delegate2.address)).to.be.revertedWith(
        'Upala: Address must be a delegate for the current UpalaId'
      )
    })

    it('owner can pass ownership to own delegate (change owner address)', async function () {
      const user1Id = await createIdAndDelegate(upala, user1, delegate1)
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

describe('POOL FACTORIES & POOLS', function () {
  beforeEach('setup protocol', async () => {
    environment = await setupProtocol({ isSavingConstants: false, skipPoolFactorySetup: true })
    upala = environment.upala
    dai = environment.dai
    ;[upalaAdmin, user1, user2, manager1, delegate1, delegate2, nobody] = environment.wallets
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

  it('pool implementation template is a valid pool too', async function () {
    // deploy pool factory
    const poolFactory = await upalaManager.deployPoolFactory('SignedScoresPoolFactory', upala.address, dai.address)
    await upala.connect(upalaAdmin).approvePoolFactory(poolFactory.address, true)
    // create pool via clones
    const poolCreationTx = await poolFactory.connect(manager1).createPool()
    const newPoolAddress = await getNewPoolAddress(poolCreationTx)
    await expect(poolCreationTx)
      .to.emit(upala, 'NewPool')
      .withArgs(newPoolAddress, manager1.address, poolFactory.address)
    // register template
    const implRegTx = await poolFactory.connect(nobody).registerImplementationAsPool()
    const implPoolAddress = await getNewPoolAddress(implRegTx)
    await expect(implRegTx).to.emit(upala, 'NewPool').withArgs(implPoolAddress, upalaAdmin.address, poolFactory.address)
    // set base score
    const implPool = environment.upalaConstants.getContract('SignedScoresPool', upalaAdmin, implPoolAddress)
    await implPool.connect(upalaAdmin).setBaseScore(10)
    expect(await implPool.connect(nobody).baseScore()).to.eq(10)
    // sanity check storage is different
    const newPool = environment.upalaConstants.getContract('SignedScoresPool', manager1, newPoolAddress)
    await newPool.connect(manager1).setBaseScore(5)
    expect(await newPool.connect(nobody).baseScore()).to.eq(5)
    expect(await implPool.connect(nobody).baseScore()).to.eq(10)
  })

  // (todo future) create mocks for pools and pool factories to test these functions directly
  it('disapproved pool factory child pool cannot validate or liquidate users', async function () {
    // create user and delegate
    const user1Id = await createIdAndDelegate(upala, user1, delegate1)
    // try liquidate from random address
    await expect(upala.connect(nobody).isOwnerOrDelegate(user1.address, user1Id)).to.be.revertedWith(
      'Upala: Parent pool factory is not approved'
    )
    await expect(upala.connect(nobody).liquidate(user1Id)).to.be.revertedWith(
      'Upala: Parent pool factory is not approved'
    )
    // liquidate from an approved pool address
    const poolFactory = await upalaManager.setUpPoolFactory('SignedScoresPoolFactory')
    const poolCreationTx = await poolFactory.connect(manager1).createPool()
    const newPoolAddress = await getNewPoolAddress(poolCreationTx)
    const signedScoresPool = environment.upalaConstants.getContract('SignedScoresPool', manager1, newPoolAddress)
    const proof = getProof(user1Id, signedScoresPool, manager1, A_SCORE_BUNDLE, ZERO_REWARD)
    await signedScoresPool.connect(user1).attack(user1Id, user1Id, ZERO_REWARD, A_SCORE_BUNDLE, proof)
    expect(await upala.connect(user1).isLiquidated(user1Id)).to.eq(true)
    // turn off parent Pool Factory
    await upala.connect(upalaAdmin).approvePoolFactory(poolFactory.address, false)
    const user2Id = await createIdAndDelegate(upala, user2, delegate2)
    const proof2 = getProof(user2Id, signedScoresPool, manager1, B_SCORE_BUNDLE, ZERO_REWARD)
    await expect(
      signedScoresPool.connect(user2).attack(user2Id, user2Id, ZERO_REWARD, B_SCORE_BUNDLE, proof2)
    ).to.be.revertedWith('Upala: Parent pool factory is not approved')
    // turn on again
    await upala.connect(upalaAdmin).approvePoolFactory(poolFactory.address, true)
    await signedScoresPool.connect(user2).attack(user2Id, user2Id, ZERO_REWARD, B_SCORE_BUNDLE, proof2)
    expect(await upala.connect(user1).isLiquidated(user2Id)).to.eq(true)
  })

  it('can approve only a valid pool factory contract', async function () {
    await expect(upala.connect(upalaAdmin).approvePoolFactory(environment.dai.address, true)).to.be.revertedWith(
      "Error: Transaction reverted: function selector was not recognized and there's no fallback function"
    )
  })
})

describe('DAPPS MANAGEMENT', function () {
  beforeEach('setup protocol, register users', async () => {
    environment = await setupProtocol({ isSavingConstants: false })
    upala = environment.upala
    ;[upalaAdmin, dapp1, nobody] = environment.wallets
  })

  it('Dapps can register in Upala', async function () {
    const DappRegTx = await upala.connect(dapp1).registerDApp()
    await expect(DappRegTx).to.emit(upala, 'NewDAppStatus').withArgs(dapp1.address, true)
  })

  it('Dapss can unregister in Upala (only registered ones)', async function () {
    // unregister UNREGISTERED
    await expect(upala.connect(dapp1).unRegisterDApp()).to.be.revertedWith('Upala: DApp is not registered')
    // unregister REGISTERED
    await upala.connect(dapp1).registerDApp()
    const DappUnRegTx = await upala.connect(dapp1).unRegisterDApp()
    await expect(DappUnRegTx).to.emit(upala, 'NewDAppStatus').withArgs(dapp1.address, false)
  })
})
