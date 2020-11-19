pragma solidity ^0.6.0;

import "../groups/upala-group.sol";
import "../mockups/moloch-mock.sol";

// This Upala group auto-assigns scores to members of existing moloch based DAOs.
contract MolochGroup is UpalaGroup { 

    Moloch moloch;

    // uint256 defaultLimit = 1000000 * 10 ** 18;  // one million dollars [*places little finger near mouth*]

    constructor (
        address upalaProtocolAddress,
        address poolFactory,
        address payable molochAddress
    )
    public {
        createGroup(upalaProtocolAddress, poolFactory);
        moloch = Moloch(molochAddress);
    }

    function _isMember(address candidate) internal view returns (bool) {
        (address delegateKey, uint256 shares, bool exists) = moloch.members(candidate);
        require(delegateKey == candidate, "Candidate is not a member or delegate");
        require(shares > 0, "Candidate has 0 shares");
        return exists;
    }

    function join(uint160 identityID) external {
        require(_isMember(msg.sender), "msg.sender is not a member");
        // TODO _isIdentityHolder require()
        //_announceAndSetBotnetLimit(identityID, defaultLimit);
    }
}
