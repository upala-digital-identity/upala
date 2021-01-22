const { expect } = require("chai");
const { BigNumber, utils } = require("ethers");
const { time } = require('@openzeppelin/test-helpers');
const { upgrades } = require("hardhat");
const Upala = artifacts.require("Upala");
const FakeDai = artifacts.require("FakeDai");
const BasicPoolFactory = artifacts.require("BasicPoolFactory");

let upala;
let fakeDai;
let basicPoolFactory;
let wallets;
let oneETH = BigNumber.from(10).pow(18);
let fakeUBI = oneETH.mul(100)

async function deployContract(contractName, ...args) {
  const contractFactory = await ethers.getContractFactory(contractName);
  const contractInstance = await contractFactory.deploy(...args);
  await contractInstance.deployed();
  return contractInstance;
}

async function resetProtocol() {
  // wallets and DAI mock
  fakeDai = await deployContract("FakeDai");
  wallets = await ethers.getSigners();
  [upalaAdmin,user1,user2,user3,manager1,manager2,delegate1,delegate2,delegate3,nobody] = wallets;
  
  // fake DAI giveaway
  wallets.map(async (wallet, ix) => {
    if (ix <= 10) {
      await fakeDai.freeDaiToTheWorld(wallet.address, fakeUBI);
    }
  });

  // deploy upgradable upala
  const Upala = await ethers.getContractFactory("Upala");
  upala = await upgrades.deployProxy(Upala);
  await upala.deployed();

  basicPoolFactory = await deployContract("BasicPoolFactory", fakeDai.address);
  await upala.setapprovedPoolFactory(basicPoolFactory.address, "true").then((tx) => tx.wait());
}

