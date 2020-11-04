pragma solidity ^0.6.0;

import "../../groups/upala-group.sol";
import "../../groups/ignoring-attack-window.sol";
import "../../groups/free-provider.sol";

contract ProtoGroup is UpalaGroup, IgnoringAttackWindow, FreeProvider { // is ScoreProvider

    uint256 defaultLimit = 1000000 * 10 ** 18;  // one million dollars [*places little finger near mouth*]

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
        announceAndSetBotnetLimit(identityID, defaultLimit);
    }
}
