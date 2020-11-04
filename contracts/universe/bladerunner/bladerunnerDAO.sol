pragma solidity ^0.6.0;

import "./proto-group.sol";

// Full BladerunnerDAO is in playground/mvp.
// Here is the prototype BladerunnerDAO - controlled by a single person
contract BladerunnerDAO is UpalaGroup, IgnoringAttackWindow, FreeProvider {

    bool public isBladerunner = true;

    constructor(
        address upalaProtocolAddress,
        address poolFactory
    )
        public
    {
        createGroup(upalaProtocolAddress, poolFactory);
    }
}
