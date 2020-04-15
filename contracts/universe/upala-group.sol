pragma solidity ^0.6.0;

import "../protocol/upala.sol";

// Basic Upala Group
contract UpalaGroup {

    /********
    CONSTANTS
    /********/
    // address of the Upala protocol
    // now it works as a guildBank
    Upala upala;
    uint160 groupID;
    address groupPool;

    constructor(
        address upalaProtocolAddress,
        address poolFactory
    )
        public
    {
        upala = Upala(upalaProtocolAddress);
        (groupID, groupPool) = upala.newGroup(address(this), poolFactory);
    }

    /******
    SCORING
    /*****/

    function _announceAndSetBotReward(uint botReward) internal {
        _announceBotReward(botReward);
        _setBotReward(botReward);
    }

    function _announceAndSetBotnetLimit(uint160 identityID, uint256 newBotnetLimit) internal {
        _announceBotnetLimit(identityID, newBotnetLimit);
        _setBotnetLimit(identityID, newBotnetLimit);
    }

    function _announceBotReward(uint botReward) internal {
        upala.announceBotReward(groupID, botReward);
    }

    function _announceBotnetLimit(uint160 member, uint limit) internal {
        upala.announceBotnetLimit(groupID, member, limit);
    }

    function _setBotReward(uint botReward) internal {
        upala.setBotReward(groupID, botReward);
    }

    function _setBotnetLimit(uint160 identityID, uint256 newBotnetLimit) internal {
        upala.setBotnetLimit(groupID, identityID, newBotnetLimit);
    }


    /******
    GETTERS
    /*****/

    function getMyScore(uint160[] memory path) internal returns (address, uint256) {
    }

    function getUpalaGroupID() external view returns (uint160) {
        return groupID;
    }

    function getGroupPoolAddress() external view returns (address) {
        return groupPool;
    }

}
