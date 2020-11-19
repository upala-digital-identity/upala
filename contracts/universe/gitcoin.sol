pragma solidity ^0.6.0;

import "../groups/upala-group.sol";
import "../mockups/moloch-mock.sol";
import "../groups/merkle-drop.sol";

// a score aggregator group
// retrieves scores from multiple sources and calculates own score
contract GitcoinGroup is UpalaGroup, usingMerkleDrop {

    Moloch moloch;
    mapping (address => bool) approvedMolochs;
    mapping (address => mapping(address => bool)) claimed;
    mapping (address => uint8) molochScores;

    mapping (address => mapping(uint8 => uint8)) scoresByMethod;
    
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
    // moloch delegate key or member address may be different from
    // Upala ID holder address, so let moloch member assign score to any 
    // existing Upala ID, but only once
    // Molochs have different weights
    function molochIncreaseScore(uint160 identityID, address payable moloch) external {
        // check membership
        require (approvedMolochs[moloch] == true, "Moloch address is not approved by the group");
        address molMember = Moloch(moloch).memberAddressByDelegateKey(msg.sender);
        require (claimed[moloch][molMember] == false, "Member has already claimed the score");
        (address delegateKey, uint256 shares, bool exists) = Moloch(moloch).members(molMember);
        require(shares > 0, "Candidate has 0 shares");

        // increase score
        upala.increaseTrust(identityID, molochScores[moloch]);
        claimed[moloch][molMember] == true;
    }

    // array
    // function molochIncreaseScore(uint160 identityID, address payable moloch) returns(bool res) internal {
        
    // }
    

    // // combine scores from multiple sources
    // function increaseScore () returns(bool res) internal {
        
    // }
    

    /***************
    GROUP MANAGEMENT
    ****************/

    function setApprovedMoloch(address moloch, bool isApproved) onlyOwner external {
        approvedMolochs[moloch] = isApproved;
    }
    
    function setMolochScore(address moloch, uint8 score) onlyOwner external {
        molochScores[moloch] = score;
    }
}
