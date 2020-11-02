pragma solidity ^0.6.0;

import "../protocol/upala.sol";
import "./upala-group.sol";

contract ProtoGroup is UpalaGroup {

    uint256 defaultLimit = 1000000 * 10 ** 18;  // one million dollars [*places little finger near mouth*]

    constructor (
        address upalaProtocolAddress,
        address poolFactory
    ) UpalaGroup (
        upalaProtocolAddress,
        poolFactory
    )
    public {
    }

    // Prototype functions (bot attack window is 0 - group owners can frontrun bot attack)

    function announceAndSetBotReward(uint botReward) external {
        _announceBotReward(botReward);
        _setBotReward(botReward);
    }

    function announceAndSetBotnetLimit(uint160 identityID, uint256 newBotnetLimit) public {
        _announceBotnetLimit(identityID, newBotnetLimit);
        _setBotnetLimit(identityID, newBotnetLimit);
    }

    // this group proves scores for free. Anyone can add any dapp to get free scores
    function freeAppCredit(address appAddress) external {
        _increaseAppCredit(appAddress, 1000);
    }

    // User joins
    function join(uint160 identityID) external virtual {
        announceAndSetBotnetLimit(identityID, defaultLimit);
    }
}
