pragma solidity ^0.6.0;

// import "../universe/i-score-provider.sol";
import "../protocol/upala.sol";
import "../pools/i-pool.sol";
// ../universe/proto-group.sol

// Upala library for DApps (human library)
contract usingUpala {

    // IScoreProvider scoreProviderContract;  // e.g. BladerunnerDAO
    uint8 public version;
    Upala upala;

    /*****
    SCORES
    ******/

    function scoreIsAboveThreshold(
        address pool, 
        uint256 threshold, 
        address identityID, 
        uint8 score, 
        bytes calldata proof)
    internal 
    returns (bool) 
    {
        return (userScore(pool, identityID, score, proof) >= threshold);
    }

    // verifies and returns user score
    function userScore(
        address pool, 
        address identityID, 
        uint8 score, 
        bytes calldata proof) 
    internal 
    returns (uint256)
    {   
        // msg.sender is user
        return IPool(pool).userScore(msg.sender, identityID, score, proof);
    }


    /*****
    MANAGE
    ******/

    function setUpalaAddress(address upalaAddress) internal {
        upala = Upala(upalaAddress);
    }

    // Manage trusted score providers
    // Need to register DApp in all trusted pools
    function approveScoreProvider(address groupAddress) internal {
        IPool(groupAddress).registerDapp();
    }
    function removeScoreProvider(address groupAddress) internal {
        IPool(groupAddress).unregisterDapp();
    }
}

contract UBIExampleDApp is usingUpala {  // gotHumans requiringHumans 

    uint256 MINIMAL_SCORE = 1 * 10 ** 18;  // 1 DAI
    uint256 UBI = 10 * 10 ** 18;  // 10 Tokens

    mapping (uint160 => bool) claimed;
    mapping (address => uint256) balances;

    constructor (address upalaAddress, uint160 trustedProviderUpalaID) public {
        approveScoreProvider(trustedProviderUpalaID);
        setUpalaAddress(upalaAddress);
    }

    function claimUBI(uint160[] calldata path) external {
        uint160 identityID = getUncofirmedUserIdentity(path);
        require (claimed[identityID] == false, "Already claimed");

        require(scoreIsAboveThreshold(msg.sender, path, MINIMAL_SCORE), "Score is too low");

        _payOutUBI(identityID, msg.sender);
    }

    function _payOutUBI(uint160 identityID, address recipient) private {
        balances[recipient] += UBI;
        claimed[identityID] = true;
    }

    function myUBIBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    function myUBIBalanceTest() external view returns (address) {
        return msg.sender;
    }
}