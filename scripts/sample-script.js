// We require the Buidler Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `buidler run <script>` you'll find the Buidler
// Runtime Environment's members available in the global scope.
const bre = require("@nomiclabs/buidler");
const fs = require('fs');
const chalk = require('chalk');

async function main() {
  // Buidler always runs the compile task when running scripts through it. 
  // If this runs in a standalone fashion you may want to call compile manually 
  // to make sure everything is compiled
  // await bre.run('compile');

  const networkName = bre.network.name;
  const publishDir =  "../scaffold-eth/rad-new-dapp/packages/react-app/src/contracts/" + networkName;
  if (!fs.existsSync(publishDir)){
    fs.mkdirSync(publishDir);
  }

  let finalContractList = []
  var finalContracts = {}

  console.log("📡 Deploying to", networkName)

  async function deployContract(contractName, ...args) {
    const contractFactory = await ethers.getContractFactory(contractName);
    const contractInstance = await contractFactory.deploy(...args);
    await contractInstance.deployed();
    console.log(chalk.cyan(contractName),"deployed to:", chalk.magenta(contractInstance.address));
    // fs.writeFileSync("artifacts/"+contractName+".address",contractInstance.address);


    finalContracts[contractName] = {
      address: contractInstance.address,
      bytecode: contractFactory.bytecode,
      interface: contractInstance.interface, // TODO will it work as ABI in Front-end
    };

    
    try {
        let contract = fs.readFileSync(bre.config.paths.artifacts+"/"+contractName+".json").toString()
        // let address = fs.readFileSync(bre.config.paths.artifacts+"/"+contractName+".address").toString()
        let address = contractInstance.address;
        contract = JSON.parse(contract);

        // Publish
        fs.writeFileSync(publishDir+"/"+contractName+".address.js","module.exports = \""+address+"\"");
        fs.writeFileSync(publishDir+"/"+contractName+".abi.js","module.exports = "+JSON.stringify(contract.abi));
        // fs.writeFileSync(publishDir+"/"+contractName+".bytecode.js","module.exports = \""+contract.bytecode+"\"");
        fs.writeFileSync(publishDir+"/"+contractName+".bytecode.js","module.exports = \""+contractFactory.bytecode+"\"");
        finalContractList.push(contractName)

      }catch(e){console.log(e)}
      
      return contractInstance;
  }

  // await deployContract("SmartContractWallet", "0xf53bbfbff01c50f2d42d542b09637dca97935ff7");
  upala = await deployContract("Upala")

  // Testing environment
  fakeDai = await deployContract("FakeDai");
  basicPoolFactory = await deployContract("BasicPoolFactory", fakeDai.address);
  await upala.setapprovedPoolFactory(basicPoolFactory.address, "true");








  console.log(chalk.green("\nDEPLOYING GROUPS \n"));
  /////////////////////////////////////////////////

  const defaultBotReward = ethers.utils.parseEther("3");
  const poolDonation = ethers.utils.parseEther("1000");
  var groupsAddresses = []

  async function deployGroup(groupContractName, details, multiplier) {
    newGroup = await deployContract(groupContractName, upala.address, basicPoolFactory.address); // {from: groupManager}
    groupsAddresses.push(newGroup.address);

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

  const [group1, group1ID] = await deployGroup("ProtoGroup", JSON.stringify(group1Details), 1);
  const [group2, group2ID] = await deployGroup("ProtoGroup", JSON.stringify(group2Details), 2);
  const [group3, group3ID] = await deployGroup("ProtoGroup", JSON.stringify(group3Details), 3);





  console.log(chalk.green("\nDEPLOYING BLADERUNNER \n"));
  ///////////////////////////////////////////////////////


  bladerunnerDetails = {
    "title": "BladerunnerDAO",
    "description": "Users cannot join this group directly - only its subgroups (entry-tests). Members of BladerunnerDAO decide which entry-tests to approve.",
    "short_description": "Bladerunner Score provider"
    }
  const [bladerunner, bladerunnerID] = await deployGroup("BladerunnerDAO", JSON.stringify(bladerunnerDetails), 5);




  console.log(chalk.green("\nTESTING GROUPS\n"));
  ///////////////////////////////////////////////

  const [owner, m1, m2, m3, u1, u2, u3] = await ethers.getSigners();

  // Upala prototype UX
  // "Create ID" button
  tx = await upala.connect(u1).newIdentity(u1.getAddress());

  // ID details
  const user1ID = await upala.connect(u1).myId();
  console.log("User1 ID: ", user1ID.toNumber());

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
  console.log("group1.connect(u1)");

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
  sampleDapp = await deployContract("UBIExampleDApp", upala.address, group1ID);
  
  // add credit
  tx = await group1.connect(u1).freeAppCredit(sampleDapp.address);

  const path = [user1ID, group1ID];
  tx = await sampleDapp.connect(u1).claimUBI(path);
  console.log("App credit: ", ethers.utils.formatEther(await upala.connect(u1).appBalance(group1ID, sampleDapp.address)));

  console.log("UBIExampleDApp address: ", sampleDapp.address);
  // console.log("User 1 UBI balance: ", await sampleDapp.connect(u1).myUBIBalance());
  console.log("User 1 UBI balance: ", ethers.utils.formatEther(await sampleDapp.connect(u1).myUBIBalance()));










  // console.log(finalContracts);
  //   deployer.deploy(BasicPoolFactory, FakeDai.address).then(() => {
  //     Upala.deployed().then(upala => {
  //         return upala.setapprovedPoolFactory(BasicPoolFactory.address, "true");
  //     });
  // });

  // console.log(chalk.green("\n📡 PUBLISHING\n"));

  // fs.writeFileSync(publishDir+"/contracts.js","module.exports = "+JSON.stringify(finalContractList));
  // fs.writeFileSync(publishDir+"/groups.js","module.exports = "+JSON.stringify(groupsAddresses));


}



// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
