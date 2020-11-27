pragma solidity ^0.6.0;

import "../base-groups/upala-group.sol";
import "../base-groups/ignoring-attack-window.sol";
import "../base-groups/free-provider.sol";

contract ProtoGroup is UpalaGroup, IgnoringAttackWindow { // is ScoreProvider, FreeProvider

    uint8 defaultTrust = 100;  // one million dollars [*places little finger near mouth*]

    constructor(
        address upalaProtocolAddress,
        address poolFactory
    )
        public
    {
        createGroup(upalaProtocolAddress, poolFactory);
    }

    // User joins
    function join(uint160 identityID) external virtual {
        announceAndSetTrust(identityID, defaultTrust);
    }
}
