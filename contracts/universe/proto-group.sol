pragma solidity ^0.6.0;

import "../protocol/upala.sol";
import "./using-cached-paths.sol";
import "./upala-group.sol";

contract ProtoGroup is UpalaGroup, UsingCachedPaths {

    uint256 defaultLimit = 1000000 * 10 ** 18;  // one million dollars [*places little finger near mouth*]

    constructor (
        address upalaProtocolAddress,
        address poolFactory
    ) UpalaGroup (
        upalaProtocolAddress,
        poolFactory
    )
    public {
    }

    function announceAndSetBotReward(uint botReward) external {
        _announceAndSetBotReward(botReward);
    }

    function announceAndSetBotnetLimit(uint160 identityID, uint256 newBotnetLimit) external {
        _announceAndSetBotnetLimit(identityID, newBotnetLimit);
    }

    function getScoreByPath(address wallet, uint160[] calldata path) external view returns (uint256) {
        // charge();
        // (address identityManager, uint256 score)
        // uint160[] memory memPath = path;
        // return upala.memberScore(memPath);
        return _getScoreByPath(wallet, path);
    }

    // User joins
    function join(uint160 identityID) external virtual {
        identityIDs[msg.sender] = identityID;
        _announceAndSetBotnetLimit(identityID, defaultLimit);
    }
}
