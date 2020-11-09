pragma solidity ^0.6.0;

import "./upala-group.sol";

contract IgnoringAttackWindow is UpalaGroup {
	
	// Prototype functions (bot attack window is 0 - group owners can frontrun bot attack)
    function announceAndSetBotReward(uint256 botReward) external {
        _announceBotReward(botReward);
        _setBotReward(botReward);
    }

    function announceAndSetTrust(uint160 identityID, uint8 trust) public {
        _announceTrust(identityID, trust);
        _setTrust(identityID, trust);
    }

}
