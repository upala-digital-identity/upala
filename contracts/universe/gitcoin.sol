pragma solidity ^0.6.0;

import "../groups/upala-group.sol";
import "../mockups/moloch-mock.sol";
import "../groups/merkle-drop.sol";

// a score aggregator group
// retrieves scores from multiple sources and calculates own score
contract GitcoinGroup is UpalaGroup, usingMerkleDrop {
    // methods are Upala groups with their own entry conditions
    // e.g. a group based on DAO membership or POAP token
    mapping (uint160 => uint8) methodWeight;
    mapping (uint160 => mapping(uint160 => uint8)) userScoreByMethod;
    uint160[] approvedMethods;
    uint160 MERKLE_GROUP = 0;  // special value to represent user score from merkle drop
    // housekeeping
    uint256 ERROR_VALUE = 99999999999999;  // a special error return value

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
        userScoreByMethod[MERKLE_GROUP][identityID] = score;
        pushScores(identityID);
    }

    // ON-Chain scores
    // combine scores from multiple on-chain sources
    function fetchScores(uint160 identityID) internal {
        for (uint i = 0; i<=approvedMethods.length-1; i++) {
            fetchScore(identityID, approvedMethods[i]);
            }
        pushScores(identityID); 
    }

    // fetch user score from single Upala group
    // notice. the score here is not in DAI. 
    function fetchScore(uint160 identityID, uint160 groupID) public returns (uint256) {
        address holder = msg.sender;
        uint160[] memory path;
        path[0] = identityID;
        path[1] = groupID;
        // this group acts as DApp to retrieve other group's score
        uint8 userScore = uint8(upala.userScore(holder, path) / upala.getBotReward(groupID));
        userScoreByMethod[groupID][identityID] = userScore;
        return userScore;
    }

    // combine and push scores
    function pushScores(uint160 identityID) public {
        uint8 totalScore = userScoreByMethod[MERKLE_GROUP][identityID];
        for (uint i = 0; i<=approvedMethods.length-1; i++) {
            totalScore += userScoreByMethod[approvedMethods[i]][identityID] * methodWeight[approvedMethods[i]] / 100;
        }
        upala.increaseTrust(identityID, totalScore);
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
