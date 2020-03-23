const Upala = artifacts.require("Upala");

var admin = "";
var user_1 = "";
var user_2 = "";
var user_3 = "";
var network_id;

contract('Upala', function(accounts) {
  web3.eth.getAccounts((error,result) => {
    admin = result[0];  // 0x0230c6dd5db1d3f871386a3ce1a5a836b2590044
    user_1 = result[1]; // 0x5adb20e1ea529f159b191b663b9240f29f903727
    user_2 = result[2]; // 0xe66ec08db6d02312d4eccbfa505e68485c42fe86
    user_3 = result[3]; // 0x0172195ab28740d83b279456c38c020420b2f03a
    console.log(admin, user_1, user_2, user_3);
  })

  web3.eth.defaultAccount = admin;

// Helper functions

  function getBalance(address) {
    return new Promise (function(resolve, reject) {
      web3.eth.getBalance(address, function(error, result) {
        if (error) {
            reject(error);
        } else {
            resolve(result);
        }
      })
    })
  }

  function logGas(_tx, _tx_name) {
    console.log("       > gasUsed for", _tx_name, _tx.receipt.gasUsed); //, '|', _tx.receipt.cumulativeGasUsed);
  }

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

  async function ignoreThrow(foo, msg) {
    var error = {};
    error.message = "";
    try {
        const tx = await foo;
    } catch (err) {}
  }

  //credits https://github.com/OpenZeppelin/openzeppelin-solidity/blob/f4228f1b49d6d505d3311e5d962dfb0febdf61df/test/Bounty.test.js#L82-L109
  function awaitEvent (event, handler) {
      return new Promise((resolve, reject) => {
        function wrappedHandler (...args) {
          Promise.resolve(handler(...args)).then(resolve).catch(reject);
        }
        event.watch(wrappedHandler);
      });
  }


  it("should let create group", async () => {
    const U = await Upala.deployed();
    const groupManager = user_1;

    // tx = await U.newGroup(groupManager, {from: groupManager});

    // assert.equal(await U.getBlockOwner.call(1, 1), groupManager,                       
    //     "the block 1x1 owner wasn't set");
  })

});
