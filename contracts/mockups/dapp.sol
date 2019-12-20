pragma solidity ^0.5.0;

import "../incentives/group-example.sol";

contract DApp {
    
    ScoreProvider scoreProviderContract;
    
    constructor (address _userScoreProvider) public {
        scoreProviderContract = ScoreProvider(_userScoreProvider);
    }
    
    function voteWeight(address[] calldata _path) external returns (uint8) {
        return scoreProviderContract.getUserScore(msg.sender, _path);  // payable
    }
    
    function userFriendly() external returns (uint8) {
        return scoreProviderContract.getUserScoreCached(msg.sender);
    }
}


// 
contract DAppAsAGroup is UpalaGroup {
    function voteWeight(address[] calldata _path) external view returns (uint8) {
        return calculateScore(msg.sender, _path);  // payable
    }
}