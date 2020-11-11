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

    // Interface to Upala functions

    function _commitHash(bytes32 hash) internal {
        upala.commitHash(hash);
    }

    function _setBotReward(uint botReward) internal {
        upala.setBotReward(botReward, "0x0");
    }

    function _setTrust(uint160 identityID, uint8 trust) internal {
        upala.setTrust(identityID, trust, "0x0");
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

}
