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
  [upalaAdmin,user1,user2,manager1,manager2,approvedAddress1] = wallets;

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

});


describe("USERS", function() {

    // REGISTER USER
    it("Upala ID equals to the registrant address", async function() {
    	await upala.connect(user2).newIdentity(user1.getAddress());
      expect(await upala.connect(user1).myId()).to.eq(1)
    });

    it("Upala ID owner address cannot be used to register another Upala ID", async function() {
      await expect(upala.connect(user2).newIdentity(user1.getAddress())).to.be.revertedWith(
        'Provided address owns an Upala ID already'
      )
    });

    it("cannot query Upala ID from an arbitrary address", async function() {
      await expect(upala.connect(user2).myId()).to.be.revertedWith(
        'no id registered for the address'
      )
    });


    // APPROVED ADDRESSES
    // registers approved addreess
    // cannot register an address approved by another Upala ID
    // can query Upala ID from an approved address
    // removes approved address
    // cannot query Upala ID from a removed address
    // Upala ID delegate address cannot register Upala ID

    // MANAGEMENT
    // Owner can change Upala ID ownership (change owner address) 
    // Arbitrary address cannot change Upala ID ownership

    // SCORING
    // Upala ID owner can approve scores to DApps
    // An address approved by Upala ID owner can approve scores to DApps
    // cannot approve scores from an arbitrary address

    // EXPLODING
    // cannot explode from an arbitrary address
    // cannot explode using approved address
    // Upala ID owner can explode


  // });
});