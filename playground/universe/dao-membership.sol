pragma solidity ^0.6.0;

import "./base-groups/upala-group.sol";
import "../mockups/moloch-mock.sol";

// This Upala group auto-assigns scores to members of existing moloch-based DAOs.
// Every moloch has its own weight defined by the group admin (individual or DAO)
// For now, weight equal to the score (trust) that a user can get from this moloch
// No summing up. User score IS the maximum weight among molochs they are a member of.
contract MolochGroup is UpalaGroup { 

    mapping (address => mapping(address => bool)) claimed;  // a member can only claim once
    mapping (address => uint8) molochWeights;

    // contract constructor
    function initialize (address upalaProtocolAddress, address poolFactory) external {
        createGroup(upalaProtocolAddress, poolFactory);
    }

    // moloch delegate key or member address may be different from
    // Upala ID holder address, so let moloch member assign score to any 
    // existing Upala ID, but only once
    // Molochs have different weights
    function molochIncreaseScore(uint160 identityID, address payable moloch) external {
        // check membership
        uint8 molWeight = molochWeights[moloch];
        require (molWeight > 0, "Moloch address is not approved by the group");
        address molMember = Moloch(moloch).memberAddressByDelegateKey(msg.sender);
        require (claimed[moloch][molMember] == false, "Member has already claimed the score");
        (address delegateKey, uint256 shares, bool exists) = Moloch(moloch).members(molMember);
        require(shares > 0, "Candidate has 0 shares");

        // increase score
        // upala.increaseTrust(identityID, molochWeights[moloch]);
        claimed[moloch][molMember] == true;
    }

    /***************
    GROUP MANAGEMENT
    ****************/

    function setMolochWeight(address moloch, uint8 newWeight) onlyOwner external {
        molochWeights[moloch] = newWeight;
    }

    /******
    GETTERS
    *******/

    // function checkForExplosion () returns(bool res) {
        
    // }
    
}
