pragma solidity ^0.6.0;

import "../universe/i-score-provider.sol";
// ../universe/proto-group.sol

contract UBIExampleDApp {

    IScoreProvider scoreProviderContract;  // e.g. BladerunnerDAO

    uint256 MINIMAL_SCORE = 1 * 10 ** 18;  // 1 DAI
    uint256 UBI = 1000;  // 1 Token

    mapping (uint160 => bool) claimed;
    mapping (address => uint256) balances;

    constructor (address _userScoreProvider) public {
        scoreProviderContract = IScoreProvider(_userScoreProvider);
    }

    function claimUBI(uint160[] calldata path) external {
        address wallet = msg.sender;
        uint160 identityID = path[0];
        (address identityManager, uint256 score) = scoreProviderContract.getScoreByPath(path);

        require (claimed[identityID] == false, "Already claimed");
        require(identityManager == wallet, "msg.sender must be identity manager");
        require(score >= MINIMAL_SCORE, "Score is too low");

        _payOutUBI(identityID, wallet);
    }

    // scoreProviderContract stores cached
    function claimUBICachedPath() external {
        address wallet = msg.sender;
        (uint160 identityID, uint256 score) = scoreProviderContract.getScoreByManager(wallet);

        require (claimed[identityID] == false, "Already claimed");
        require(score >= MINIMAL_SCORE, "Score is too low");

        _payOutUBI(identityID, wallet);
    }

    function _payOutUBI(uint160 identityID, address recipient) private {
        balances[recipient] += UBI;
        claimed[identityID] = true;
    }

    function myUBIBalance() external returns (uint256) {
        return balances[msg.sender];
    }
}