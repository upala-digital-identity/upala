pragma solidity ^0.6.0;

import "../groups/upala-group.sol";
import "../mockups/moloch-mock.sol";
import "../groups/merkle-drop.sol";

// a score aggregator group
// retrieves scores from multiple sources and calculates own score
contract GitcoinGroup is UpalaGroup, usingMerkleDrop {

    mapping (string => mapping(uint8 => uint8)) scoresByMethod;
    
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


    // array
    // function molochIncreaseScore(uint160 identityID, address payable moloch) returns(bool res) internal {
        
    // }
    

    // // combine scores from multiple sources
    // function increaseScore () returns(bool res) internal {
        
    // }
    


}
