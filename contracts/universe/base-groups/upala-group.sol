pragma solidity ^0.6.0;

import "../../protocol/upala.sol";
import "../../libraries/openzeppelin-contracts/contracts/access/Ownable.sol";

// Basic Upala Group
contract UpalaGroup is Ownable { 

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

    function connectGroup(address upalaProtocolAddress, uint160 groupID, address poolFactory) onlyOwner external { 
    }

    function setDetails(string calldata newDetails) onlyOwner external {
        details = newDetails;
    }
    


    /******
    SCORING
    /*****/

    // Interface to Upala functions

    function commitHash(bytes32 hash) onlyOwner external {
        upala.commitHash(hash);
    }

    function setBotReward(uint newBotReward) onlyOwner external {
        // upala.setBotReward(newBotReward, "0x0");
    }

    function setTrust(uint160 identityID, uint8 trust) onlyOwner external {
        // upala.setTrust(identityID, trust, "0x0");
    }

    function increaseReward(uint newBotReward) onlyOwner external {
        // upala.increaseReward(newBotReward);
    }

    function increaseTrust(uint160 member, uint8 newTrust) onlyOwner external {
        // upala.increaseTrust(member, newTrust);
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
