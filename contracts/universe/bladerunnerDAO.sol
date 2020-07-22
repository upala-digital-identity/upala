pragma solidity ^0.6.0;

import "./proto-group.sol";

// Full BladerunnerDAO is in playground/mvp.
// Here is the prototype BladerunnerDAO - controlled by a single person
contract BladerunnerDAO is ProtoGroup {

    bool public isBladerunner = true;

    constructor (
        address upalaProtocolAddress,
        address poolFactory
    ) ProtoGroup (
        upalaProtocolAddress,
        poolFactory
    )
    public {
    }

    // Users cannot join Bladerunner directly
    function join(uint160 identityID) external override(ProtoGroup) {
        require(false);
    }
}