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
        address uID, 
        uint8 score, 
        bytes32 bundle,
        bytes memory proof)
    internal 
    returns (bool){
        return (
            userScore(pool, uID, score, bundle, proof) >= threshold);
    }

    // verifies and returns user score
    function userScore(
        address pool, 
        address uID, 
        uint8 score, 
        bytes32 bundle,
        bytes memory proof) 
    internal 
    returns (uint256){
        // msg.sender is user
        return SignedScoresPool(pool)
            .userScore(msg.sender, uID, score, bundle, proof);
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
    uint256 MIN_SCORE = 1 * 10 ** 18;  // 1 DAI
    
    mapping (address => bool) claimed;
    mapping (address => uint256) balances;

    constructor (uint256 ubi, uint256 minimalScore, address upalaAddress) public {
        UBI = ubi; // e.g. 10 * 10 ** 18;  // 10 Tokens
        MIN_SCORE = minimalScore; // e.g. 1 * 10 ** 18;  // 1 DAI
    }

    function claimUBI(
        address pool,
        uint256 threshold, 
        address uID, 
        uint8 score, 
        bytes32 bundle,
        bytes calldata proof) 
    external {
        require (
            claimed[uID] == false, 
            "Already claimed or not in the list");
        require(
            scoreIsAboveThreshold(MIN_SCORE, pool, uID, score, bundle, proof), 
            "Score is too low");

        _payOutUBI(uID, msg.sender);
    }

    function _payOutUBI(address uID, address recipient) private {
        balances[recipient] += UBI;
        claimed[uID] = true;
    }

    function myUBIBalance() external view returns (uint256) {
        return balances[msg.sender];
    }
}