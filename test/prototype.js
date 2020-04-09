const Upala = artifacts.require("Upala");
const FakeDai = artifacts.require("FakeDai");
const BasicPoolFactory = artifacts.require("BasicPoolFactory");
const ProtoGroup = artifacts.require("ProtoGroup");
const UBIExampleDApp = artifacts.require("UBIExampleDApp");


const oneDollar = web3.utils.toWei("1", 'ether');
const poolDonation = web3.utils.toWei("10", 'ether');

var BN = web3.utils.BN;

var admin = "";
var user_1 = "";
var user_2 = "";
var user_3 = "";
var network_id;

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
    console.log("FakeDai pool factory address: ", basicPoolFactory.address);

    // create ProtoGroup
    group1 = await ProtoGroup.new(upalaProtocol.address, basicPoolFactory.address, {from: groupManager});
    const group1ID = (await group1.getUpalaGroupID.call({from: groupManager})).toNumber();
    const group1PoolAddress = await group1.getGroupPoolAddress.call({from: groupManager});
    console.log("Group 1 Upala ID: ", group1ID);
    console.log("Group 1 Pool Address: ", group1PoolAddress);

    // fill up group's pool
    tx = await fakeDai.freeDaiToTheWorld(group1PoolAddress, poolDonation, {from: groupManager});

    // group announces and immediately sets BotReward (since for now attack window is 0)
    tx = await group1.announceBotReward(oneDollar, {from: groupManager});
    console.log("Bot reward: ", web3.utils.fromWei(await upalaProtocol.getBotReward.call(group1ID)));

    // deploy DApp 
    dapp1 = await UBIExampleDApp.new(group1.address, {from: groupManager});
    console.log("UBIExampleDApp address: ", basicPoolFactory.address);



    // Upala prototype UX
    // "Create ID" button
    tx = await upalaProtocol.newIdentity(user_1, {from: user_1});

    // ID details
    const user1ID = (await upalaProtocol.myId.call({from: user_1})).toNumber();
    console.log("User1 ID: ", user1ID);

    // "Memberships" ("Groups list")
    // No on-chain data - only session data for now
    // Or probably same as "waiting for confirmation" 
    // TODO - implement "waiting for confirmation" functionality first

    // "Group details", "Score provider details"
    // name, join and leave terms - all in json string
    // deposit amount 
    // For Score provider loads the last group in the attack/scoring path
    // TODO - add functions to protogroup

    // "waiting for confirmation" message 
    // join is requested, but not a confirmed member yet
    // check user score
    // TODO - user requests Upala the list of invitations they accepted, then checks each for botNetLimit

    // "Leave group" button
    // TODO - add function to protogroup

    // Score providers list
    // No onchain data ever
    // For now browser data + hardcoded score providers (BladerunnerDAO, what else?)
    // DB for later 

    // "Forget path" button 
    // Nothings happens on blockchain

    // "Your score"
    // TODO - log function call requesting price

    // "Explode"
    // TODO - test explosion function

    // "Deposit and join" button
    tx = await group1.join(user1ID, {from: user_1});

    // DApp UX
    tx = await dapp1.claimUBICachedPath({from: user_1});
    console.log("User 1 UBI balance: ", web3.utils.fromWei(await dapp1.myUBIBalance.call({from: user_1})));

  })

});
