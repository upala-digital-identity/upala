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
    admin = result[0];  // 0x0230c6dd5db1d3f871386a3ce1a5a836b2590044
    groupManager = result[1]; // 0x5adb20e1ea529f159b191b663b9240f29f903727\

    user_1 = result[2]; // 0xe66ec08db6d02312d4eccbfa505e68485c42fe86
    user_2 = result[3]; // 0x0172195ab28740d83b279456c38c020420b2f03a
    //console.log(admin, user_1, user_2, user_3);
  })

  web3.eth.defaultAccount = admin;

  it("should let create group", async () => {
    const upalaProtocol = await Upala.deployed();
    const fakeDai = await FakeDai.deployed();
    const basicPoolFactory = await BasicPoolFactory.deployed();

    // create proto group
    group1 = await ProtoGroup.new(upalaProtocol.address, basicPoolFactory.address, {from: groupManager});
    const group1ID = (await group1.getUpalaGroupID.call()).toNumber();
    const group1PoolAddress = await group1.getGroupPoolAddress.call();
    console.log("Group ID: ", group1ID);
    console.log("Group Pool Address: ", group1PoolAddress);

    // fill up group's pool
    tx = await fakeDai.freeDaiToTheWorld(group1PoolAddress, poolDonation, {from: groupManager});

    // group announces and then anyone sets BotReward 
    tx = await group1.announceBotReward(oneDollar, {from: groupManager});
    tx = await upalaProtocol.setBotReward(group1ID, oneDollar, {from: user_1});
    console.log("Bot reward: ", web3.utils.fromWei(await upalaProtocol.getBotReward.call(group1ID)));

    // deploy DApp 
    dapp1 = await UBIExampleDApp.new(group1.address, {from: groupManager});

    // Upala homepage UX
    // register users and auto-assign scores
    tx = await upalaProtocol.newIdentity(user_1, {from: user_1});
    const user1ID = (await upalaProtocol.myId.call({from: user_1})).toNumber();
    console.log("User1 ID: ", user1ID);
    tx = await group1.join(user1ID, {from: user_1});
    tx = await group1.setBotnetLimit(user1ID, {from: user_1});

    // DApp UX
    tx = await dapp1.claimUBICachedPath({from: user_1});
    console.log("User 1 UBI balance: ", web3.utils.fromWei(await dapp1.myUBIBalance.call({from: user_1})));
    
    //console.log("User1 Score: ", user1ID);

  //}


    // function announceBotnetLimit(uint160 member, uint limit) external {

    // // anyone 
    
    // function setBotnetLimit(uint160 group, uint160 member, uint limit) external override(IUpala) {
    // newPool(address poolFactory, uint160 poolOwner
    // assert.equal(await upalaProtocol.getBlockOwner.call(1, 1), groupManager,                       
    //     "the block 1x1 owner wasn't set");
  })

});
