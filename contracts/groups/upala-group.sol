pragma solidity ^0.6.0;

import "../protocol/upala.sol";

// Basic Upala Group
contract UpalaGroup {

    /********
    CONSTANTS
    /********/

    // address of the Upala protocol
    Upala upala;
    bool public isUpalaGroup = true;

    uint160 public groupID;
    address groupPool;

    string public details;  // json with ^details^ // or link/hash


    function createGroup(address upalaProtocolAddress, address poolFactory) internal {
        upala = Upala(upalaProtocolAddress);
        (groupID, groupPool) = upala.newGroup(address(this), poolFactory);
    }

    function connectGroup(address upalaProtocolAddress, uint160 groupID, address poolFactory) internal { 
    }

    function setDetails(string calldata newDetails) external {
        details = newDetails;
    }
    


    /******
    SCORING
    /*****/

    // credit app
    // temporarily removed for faster MVP (UIP-3)
    // function _increaseAppCredit(address appAddress, uint256 amount) internal {
    //     upala.increaseAppCredit(appAddress, amount);
    // }

    // function _decreaseAppCredit(address appAddress, uint256 amount) internal {
    //     upala.decreaseAppCredit(appAddress, amount);
    // }

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

    // function getMyScore(uint160[] memory path) internal returns (address, uint256) {
    // }
    function getGroupDetails() external view returns (string memory){
        return details;
    }

    function getUpalaGroupID() external view returns (uint160) {
        return groupID;
    }

    function getGroupPoolAddress() external view returns (address) {
        return groupPool;
    }

    function getPoolBalance() external view returns (uint256) {
    }

    // function _getScoreByPath(address wallet, uint160[] memory path) internal view returns (uint256) {
    //     return upala.memberScore(wallet, path);
    // }

    // function _getIdentityHolder(uint160 memberID) internal view returns (address) {
    //     return upala.getIdentityHolder(memberID);
    // }
}
