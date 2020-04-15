pragma solidity ^0.6.0;

import "../protocol/upala.sol";
import "./upala-score-provider.sol";
import "./base-prototype.sol";

contract ProtoGroup is UpalaScoreProvider, BasePrototype {

    constructor (
        address upalaProtocolAddress,
        address poolFactory
    ) UpalaScoreProvider (
        upalaProtocolAddress,
        poolFactory
    ) BasePrototype (
        "dfgdfg",
        242,
        234
    )
    public {
        upala = Upala(upalaProtocolAddress);
        (groupID, groupPool) = upala.newGroup(address(this), poolFactory);
    }


    function announceAndSetBotReward(uint botReward) external {
        _announceAndSetBotReward(botReward);
    }

    function announceAndSetBotnetLimit(uint160 identityID, uint256 newBotnetLimit) external {
        _announceAndSetBotnetLimit(identityID, newBotnetLimit);
    }

    function getScoreByManager(address manger) external view returns (address, uint256) {
        uint160[] memory path = new uint160[](2);
        path[0] = identityIDs[manger];
        path[1] = groupID;
        uint256 score = _getScoreByPath(path);
        address holder = _getIdentityHolder(path[0]);
        return (holder, score);
        // charge();
        //(uint160 identityID, uint256 score)
    }

    // User joins
    function join(uint160 identityID) external {
        identityIDs[msg.sender] = identityID;
        _announceAndSetBotnetLimit(identityID, defaultLimit);
    }
}
