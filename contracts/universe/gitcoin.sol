pragma solidity ^0.6.0;

import "../groups/upala-group.sol";
import "../mockups/moloch-mock.sol";
import "../groups/merkle-drop.sol";

contract GitcoinGroup is UpalaGroup, usingMerkleDrop {

    Moloch moloch;
    mapping (address => bool) approvedMolochs;
    mapping (address => mapping(address => bool)) claimed;
    uint8 defaultScore = 1;

    function initialize (address upalaProtocolAddress, address poolFactory) external {
        createGroup(upalaProtocolAddress, poolFactory);
    }

    // anyone can increase an ID's score with a merkele proof
    // to decrease score group admin needs 
    // to make a commitment and wait for the attack window to pass (see UpalaGroup contract)
    function merkleIncreaseTrust(uint160 identityID, uint8 trust, bytes32[] calldata proof) external {
        require(verifyEntitled(identityID, trust, proof), "The proof could not be verified.");
        upala.increaseTrust(identityID, trust);
    }

    // moloch delegate key or member address may be different from
    // Upala ID holder address, so let moloch member assign score to any 
    // existing Upala ID, but only once
    // Molochs have different weights
    function molochIncreaseTrust(uint160 identityID, address payable moloch) external {
        // check membership
        require (approvedMolochs[moloch] == true, "Moloch address is not approved by the group");
        address molMember = Moloch(moloch).memberAddressByDelegateKey(msg.sender);
        require (claimed[moloch][molMember] == false, "Member has already claimed the score");
        (address delegateKey, uint256 shares, bool exists) = Moloch(moloch).members(molMember);
        require(shares > 0, "Candidate has 0 shares");

        // increase trust
        upala.increaseTrust(identityID, defaultScore);
        claimed[moloch][molMember] == true;
    }

    /***************
    GROUP MANAGEMENT
    ****************/

    function setApprovedMoloch(address moloch, bool isApproved) onlyOwner external {
        approvedMolochs[moloch] = isApproved;
    }
    
    function setMolochWeights() onlyOwner external {
        
    }
}
