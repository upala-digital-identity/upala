// We require the Buidler Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `buidler run <script>` you'll find the Buidler
// Runtime Environment's members available in the global scope.
const bre = require("@nomiclabs/buidler");
const fs = require('fs');
const chalk = require('chalk');

const exampleDappDir = "../example-app/packages/contracts/";
const newPublishDir = "../scaffold-eth/rad-new-dapp/packages/contracts/"




async function main() {
  // Buidler always runs the compile task when running scripts through it. 
  // If this runs in a standalone fashion you may want to call compile manually 
  // to make sure everything is compiled
  // await bre.run('compile');

  const networkName = bre.network.name;

  var finalContracts = {}
  var finalGroups = {}

  console.log(chalk.green("\n👤 USERS\n"));
  /////////////////////////////////////////////////

  const [owner, m1, m2, m3, u1, u2, u3] = await ethers.getSigners();
  console.log(
    "owner", chalk.blue(await owner.getAddress()), ethers.utils.formatEther(await owner.getBalance()),
    "\nm1", chalk.blue(await m1.getAddress()), ethers.utils.formatEther(await m1.getBalance()),
    "\nm2", chalk.blue(await m2.getAddress()), ethers.utils.formatEther(await m2.getBalance()),
    "\nm3", chalk.blue(await m3.getAddress()), ethers.utils.formatEther(await m3.getBalance()),
    "\nu1", chalk.blue(await u1.getAddress()), ethers.utils.formatEther(await u1.getBalance()),
    "\nu2", chalk.blue(await u2.getAddress()), ethers.utils.formatEther(await u2.getBalance()),
    "\nu3", chalk.blue(await u3.getAddress()), ethers.utils.formatEther(await u3.getBalance())
    );
  

  console.log(chalk.green("\n📡 DEPLOYING (", networkName, ")\n"));
  /////////////////////////////////////////////////


  async function deployContract(contractName, ...args) {
    const contractFactory = await ethers.getContractFactory(contractName);
    const contractInstance = await contractFactory.deploy(...args);
    await contractInstance.deployed();
    
    console.log(chalk.cyan(contractName),"deployed to:", chalk.magenta(contractInstance.address));
    finalContracts[contractName] = {
      address: contractInstance.address,
      abi: contractInstance.interface.abi, // TODO will it work as ABI in Front-end
    };

    return contractInstance;
  }

  // await deployContract("SmartContractWallet", "0xf53bbfbff01c50f2d42d542b09637dca97935ff7");
  upala = await deployContract("Upala")

  // Testing environment
  fakeDai = await deployContract("FakeDai");
  basicPoolFactory = await deployContract("BasicPoolFactory", fakeDai.address);
  const basicPoolFactory_tx = await upala.setapprovedPoolFactory(basicPoolFactory.address, "true");
  console.log("approvedPoolFactory");







  console.log(chalk.green("\nDEPLOYING GROUPS \n"));
  /////////////////////////////////////////////////

  const defaultBotReward = ethers.utils.parseEther("3");
  const poolDonation = ethers.utils.parseEther("1000");
  var groupsAddresses = []

  async function deployGroup(groupName, groupContractName, details, multiplier) {
    console.log("deployContract", groupContractName, upala.address, basicPoolFactory.address);
    newGroup = await deployContract(groupContractName, upala.address, basicPoolFactory.address); // {from: groupManager}
    
    finalGroups[groupName] = {
      address: newGroup.address,
      abi: newGroup.interface.abi,
    };

    groupsAddresses.push(newGroup.address);
    console.log(chalk.blue("newGroup.address:"), newGroup.address)
    let newGroupID = await newGroup.getUpalaGroupID();
    let newGroupPoolAddress = await newGroup.getGroupPoolAddress();
    await fakeDai.freeDaiToTheWorld(newGroupPoolAddress, poolDonation.mul(multiplier));
    await newGroup.announceAndSetBotReward(defaultBotReward.mul(multiplier));
    await newGroup.setDetails(details);
    console.log(
      chalk.blue("Upala ID:"), newGroupID.toNumber(), 
      chalk.blue("Pool:"), newGroupPoolAddress,
      chalk.blue("Bal:"), ethers.utils.formatEther(await fakeDai.balanceOf(newGroupPoolAddress)),
      chalk.blue("Reward:"), ethers.utils.formatEther(await upala.getBotReward(newGroupID)));
      // "Group details", "Score provider details"
    // For Score providers load the last group in the attack/scoring path
    console.log(chalk.blue("Details: "), (await newGroup.getGroupDetails()).slice(0, 40));
    // console.log(chalk.blue("Deposit: "), (ethers.utils.formatEther(await newGroup.getGroupDepositAmount.call()), " FakeDAI"));
    
    return [newGroup, newGroupID];
  }

  /* {
    "version": "0.1",
    "title": "Base group",
    "description": "Autoassigns FakeDAI score to anyone who joins",
    "join-terms": "No deposit required (ignore the ammount you see and join)",
    "leave-terms": "No deposit - no refund"} */
  group1Details = {
    "title": "MetaCartel",
    "description": "Currently autoassigns FakeDAI score to anyone who joins",
    "short_description": "MetaCartel members only"
    }
  group2Details = {
    "title": "MolochDAO",
    "description": "Currently autoassigns FakeDAI score to anyone who joins",
    "short_description": "MolochDAO members only"
    }
  group3Details = {
    "title": "MetaGame",
    "description": "Currently autoassigns FakeDAI score to anyone who joins",
    "short_description": "MetaGamers only"
    }

  console.log("deployGroup, wait 60 sec");
  // sleep(60000);
  console.log("deploy");
  const [group1, group1ID] = await deployGroup(group1Details.title, "ProtoGroup", JSON.stringify(group1Details), 1);
  const [group2, group2ID] = await deployGroup(group2Details.title, "ProtoGroup", JSON.stringify(group2Details), 2);
  const [group3, group3ID] = await deployGroup(group3Details.title, "ProtoGroup", JSON.stringify(group3Details), 3);





  console.log(chalk.green("\nDEPLOYING BLADERUNNER \n"));
  ///////////////////////////////////////////////////////


  bladerunnerDetails = {
    "title": "BladerunnerDAO",
    "description": "Users cannot join this group directly - only its subgroups (entry-tests). Members of BladerunnerDAO decide which entry-tests to approve.",
    "short_description": "Bladerunner Score provider"
    }
  const [bladerunner, bladerunnerID] = await deployGroup(bladerunnerDetails.title, "BladerunnerDAO", JSON.stringify(bladerunnerDetails), 5);




  console.log(chalk.green("\nTESTING GROUPS\n"));
  ///////////////////////////////////////////////

  

  // Upala prototype UX
  // "Create ID" button
  tx = await upala.connect(u1).newIdentity(u1.getAddress());
  tx = await upala.connect(u2).newIdentity(u2.getAddress());

  // ID details
  const user1ID = await upala.connect(u1).myId();
  const user2ID = await upala.connect(u2).myId();
  
  console.log(chalk.blue("User1 Address: "), await u1.getAddress());
  console.log(chalk.blue("User2 Address: "), await u2.getAddress());

  console.log(chalk.blue("User1 ID: "), user1ID.toNumber());
  console.log(chalk.blue("User2 ID: "), user2ID.toNumber());

  // "Groups list"
  // No on-chain data for the list - fetch from 3Box (private Spaces and 3Box.js)
  // https://docs.3box.io/network/architecture https://docs.3box.io/build/web-apps/storage 
  // 3Box threads for future https://medium.com/3box/confidential-threads-api-17df60b34431 
  
  // Membership status (user not a member of a group)
  // A user is a member if a group assigns any score
  const membershipCheckPath = [user1ID, group1ID];
  // const error = await isThrowing(upala.memberScore.call(membershipCheckPath, {from: user_1}));
  // console.log(error);
  // TODO probably better return 0 from Upala...



  // "Deposit and join" button
  tx = await group1.connect(u1).join(user1ID);
  tx = await group1.connect(u2).join(user2ID);

  // Membership status (user is a member of a group)
  // A user is a member if a group assignes any score
  //const membershipCheckPath = [user1ID, group1ID];
  const userScoreIn = await upala.connect(u1).myScore(membershipCheckPath);
  console.log("User is member of Group1:", userScoreIn.gt(0));  // true if user score greater than 0.

  // "waiting for confirmation" message 
  // join is requested, but not a confirmed member yet
  // check user score (check each group in the list for botNetLimit)

  // "Leave group" button
  // Protogroup has no leaving terms. The action is just "forget" group - same as "Forget path"
  // Removes group from 3Box

  // Score providers list
  // 3Box Private spaces as DB + hardcoded score providers (BladerunnerDAO, etc.)

  // "Forget path" button 
  // Nothings happens onchain
  // Removes path from 3Box

  // "Your score"
  const path1 = [user1ID, group1ID];
  console.log(
    "User score in ProtoGroup:", 
    ethers.utils.formatEther(await upala.connect(u1).myScore(path1)), 
    "FakeDAI"
  );


  console.log(chalk.green("\nTESTING BLADERUNNER SCORE\n"));
  ///////////////////////////////////////////////
  
  // approve all 3 groups in BladeRunner by setting very high bot net limits
  await bladerunner.connect(u1).announceAndSetBotnetLimit(group1ID, defaultBotReward.mul(100));
  await bladerunner.connect(u1).announceAndSetBotnetLimit(group2ID, defaultBotReward.mul(100));
  await bladerunner.connect(u1).announceAndSetBotnetLimit(group3ID, defaultBotReward.mul(100));
  const pathToBladerunner = [user1ID, group1ID, bladerunnerID];
  console.log(
    "User score in Bladerunner:", 
    ethers.utils.formatEther(await upala.connect(u1).myScore(pathToBladerunner)), 
    "FakeDAI"
  );




  // // "Explode"
  // const user1_balance_before_attack = await fakeDai.connect(u1).balanceOf(u1.getAddress());
  // tx = await upala.connect(u1).attack(path1);
  // const user1_balance_after_attack = await fakeDai.connect(u1).balanceOf(u1.getAddress());
  // console.log("isBN", defaultBotReward.eq(user1_balance_after_attack.sub(user1_balance_before_attack)));
  // assert.equal(
  //   defaultBotReward.eq(user1_balance_after_attack.sub(user1_balance_before_attack)), 
  //   true,
  //   "Owner of Ads wasn't set right!");



  console.log(chalk.green("\nTESTING DAPP\n"));
  ///////////////////////////////////////////////

  // deploy DApp
  // setUpala
  // approve score provider by id
  // constructor (address upalaAddress, address trustedProviderUpalaID) 
  sampleDapp = await deployContract("UBIExampleDApp", upala.address, bladerunnerID);
  
  // add credit
  //await sleep(60000);
  tx = await bladerunner.connect(u1).freeAppCredit(sampleDapp.address);
  //await sleep(60000);
  const path = [user1ID, group1ID, bladerunnerID];
  tx = await sampleDapp.connect(u1).claimUBI(path);
  console.log("App credit: ", ethers.utils.formatEther(await upala.connect(u1).appBalance(bladerunnerID, sampleDapp.address)));

  console.log("UBIExampleDApp address: ", sampleDapp.address);
  // console.log("User 1 UBI balance: ", await sampleDapp.connect(u1).myUBIBalance());
  console.log("User 1 UBI balance: ", ethers.utils.formatEther(await sampleDapp.connect(u1).myUBIBalance()));










  // console.log(finalContracts);
  //   deployer.deploy(BasicPoolFactory, FakeDai.address).then(() => {
  //     Upala.deployed().then(upala => {
  //         return upala.setapprovedPoolFactory(BasicPoolFactory.address, "true");
  //     });
  // });

  console.log(chalk.green("\n📡 PUBLISHING\n"));


  function exportContracts(contracts, groups, pubDir, network) {

    function exportAddresses(contracts) {
      fileContents = "const addresses = {";
      if (contracts) {
        for (const [contract, params] of Object.entries(contracts)) {
          fileContents += "\n  " + contract + ": \"" + params.address + "\",";
        }
      }
      fileContents += "\n};\nexport default addresses;"
      return fileContents;
    }

    function exportAbis(contracts) {
      function abiImports(contracts) {
        fileContents = "";
        for (const [contract, params] of Object.entries(contracts)) {
          fileContents += "import " + contract + " from \"./abis/" + contract + ".json\";\n";
        }
        return fileContents;
      }

      function abisObject(contracts) {
        fileContents = "\nconst abis = {";
        for (const [contract, params] of Object.entries(contracts)) {
          fileContents += "\n  " + contract + ": " + contract + ",";
        }
        fileContents += "\n}; \n\nexport default abis;"
        return fileContents;
      }
      return abiImports(contracts) + abisObject(contracts);
    }

    const srcDir = pubDir + "src/";
    const abisDir = pubDir + "src/abis/";
    const addressesDir = pubDir + "src/addresses/";
    const groupsDir = pubDir + "src/groups/";

    // create dirs
    const dirs = [pubDir, srcDir, abisDir, addressesDir, groupsDir];
    dirs.forEach(entry => {
        if (!fs.existsSync(entry)){
          fs.mkdirSync(entry);
        }
      });

    // create empty addresses files if files don't exist
    const addressesFiles = [
      addressesDir + "main.js",
      addressesDir + "rinkeby.js",
      addressesDir + "localhost.js",
      addressesDir + "goerli.js",
      addressesDir + "mumbai.js",

      groupsDir + "main.js",
      groupsDir + "rinkeby.js",
      groupsDir + "localhost.js",
      groupsDir + "goerli.js",
      groupsDir + "mumbai.js",
      ];
    addressesFiles.forEach(path => {
        if (!fs.existsSync(path)){
          fs.writeFileSync(path, exportAddresses());
        }
      });

    // genrate addresses and abis files
    fs.writeFileSync(addressesDir + "/" + network + ".js", exportAddresses(contracts));
    fs.writeFileSync(groupsDir + "/" + network + ".js", exportAddresses(groups));
    for (const [contract, params] of Object.entries(contracts)) {
      fs.writeFileSync(abisDir + "/" + contract + ".json", JSON.stringify(params.abi));
    }
    fs.writeFileSync(srcDir + "/abis.js", exportAbis(contracts));

    // copy template files
    fs.copyFile('./scripts/exporter/index.js.template', srcDir + "index.js", (err) => {
      if (err) throw err;
    });
    fs.copyFile('./scripts/exporter/package.json.template', pubDir + "/package.json", (err) => {
      if (err) throw err;
    });
  }

  // exportContracts(finalContracts, finalGroups, newPublishDir, networkName);
}



// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
