pragma solidity ^0.6.0;

import "./upala-group.sol";

contract IgnoringAttackWindow is UpalaGroup {
	
	// Prototype functions (bot attack window is 0 - group owners can frontrun bot attack)
    function announceAndSetBotReward(uint botReward) external {
        _announceBotReward(botReward);
        _setBotReward(botReward);
    }

    function announceAndSetBotnetLimit(uint160 identityID, uint256 newBotnetLimit) public {
        _announceBotnetLimit(identityID, newBotnetLimit);
        _setBotnetLimit(identityID, newBotnetLimit);
    }

}
