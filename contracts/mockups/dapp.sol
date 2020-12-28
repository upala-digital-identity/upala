pragma solidity ^0.6.0;

// import "../universe/i-score-provider.sol";
import "../protocol/upala.sol";
// ../universe/proto-group.sol

// Upala library for DApps (human library)
contract usingUpala {

    mapping (uint160 => bool) trustedScoreProviders;
    mapping (uint160 => address) scoreProviderAddresses;

    // IScoreProvider scoreProviderContract;  // e.g. BladerunnerDAO
    Upala upala;
    /*****
    SCORES
    ******/

    // this function does not verify whether Id really belogs to msg.sender
    function getUncofirmedUserIdentity(uint160[] memory path) internal pure returns (uint160){
        return path[0];
    }

    function scoreIsAboveThreshold(address wallet, uint160[] memory path, uint256 threshold) internal returns (bool) {
        return (getScoreByPath(wallet, path) >= threshold);
    }

    // this func does verify identity holder
    
    function getScoreByPath(address wallet, uint160[] memory path) internal returns (uint256){
        require (trustedScoreProviders[path[path.length-1]] == true, "score provider is not proved");
        // return upala.userScore(wallet, path);
        return 42; // moving to Merkle (deprecating)
    }


    /*****
    MANAGE
    ******/

    function setUpalaAddress(address upalaAddress) internal {
        upala = Upala(upalaAddress);
    }

    // Manage trusted score providers
    // no need to check if scoreProviderAddresses is the group manager.
    // Upala protocol will not let non-managers to get the score.
    // path[path.length-1] = groupID, 
    // scoreProviderAddress is groupID manager - ensured by the protocol
    function approveScoreProvider(uint160 providerUpalaID) internal {
        trustedScoreProviders[providerUpalaID] = true;
    }
    function removeScoreProvider(uint160 providerUpalaID) internal {
        delete trustedScoreProviders[providerUpalaID];
    }
}

contract UBIExampleDApp is usingUpala {

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