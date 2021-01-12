const { expect } = require("chai");

const Upala = artifacts.require("Upala");
const FakeDai = artifacts.require("FakeDai");
const BasicPoolFactory = artifacts.require("BasicPoolFactory");

async function deployContract(contractName, ...args) {
  const contractFactory = await ethers.getContractFactory(contractName);
  const contractInstance = await contractFactory.deploy(...args);
  await contractInstance.deployed();
  return contractInstance;
}

let upala;
let fakeDai;
let basicPoolFactory;
let wallets;

before('deploy and setup protocol', async () => {
  wallets = await ethers.getSigners();
  [upalaAdmin,user1,user2,user3,manager1,manager2,delegate1,delegate2,delegate3,nobody] = wallets;

  // setup protocol
  upala = await deployContract("Upala");
  fakeDai = await deployContract("FakeDai");
  basicPoolFactory = await deployContract("BasicPoolFactory", fakeDai.address);
  await upala.setapprovedPoolFactory(basicPoolFactory.address, "true").then((tx) => tx.wait());
  })



describe("Groups", function() {

    // REGISTER GROUP
    // it("registers a group ID", async function() {
    //   await upala.connect(user1).newIdentity(user1.getAddress());
    // });

    // cannot commit hash for another group 

});


describe("USER", function() {

    before('register users', async () => {
      await upala.connect(user2).newIdentity(user1.getAddress());
      await upala.connect(user2).newIdentity(user2.getAddress());
      await upala.connect(user1).approveDelegate(delegate1.getAddress());
      })

    describe("registration", function() {

      it("registers Upala ID", async function() {
        expect(await upala.connect(user1).myId()).to.eq(1)
      });

      it("Upala ID owner address cannot be used to register another Upala ID", async function() {
        await expect(upala.connect(user2).newIdentity(user1.getAddress())).to.be.revertedWith(
          'Address is already an owner or delegate'
        )
      });

      it("cannot query Upala ID from an arbitrary address", async function() {
        await expect(upala.connect(nobody).myId()).to.be.revertedWith(
          'no id registered for the address'
        )
      });

      // todo can register from another address
      // todo can remove id (just explode with 0 reward)
      // todo only delegates or owner can get identity owner

    });
    
    describe("delegation", function() {
 
      it("can query Upala ID from an approved address", async function() {
        expect(await upala.connect(delegate1).myId()).to.eq(1)
      });

      it("cannot register an address approved by another Upala ID as a delegate", async function() {
        await expect(upala.connect(user2).newIdentity(delegate1.getAddress())).to.be.revertedWith(
          'Address is already an owner or delegate'
        )
      });

      it("cannot APPROVE delegate from a delegate address (only owner)", async function() {
        await expect(upala.connect(delegate1).approveDelegate(delegate2.getAddress())).to.be.revertedWith(
          'Only identity holder can add or remove delegates'
        )
      });

      it("cannot REMOVE delegate from a delegate address (only owner)", async function() {
        await upala.connect(user1).approveDelegate(delegate2.getAddress()); 
        await expect(upala.connect(delegate1).removeDelegate(delegate2.getAddress())).to.be.revertedWith(
          'Only identity holder can add or remove delegates'
        )
      });

      it("cannot query Upala ID from a removed address", async function() {
        await upala.connect(user1).removeDelegate(delegate2.getAddress());
        await expect(upala.connect(delegate2).myId()).to.be.revertedWith(
          'no id registered for the address'
        )
      });
    });

    describe("ownership", function() {
      it("owner can change Upala ID ownership (change owner address)", async function() {
        const upalaId = await upala.connect(user1).myId();
        await upala.connect(user1).setIdentityOwner(user3.getAddress())
        // id sticks
        expect(await upala.connect(user3).myId()).to.eq(upalaId)
        // delegates stick
        expect(await upala.connect(delegate1).myIdOwner()).to.eq(await user3.getAddress())
        // owner becomes delegate
        expect(await upala.connect(user1).myIdOwner()).to.eq(await user3.getAddress())
      });

      it("arbitrary address cannot change Upala ID ownership", async function() {
        await expect(upala.connect(nobody).setIdentityOwner(user3.getAddress())).to.be.revertedWith(
          'no id registered for the address'
        )
      });

      it("cannot pass ownership to another account OWNER", async function() {
        await expect(upala.connect(user3).setIdentityOwner(user2.getAddress())).to.be.revertedWith(
          'Address is already an owner or delegate'
        )
      });

      it("cannot pass ownership to another account DELEGATE", async function() {
        await upala.connect(user2).approveDelegate(delegate2.getAddress()); 
        await expect(upala.connect(user3).setIdentityOwner(delegate2.getAddress())).to.be.revertedWith(
          'Address is already an owner or delegate'
        )

      });

      it("delegate cannot change ownership", async function() {
        await upala.connect(user3).approveDelegate(delegate3.getAddress()); 
        await expect(upala.connect(delegate3).setIdentityOwner(user1.getAddress())).to.be.revertedWith(
          'Only identity holder can add or remove delegates'
        )
      });

      it("can pass ownership to own delegate", async function() {
        await upala.connect(user3).setIdentityOwner(delegate3.getAddress());
        expect(await upala.connect(delegate3).myIdOwner()).to.eq(await delegate3.getAddress())
      });

      after('cleanup', async () => {
        await upala.connect(user2).removeDelegate(delegate2.getAddress());
      })

    });



    // SCORING
    // Upala ID owner can approve scores to DApps
    // An address approved by Upala ID owner can approve scores to DApps
    // cannot approve scores from an arbitrary address

    // EXPLODING
    // cannot explode from an arbitrary address
    // cannot explode using delegate address
    // Upala ID owner can explode (check fees and rewards)

    // PROTOCOL MANAGEMENT
  // });
});