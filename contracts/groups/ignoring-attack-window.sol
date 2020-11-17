pragma solidity ^0.6.0;

import "./upala-group.sol";

contract IgnoringAttackWindow is UpalaGroup {
	
	// Prototype functions (bot attack window is 0 - group owners can frontrun bot attack)
    function announceAndSetBotReward(uint256 botReward) external {
        upala.commitHash(keccak256(abi.encodePacked("setBotReward", groupID, botReward)));
        upala.setBotReward(botReward, "0x0");
    }

    function announceAndSetTrust(uint160 identityID, uint8 trust) public {
    	upala.commitHash(keccak256(abi.encodePacked("setTrust", groupID, identityID, trust)));
        upala.setTrust(identityID, trust, "0x0");
    }

}
