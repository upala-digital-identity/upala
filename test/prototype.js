const Upala = artifacts.require("Upala");
const FakeDai = artifacts.require("FakeDai");
const BasicPoolFactory = artifacts.require("BasicPoolFactory");
const ProtoGroup = artifacts.require("ProtoGroup");
const UBIExampleDApp = artifacts.require("UBIExampleDApp");

const BN = web3.utils.BN;
const defaultBotReward = web3.utils.toWei(new BN(3, 10), 'ether');  // 3 DAI (same denomination as ETH)
const poolDonation = web3.utils.toWei(new BN(10, 10), 'ether');



var admin = "";
var user_1 = "";
var user_2 = "";
var user_3 = "";
var network_id;

async function assertThrows(foo, msg) {
  var error = {};
  error.message = "";
  try {
      const tx = await foo;
  } catch (err) {
      error = err;

  }
  console.log(error.message);
  if (network_id == 4 || network_id == 42) {        
      //Rinkeby through infura: "Transaction: 0x3a2128319ad2216504878abd4b3358e967bfec68b8fb37eb951d986a857b6530 exited with an error (status 0)...."
      assert.equal(error.message.substring(95,100), "error", msg);
  } else {
      //Truffle develop: "VM Exception while processing transaction: revert"
      //Network id 4447
      assert.equal(error.message.substring(43,49), "revert", msg);
  }
  
}

contract('Upala', function(accounts) {
  web3.eth.getAccounts((error,result) => {
    admin = result[0];  
    groupManager = result[1]; 

    user_1 = result[2];
    user_2 = result[3];
    user_3 = result[4];
    console.log(admin, user_1, user_2, user_3);
  })

  web3.eth.defaultAccount = admin;

  it("ProtoGroup test (attack window must be 0)", async () => {
    // Basic setup for Upala prototype.
    // Uses a single group - ProtoGroup
    // ProtoGroup features:
    // - auto-assigns scores to anyone who joins.
    // - uses fakeDai pool (anyone can mint any ammount of tokens into it)
    // - Caches paths for all users (the path is as simple as [UserID, ProtoGroupID])
    // - Provides scores to UBI Dapp by requiring only ID manager (uses cached paths)
    // - Allows anyone to set botNetLimits
    // The test Will work only with attack window set to 0

    // initialize contracts
    const upalaProtocol = await Upala.deployed();
    const fakeDai = await FakeDai.deployed();
    const basicPoolFactory = await BasicPoolFactory.deployed();
    console.log("Upala protocol address: ", upalaProtocol.address);
    console.log("FakeDai pool factory address: ", basicPoolFactory.address, "\n");

    // create ProtoGroup
    group1 = await ProtoGroup.new(upalaProtocol.address, basicPoolFactory.address, {from: groupManager});
    const group1ID = await group1.getUpalaGroupID.call({from: groupManager});
    const group1PoolAddress = await group1.getGroupPoolAddress.call({from: groupManager});
    console.log("Group1 Upala ID: ", group1ID.toNumber());
    console.log("Group1 Pool Address: ", group1PoolAddress);

    // fill up group's pool
    tx = await fakeDai.freeDaiToTheWorld(group1PoolAddress, poolDonation, {from: groupManager});

    // group announces and immediately sets BotReward (since for now attack window is 0)
    tx = await group1.announceBotReward(defaultBotReward, {from: groupManager});
    console.log("Bot reward: ", web3.utils.fromWei(await upalaProtocol.getBotReward.call(group1ID)));





    // Upala prototype UX
    // "Create ID" button
    tx = await upalaProtocol.newIdentity(user_1, {from: user_1});

    // ID details
    const user1ID = await upalaProtocol.myId.call({from: user_1});
    console.log("User1 ID: ", user1ID.toNumber());

    // "Groups list"
    // No on-chain data for the list - only session data for now (and probably for the future as well)
    
    // Membership status (is user a member of a group)
    // A user is a member if a group assignes any score
    const membershipCheckPath = [user1ID, group1ID];
    // console.log("User is member of Group1:", userScoreIn.gt(0));  // true if user score greater than 0.
    // await assertThrows(upalaProtocol.memberScore.call(membershipCheckPath, {from: user_1}), 
    //     "Allowed buying block not marked for sale!");

    // "Group details", "Score provider details"
    // name, join and leave terms - all in json string
    // deposit amount 
    // For Score providers load the last group in the attack/scoring path
    console.log("Group details: ", await group1.getGroupDetails.call({from: user_1}));
    console.log("Group deposit: ", (web3.utils.fromWei(await group1.getGroupDepositAmount.call({from: user_1})), " FakeDAI"));

    // "Deposit and join" button
    // TODO acceptInvitation in Upala
    tx = await group1.join(user1ID, {from: user_1});
    
    // Membership status (is user a member of a group)
    // A user is a member if a group assignes any score
    //const membershipCheckPath = [user1ID, group1ID];
    const userScoreIn = await upalaProtocol.memberScore.call(membershipCheckPath, {from: user_1});
    console.log("User is member of Group1:", userScoreIn.gt(0));  // true if user score greater than 0.

    // "waiting for confirmation" message 
    // join is requested, but not a confirmed member yet
    // check user score
    // TODO - user requests Upala the list of invitations they accepted, then checks each for botNetLimit

    // "Leave group" button
    // Protogroup has no leaving terms. The action is just "forget" group - same as "Forget path"


    // Score providers list
    // No onchain data ever, DB for the future 
    // For now browser data + hardcoded score providers (BladerunnerDAO, etc.)

    // "Forget path" button 
    // Nothings happens onchain

    // "Your score"
    const path1 = [user1ID, group1ID];
    console.log(
      "User score in ProtoGroup:", 
      web3.utils.fromWei(await upalaProtocol.memberScore.call(path1, {from: user_1})), 
      "FakeDAI"
    );

    // "Explode"
    const user1_balance_before_attack = await fakeDai.balanceOf.call(user_1, {from: user_1});
    tx = await upalaProtocol.attack(path1, {from: user_1});
    const user1_balance_after_attack = await fakeDai.balanceOf.call(user_1, {from: user_1});
    console.log("isBN", defaultBotReward.eq(user1_balance_after_attack.sub(user1_balance_before_attack)));
    assert.equal(
      defaultBotReward.eq(user1_balance_after_attack.sub(user1_balance_before_attack)), 
      true,
      "Owner of Ads wasn't set right!");

    // deploy DApp 
    dapp1 = await UBIExampleDApp.new(group1.address, {from: groupManager});
    console.log("UBIExampleDApp address: ", basicPoolFactory.address);

    // DApp UX
    tx = await dapp1.claimUBICachedPath({from: user_1});
    console.log("User 1 UBI balance: ", web3.utils.fromWei(await dapp1.myUBIBalance.call({from: user_1})));

  })

});
