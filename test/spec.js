const { expect } = require("chai");
const { BigNumber, utils } = require("ethers");

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
let oneETH = BigNumber.from(10).pow(18);
let fakeUBI = oneETH.mul(100)

async function resetProtocol() {
  // wallets
  fakeDai = await deployContract("FakeDai");
  wallets = await ethers.getSigners();
  [upalaAdmin,user1,user2,user3,manager1,manager2,delegate1,delegate2,delegate3,nobody] = wallets;
  
  // fake DAI giveaway
  wallets.map(async (wallet, ix) => {
    if (ix <= 10) {
      await fakeDai.freeDaiToTheWorld(wallet.address, fakeUBI);
    }
  });

  // setup protocol
  upala = await deployContract("Upala");
  basicPoolFactory = await deployContract("BasicPoolFactory", fakeDai.address);
  await upala.setapprovedPoolFactory(basicPoolFactory.address, "true").then((tx) => tx.wait());
}


describe("USER", function() {

  before('register users', async () => {
    await resetProtocol();
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

    // utils.id("Hello World");
    // todo can register from another address
    // todo can remove id (just explode with 0 reward)
    // todo only delegates or owner can get identity owner
    // todo check return entityCounter;

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
});

describe("GROUPS", function() {
  
  let manager1Group
  let manager1Pool

  describe("registration", function() {
    it("anyone can register a group", async function() {
      const groupIDtoBeAssigned = 3
      await upala.connect(nobody).newGroup(manager1.getAddress(), basicPoolFactory.address);
      manager1Group = await upala.getGroupID(manager1.getAddress())
      manager1Pool = await upala.getGroupPool(manager1Group)
      // expect(await upala.connect(nobody).getGroupID(manager1.getAddress())).to.eq(groupIDtoBeAssigned)
      // todo check return (entityCounter, groupPool[entityCounter]);
      // todo check events
    });

    it("cannot register to an existing manager", async function() {
      await expect(upala.connect(nobody).newGroup(manager1.getAddress(), basicPoolFactory.address)).to.be.revertedWith(
        'Provided address already manages a group'
      )
    });

  });

  describe("ownership", function() {
  // can setGroupManager
  // only owner can setGroupManager
  // old manager can now manage new group
  // still got access to pool
  });

  describe("commitments", function() {
  // two groups can issue identical commitments (cannot overwrite other group's commitment)
  });

  describe("score management", function() {
    
    const scoreChange = oneETH.mul(42).div(100);

    it("Group manager can increase base score immediately", async function() {
      const scoreBefore = await upala.connect(manager1).groupBaseScore(manager1Group)
      await upala.connect(manager1).increaseBaseScore(scoreBefore.add(scoreChange));
      const scoreAfter = await upala.connect(manager1).groupBaseScore(manager1Group)
      expect(scoreAfter.sub(scoreBefore)).to.eq(scoreChange)
    });

    it("cannot decrease base score immediately", async function() {
      await expect(upala.connect(manager1).increaseBaseScore(scoreChange)).to.be.revertedWith(
        'To decrease score, make a commitment first'
      )
    });

    // todo cannot decrease score immediately after commitment 

    it("can decrease score after commitment and attack window (todo - enable attack window)", async function() {
      const secret = utils.formatBytes32String("Zuckerberg is a human")
      const method = "setBaseScore"
      const hash = utils.solidityKeccak256([ 'string', 'uint256', 'bytes32' ], [ method, scoreChange, secret ]);
      await upala.connect(manager1).commitHash(hash);
      await upala.connect(manager1).setBaseScore(scoreChange, secret);
      // todo check events
    });

    it("group manager can can publish new merkle root immediately", async function() {
    // function publishRoot(bytes32 newRoot) external    });
    });

    it("group manager has to wait for the attack window to pass after commitment to delete root", async function() {
    // function deleteRoot(bytes32 root, bytes32 secret) external {
    });

    // todo execution window 
    // todo attack window
    // todo hash exists

    
  // cannot commit hash for another group 
  });

  describe("basic pool", function() {
    it("anyone can deposit", async function() {
      
      const transferAmount = oneETH.mul(23)
      const balBefore = await fakeDai.balanceOf(manager1Pool)
      await fakeDai.connect(nobody).transfer(manager1Pool, transferAmount)
      const balAfter = await fakeDai.balanceOf(manager1Pool)
      expect(balAfter.sub(balBefore)).to.eq(transferAmount)
    });

  // cannot withdraw without commitment
  });

  // todo test basicPool in a separate file

});

describe("SCORING", function() {
   // todo setup protocol

   it("can verify own score", async function() {
    //  function verifyMyScore (uint160 groupID, uint160 identityID, address holder, uint8 score, bytes32[] calldata proof) external {
    });

   it("DApp can verify user score", async function() {
    // function verifyUserScore (uint160 groupID, uint160 identityID, address holder, uint8 score, bytes32[] calldata proof) external {
    });

   it("cannot approve scores from an arbitrary address", async function() {
    });

   it("An address approved by Upala ID owner can approve scores to DApps", async function() {
    });
});

describe("EXPLOSIONS", function() {
   // todo setup protocol

   it("cannot explode from an arbitrary address", async function() {
    });

   it("cannot explode using delegate address", async function() {
    });

   it("Upala ID owner can explode (check fees and rewards)", async function() {
    });
});

describe("PROTOCOL MANAGEMENT", function() {
   // todo setup protocol
   it("owner can change owner", async function() {
    });

   it("owner can set attack window", async function() {
    });

   it("owner can set execution window", async function() {
    });

});