describe("PROTOCOL MANAGEMENT", function() {
  before('set protocol', async () => {
    await resetProtocol();
    })

  it("owner can set attack window", async function() {
    const oldAttackWindow = await upala.attackWindow();
    const newAttackWindow = oldAttackWindow + 1000;
    await expect(upala.connect(nobody).setAttackWindow(newAttackWindow)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    );
    await upala.connect(upalaAdmin).setAttackWindow(newAttackWindow);
    expect(await upala.attackWindow()).to.be.eq(newAttackWindow);
   });

  it("owner can set execution window", async function() {
    const oldExecutionWindow = await upala.executionWindow();
    const newExecutionWindow = oldExecutionWindow + 1000;
    await expect(upala.connect(nobody).setExecutionWindow(newExecutionWindow)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    );
    await upala.connect(upalaAdmin).setExecutionWindow(newExecutionWindow);
    expect(await upala.executionWindow()).to.be.eq(newExecutionWindow);
   });
  
   it("owner can change owner", async function() {
    await expect(upala.connect(nobody).transferOwnership(nobody.getAddress())).to.be.revertedWith(
      'Ownable: caller is not the owner'
    );
    await upala.connect(upalaAdmin).transferOwnership(nobody.getAddress());
    expect(await upala.owner()).to.be.eq(await nobody.getAddress());
   });
});

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
  let manager2Group
  let manager2Pool

  before('register users', async () => {
    await resetProtocol();
    })

  describe("registration", function() {
    it("anyone can register a group - todo check group id", async function() {
      const groupIDtoBeAssigned = 3
      await upala.connect(nobody).newGroup(manager1.getAddress(), basicPoolFactory.address);
      manager1Group = await upala.getGroupID(manager1.getAddress())
      manager1Pool = await upala.getGroupPool(manager1Group)
      // expect(await upala.connect(nobody).getGroupID(manager1.getAddress())).to.eq(groupIDtoBeAssigned)
      // todo check return (entityCounter, groupPool[entityCounter]);
      // todo check events

      // register second group
      await upala.connect(nobody).newGroup(manager2.getAddress(), basicPoolFactory.address);
      manager2Group = await upala.getGroupID(manager2.getAddress())
      manager2Pool = await upala.getGroupPool(manager2Group)
    });

    it("cannot register to an existing manager", async function() {
      await expect(upala.connect(nobody).newGroup(manager1.getAddress(), basicPoolFactory.address)).to.be.revertedWith(
        'Provided address already manages a group'
      )
    });

  });

  describe("commitments", function() {

    it("a group can issue a commitment", async function() {
      const someHash = utils.formatBytes32String("First commitment!");
      await upala.connect(manager1).commitHash(someHash);
      const now = await time.latest();
      expect(await upala.commitsTimestamps(manager1Group, someHash)).to.eq(now.toString());
      // fast-forward
      await time.increase(1000);
      const otherHash = utils.formatBytes32String("Second commitment!");
      await upala.connect(manager1).commitHash(otherHash);
      const then = await time.latest();
      expect(await upala.commitsTimestamps(manager1Group, otherHash)).to.eq(then.toString());
    });

    it("two groups can issue identical commitments (cannot overwrite other group's commitment)", async function() {
      const someHash = utils.formatBytes32String("We have identical commitments!");      
      await upala.connect(manager1).commitHash(someHash);
      await upala.connect(manager2).commitHash(someHash);
      const timestamp1 = await upala.commitsTimestamps(manager1Group, someHash);
      const timestamp2 = await upala.commitsTimestamps(manager2Group, someHash);
      expect(timestamp2.sub(timestamp1)).to.eq(1);
    });
  });

  describe("score management", function() {
    let attackWindow
    let executionWindow
    let hash
    const scoreChange = oneETH.mul(42).div(100);
    const secret = utils.formatBytes32String("Zuckerberg is a human")
    const wrongSecret = utils.formatBytes32String("dfg")

    before('register users', async () => {
      attackWindow = await upala.attackWindow();
      executionWindow = await upala.executionWindow();
      if (attackWindow.toNumber() < 600  || executionWindow  < 600) {
        throw 'attackWindow or executionWindow are too short for the tests!';
      }
    })

    describe("increase base score", function() {

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

      // only group manager todo 
    });

    describe("decrease base score", function() {
      
      let newScore
      before('Commit hash', async () => {
        // scoreBefore = 
        newScore = (await upala.connect(manager1).groupBaseScore(manager1Group)).sub(1);
        hash = utils.solidityKeccak256([ 'string', 'uint256', 'bytes32' ], [ "setBaseScore", newScore, secret ]);
        await upala.connect(manager1).commitHash(hash);
      })

      it("cannot decrease score immediately after commitment", async function() {
        await expect(upala.connect(manager1).setBaseScore(newScore, secret)).to.be.revertedWith(
          'Attack window is not closed yet'
        )
      });

      it("cannot decrease score after execution window", async function() {
        await time.increase((executionWindow).add(attackWindow).toNumber());
        await expect(upala.connect(manager1).setBaseScore(newScore, secret)).to.be.revertedWith(
          'Execution window is already closed'
        )
      });

      it("cannot decrease score with wrong secret", async function() {
        await upala.connect(manager1).commitHash(hash);
        await time.increase(attackWindow.toNumber());
        await expect(upala.connect(manager1).setBaseScore(newScore, wrongSecret)).to.be.revertedWith(
          'No such commitment hash'
        )
      });

      it("can decrease score after attack window and before execution window", async function() {
        await expect(upala.connect(nobody).setBaseScore(newScore, secret)).to.be.revertedWith(
          'No such commitment hash'
        )
        await upala.connect(manager1).setBaseScore(newScore, secret);
        const scoreAfter = await upala.connect(manager1).groupBaseScore(manager1Group)
        expect(scoreAfter).to.eq(newScore)
      });
    });

    describe("publish/delete merkle roots", function() {

      let someRoot
      let delRootCommitHash
      before('Commit hash', async () => {
        someRoot = utils.formatBytes32String("Decentralize the IDs");
        delRootCommitHash = utils.solidityKeccak256([ 'string', 'uint256', 'bytes32' ], [ "deleteRoot", someRoot, secret ]);
      })

      it("group manager can publish new merkle root immediately", async function() {
        await upala.connect(manager1).publishRoot(someRoot);
        expect(await upala.roots(manager1Group, someRoot)).to.eq((await time.latest()).toString());
      });

      it("cannot delete during attack window", async function() {
        await upala.connect(manager1).commitHash(delRootCommitHash); // +1 second to "mine" transaction 
        await time.increase((attackWindow).sub(2).toNumber())  // +1s if next transaction is mined
        await expect(upala.connect(manager1).deleteRoot(someRoot, secret)).to.be.revertedWith(
          'Attack window is not closed yet'
        );
      });

      it("cannot delete after execution window", async function() {
        await time.increase((executionWindow).add(2).toNumber());
        await expect(upala.connect(manager1).deleteRoot(someRoot, secret)).to.be.revertedWith(
          'Execution window is already closed'
        )
      });

      it("cannot publish commit before root", async function() {
        await upala.connect(manager1).commitHash(delRootCommitHash);
        await upala.connect(manager1).publishRoot(someRoot);
        await time.increase((attackWindow).toNumber())
        await expect(upala.connect(manager1).deleteRoot(someRoot, secret)).to.be.revertedWith(
          'Commit is submitted before root'
        )
      });

      it("cannot delete with wrong secret", async function() {
        await upala.connect(manager1).publishRoot(someRoot);
        await upala.connect(manager1).commitHash(delRootCommitHash);
        await time.increase((attackWindow).toNumber());
        await expect(upala.connect(manager1).deleteRoot(someRoot, wrongSecret)).to.be.revertedWith(
          'No such commitment hash'
        )
      });

      it("can delete after attack window and before execution window", async function() {
        await upala.connect(manager1).deleteRoot(someRoot, secret);
        expect(await upala.commitsTimestamps(manager1Group, delRootCommitHash)).to.eq(0);
        expect(await upala.roots(manager1Group, someRoot)).to.eq(0);
      });
    });
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

  describe("ownership", function() {
  // can setGroupManager
  // only owner can setGroupManager
  // old manager can now manage new group
  // still got access to pool
  });



  describe("group details (misc)", function() {
    it("group manager can publish group meta", async function() {
      // db_url, description, etc. - from future
    });
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

   it("you can explode, you can explode, you can explode, anyone can exploooooode", async function() {
    ///function attack(uint160 groupID, uint160 identityID, uint8 score, bytes32[] calldata proof)
    });

   
   it("cannot explode from an arbitrary address", async function() {
    });

   it("cannot explode using delegate address", async function() {
    });

   it("Upala ID owner can explode (check fees and rewards)", async function() {
    });
});



