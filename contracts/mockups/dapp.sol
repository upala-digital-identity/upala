pragma solidity ^0.6.0;

import "../protocol/upala.sol";
// import "../pools/i-pool.sol"; // production todo create IPool
import "../pools/signed-scores-pool.sol";

// Upala library for DApps (human library)
contract usingUpala {

    // Upala upala;
    mapping(address => bool) approvedProviders;


    event NewProviderStatus(address groupAddress, bool isApproved);
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
    onlyApprovedPools(pool)
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
    onlyApprovedPools(pool) 
    returns (uint256){
        // msg.sender is user
        return SignedScoresPool(pool)
            .userScore(msg.sender, uID, uID, score, bundle, proof);
    }

    /************
    MANAGE GROUPS
    *************/

    modifier onlyApprovedPools(address poolAddress) {
        require(approvedProviders[poolAddress] == true, 
            "Pool address is not approved");
        _;
    }

    // Manage trusted score providers
    // Events are fetched by graph
    function approveScoreProvider(address groupAddress, bool isApproved) internal {
        approvedProviders[groupAddress] = isApproved;
        NewProviderStatus(groupAddress, isApproved);
    }

    // register DApp in Upala to let graph collect events. 
    function register(address upalaAddress) internal {
        Upala(upalaAddress).registerDApp();
    }
}

contract UBIExampleDApp is usingUpala {  // gotHumans requiringHumans 

    uint256 UBI = 10 * 10 ** 18;  // 10 Tokens
    uint256 MIN_SCORE = 1 * 10 ** 18;  // 1 DAI
    
    mapping (address => bool) claimed;
    mapping (address => uint256) balances;

    constructor (uint256 ubi, uint256 minimalScore, address upalaAddress) public {
        register(upalaAddress);
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