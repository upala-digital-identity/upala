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
    bool public isUpalaGroup = true;

    uint160 public groupID;
    address groupPool;

    /* {"name": "ProtoGroup",
    "version": "0.1",
    "description": "Autoassigns FakeDAI score to anyone who joins",
    "join-terms": "No deposit required (ignore the ammount you see and join)",
    "leave-terms": "No deposit - no refund"} */
    string public details;  // json with ^details^

    constructor(
        address upalaProtocolAddress,
        address poolFactory
    )
        public
    {
        upala = Upala(upalaProtocolAddress);
        (groupID, groupPool) = upala.newGroup(address(this), poolFactory);
    }

    
    function setDetails(string calldata newDetails) external {
        details = newDetails;
    }
    
    function getGroupDetails() external view returns (string memory){
        return details;
    }

    /******
    SCORING
    /*****/

    // Prototype functions (bot attack window is 0 - group owners can frontrun bot attack)

    function _announceAndSetBotReward(uint botReward) internal {
        _announceBotReward(botReward);
        _setBotReward(botReward);
    }

    function _announceAndSetBotnetLimit(uint160 identityID, uint256 newBotnetLimit) internal {
        _announceBotnetLimit(identityID, newBotnetLimit);
        _setBotnetLimit(identityID, newBotnetLimit);
    }

    // Interface to Upala functions

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

    function _getScoreByPath(address wallet, uint160[] memory path) internal view returns (uint256) {
        return upala.memberScore(wallet, path);
    }

    function _getIdentityHolder(uint160 memberID) internal view returns (address) {
        return upala.getIdentityHolder(memberID);
    }
}
