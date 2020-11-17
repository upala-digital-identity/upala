pragma solidity ^0.6.0;

import "../groups/upala-group.sol";
import "../mockups/moloch-mock.sol";
import "../groups/merkle-drop.sol";

contract GitcoinGroup is UpalaGroup, usingMerkleDrop {

    Moloch moloch;

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

    function molochIncreaseTrust(uint160 identityID, uint8 trust) external {
        // check membership
        upala.increaseTrust(identityID, trust);
    }
    
    // any moloch-based group will work 
    function _isMolochMember(address candidate) private view returns (bool) {
        // (address delegateKey, uint256 shares, bool exists) = Moloch(molochAddress).members(candidate);
        // require(delegateKey == candidate, "Candidate is not a member or delegate");
        // require(shares > 0, "Candidate has 0 shares");
        return true;
    }

    function join(uint160 identityID) external {
        require(_isMolochMember(msg.sender), "msg.sender is not a member");
        // TODO _isIdentityHolder require()
        //_announceAndSetBotnetLimit(identityID, defaultLimit);
    }
}
