pragma solidity ^0.6.0;

import "../groups/upala-group.sol";
import "../mockups/moloch-mock.sol";
import "../groups/merkle-drop.sol";

// a score aggregator group
// retrieves scores from multiple sources and calculates own score
contract GitcoinGroup is UpalaGroup, usingMerkleDrop {

    uint256 ERROR_VALUE = 99999999999999;
    // methods are Upala groups with their own entry conditions
    // e.g. group based on DAO membership or using Merkle drop
    mapping (uint160 => uint8) methodWeight;
    mapping (uint160 => mapping(uint8 => uint8)) userScoreByMethod;
    uint160[] approvedMethods;

    // contract constructor 
    function initialize (address upalaProtocolAddress, address poolFactory) external {
        createGroup(upalaProtocolAddress, poolFactory);
    }

    // OFF-Chain scores
    // anyone can increase an ID's score with a merkele proof
    // to decrease score group admin needs 
    // to make a commitment and wait for the attack window to pass (see UpalaGroup contract)
    function merkleIncreaseScore(uint160 identityID, uint8 score, bytes32[] calldata proof) external {
        require(verifyEntitled(identityID, score, proof), "The proof could not be verified.");
        upala.increaseTrust(identityID, score);
    }

    // ON-Chain scores
    // combine scores from multiple sources
    function fetchScores(uint160 identityID) internal {
        uint8 userScore = 0;
        uint160 groupID;
        for (uint i = 0; i<=approvedMethods.length-1; i++) {
            groupID = approvedMethods[i];
            // TODO overflow safety
            userScore += uint8(fetchScore(identityID, groupID) * methodWeight[groupID] / 100);
            }
        upala.increaseTrust(identityID, userScore);
    }
    
    function fetchScore(uint160 identityID, uint160 groupID) internal returns (uint256) {
        return 5;
    }

    /***************
    GROUP MANAGEMENT
    ****************/

    function addMethod(uint160 groupID, uint8 weight) external onlyOwner {
        uint256 index = _searchMethod(groupID);
        if (index != ERROR_VALUE) {
            approvedMethods.push(groupID);
        }
        methodWeight[groupID] = weight;
    }

    function removeMethod(uint160 groupID) external onlyOwner returns (uint160) {
        uint256 index = _searchMethod(groupID);
        if (index != ERROR_VALUE) {
            uint160 groupToRemove = approvedMethods[index];
            approvedMethods[index] = approvedMethods[approvedMethods.length - 1];
            delete approvedMethods[approvedMethods.length - 1];
            delete methodWeight[groupToRemove];
            return groupToRemove;
        }
    }

    function _searchMethod(uint160 groupID) private returns(uint256) {
        for (uint i = 0; i<=approvedMethods.length-1; i++) {
            if (approvedMethods[i] == groupID) {
                return i;
            }
        }
        return ERROR_VALUE;
    }
}
