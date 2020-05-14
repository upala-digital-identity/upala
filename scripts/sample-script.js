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

  const publishDir =  "../scaffold-eth/rad-new-dapp/packages/react-app/src/contracts"
  if (!fs.existsSync(publishDir)){
    fs.mkdirSync(publishDir);
  }

  let finalContractList = []
  var finalContracts = {}

  console.log("📡 Deploy")

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

    return contractInstance;
    // try {
    //     let contract = fs.readFileSync(bre.config.paths.artifacts+"/"+contractName+".json").toString()
    //     // let address = fs.readFileSync(bre.config.paths.artifacts+"/"+contractName+".address").toString()
    //     let address = contractInstance.address;
    //     contract = JSON.parse(contract);

    //     // Publish
    //     fs.writeFileSync(publishDir+"/"+contractName+".address.js","module.exports = \""+address+"\"");
    //     fs.writeFileSync(publishDir+"/"+contractName+".abi.js","module.exports = "+JSON.stringify(contract.abi));
    //     // fs.writeFileSync(publishDir+"/"+contractName+".bytecode.js","module.exports = \""+contract.bytecode+"\"");
    //     fs.writeFileSync(publishDir+"/"+contractName+".bytecode.js","module.exports = \""+contractFactory.bytecode+"\"");
    //     finalContractList.push(contractName)
    //     console.log(contractName, " Published")

    //   }catch(e){console.log(e)}
  }

  await deployContract("SmartContractWallet", "0xf53bbfbff01c50f2d42d542b09637dca97935ff7");
  upala = await deployContract("Upala")

  // Testing environment
  fakeDai = await deployContract("FakeDai");
  basicPoolFactory = await deployContract("BasicPoolFactory", fakeDai.address);
  await upala.setapprovedPoolFactory(basicPoolFactory.address, "true");

  // create ProtoGroup
  group1 = await deployContract("ProtoGroup", upala.address, basicPoolFactory.address); // {from: groupManager}
  const group1ID = await group1.getUpalaGroupID();
  const group1PoolAddress = await group1.getGroupPoolAddress();
  console.log("Group1 Upala ID: ", group1ID.toNumber());
  console.log("Group1 Upala ID: ", group1ID);
  console.log("Group1 Pool Address: ", group1PoolAddress);

  // fill up group's pool
  const poolDonation = ethers.utils.parseEther("10");
  tx = await fakeDai.freeDaiToTheWorld(group1PoolAddress, poolDonation);

  // group announces and immediately sets BotReward (since for now attack window is 0)
  const defaultBotReward = ethers.utils.parseEther("3");
  tx = await group1.announceBotReward(defaultBotReward);
  console.log("Bot reward: ", ethers.utils.formatEther(await upala.getBotReward(group1ID)));



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

  // "Group details", "Score provider details"
  // name, join and leave terms - all in json string
  // deposit amount 
  // For Score providers load the last group in the attack/scoring path
  console.log("Group details: ", (await group1.getGroupDetails()).slice(0, 40));
  console.log("Group deposit: ", (ethers.utils.formatEther(await group1.getGroupDepositAmount.call()), " FakeDAI"));

  // "Deposit and join" button
  tx = await group1.connect(u1).join(user1ID);
  console.log("group1.connect(u1)");

  // Membership status (user is a member of a group)
  // A user is a member if a group assignes any score
  //const membershipCheckPath = [user1ID, group1ID];
  const userScoreIn = await upala.connect(u1).memberScore(membershipCheckPath);
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
    ethers.utils.formatEther(await upala.connect(u1).memberScore(path1)), 
    "FakeDAI"
  );



  // "Explode"
  const user1_balance_before_attack = await fakeDai.connect(u1).balanceOf(u1.getAddress());
  tx = await upala.connect(u1).attack(path1);
  const user1_balance_after_attack = await fakeDai.connect(u1).balanceOf(u1.getAddress());
  console.log("isBN", defaultBotReward.eq(user1_balance_after_attack.sub(user1_balance_before_attack)));
  assert.equal(
    defaultBotReward.eq(user1_balance_after_attack.sub(user1_balance_before_attack)), 
    true,
    "Owner of Ads wasn't set right!");


  // deploy DApp 
  sampleDapp = await deployContract("UBIExampleDApp", group1.address);
  
  // DApp UX
  tx = await sampleDapp.connect(u1).claimUBICachedPath();
  console.log("UBIExampleDApp address: ", sampleDapp.address);
  // console.log("User 1 UBI balance: ", await sampleDapp.connect(u1).myUBIBalance());
  console.log("User 1 UBI balance: ", ethers.utils.formatEther(await sampleDapp.connect(u1).myUBIBalance()));









  // console.log(finalContracts);
  //   deployer.deploy(BasicPoolFactory, FakeDai.address).then(() => {
  //     Upala.deployed().then(upala => {
  //         return upala.setapprovedPoolFactory(BasicPoolFactory.address, "true");
  //     });
  // });


  console.log("📡 Publishing \n")
  fs.writeFileSync(publishDir+"/contracts.js","module.exports = "+JSON.stringify(finalContractList))



}



// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
