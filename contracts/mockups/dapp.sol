pragma solidity ^0.6.0;

import "../protocol/upala.sol";
// import "../pools/i-pool.sol"; // production todo create IPool
import "../pools/signed-scores-pool.sol";

// Upala library for DApps (human library)
contract usingUpala {

    /*****
    SCORES
    ******/

    // checks if score is equal or above threshold
    function scoreIsAboveThreshold(
        uint256 threshold,
        address pool,
        address identityID, 
        uint8 score, 
        bytes memory proof)
    internal 
    returns (bool){
        return (userScore(pool, identityID, score, proof) >= threshold);
    }

    // verifies and returns user score
    function userScore(
        address pool, 
        address identityID, 
        uint8 score, 
        bytes memory proof) 
    internal 
    returns (uint256){
        // msg.sender is user
        return SignedScoresPool(pool).userScore(msg.sender, identityID, score, proof);
    }

    /************
    MANAGE GROUPS
    *************/

    // Manage trusted score providers
    // (Need to register DApp in all trusted pools)
    function approveScoreProvider(address groupAddress) internal {
        SignedScoresPool(groupAddress).registerDapp();
    }

    function removeScoreProvider(address groupAddress) internal {
        SignedScoresPool(groupAddress).unregisterDapp();
    }
}

contract UBIExampleDApp is usingUpala {  // gotHumans requiringHumans 

    uint256 UBI = 10 * 10 ** 18;  // 10 Tokens
    uint256 MINIMAL_SCORE = 1 * 10 ** 18;  // 1 DAI
    
    mapping (address => bool) claimed;
    mapping (address => uint256) balances;

    constructor (uint256 ubi, uint256 minimalScore, address upalaAddress) public {
        UBI = ubi; // e.g. 10 * 10 ** 18;  // 10 Tokens
        MINIMAL_SCORE = minimalScore; // e.g. 1 * 10 ** 18;  // 1 DAI
    }

    function claimUBI(
        address pool,
        uint256 threshold, 
        address identityID, 
        uint8 score, 
        bytes calldata proof) 
    external {
        require (claimed[identityID] == false, "Already claimed or not in the list");
        require(scoreIsAboveThreshold(MINIMAL_SCORE, pool, identityID, score, proof), "Score is too low");

        _payOutUBI(identityID, msg.sender);
    }

    function _payOutUBI(address identityID, address recipient) private {
        balances[recipient] += UBI;
        claimed[identityID] = true;
    }

    function myUBIBalance() external view returns (uint256) {
        return balances[msg.sender];
    }
}