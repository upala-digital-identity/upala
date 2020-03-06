pragma solidity ^0.5.0;

import "../incentives/group-example.sol";

contract UBIExampleDApp {
    
    ScoreProvider scoreProviderContract;  // e.g. BladerunnerDAO
    UBITokenContract tokenContract;

    MINIMAL_SCORE = 1 * 10 ** 18;  // 1 DAI
    UBI = 1 * 10 ** 18;  // 1 DAI

    mapping (address => bool) claimed;
    
    constructor (address _userScoreProvider) public {
        scoreProviderContract = ScoreProvider(_userScoreProvider);
    }

    function claimUBI(address[] calldata _path) external {
        require (claimed[_path[0]] == false);
        address wallet = msg.sender;
        if (scoreProviderContract.memberScore(_path, wallet) >= MINIMAL_SCORE) {
            require(tokenContract.transfer(wallet, UBI));
        }
    }
}