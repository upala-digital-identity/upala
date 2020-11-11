pragma solidity ^0.6.0;

import "./upala-group.sol";

contract IgnoringAttackWindow is UpalaGroup {
	
	// Prototype functions (bot attack window is 0 - group owners can frontrun bot attack)
    function announceAndSetBotReward(uint256 botReward) external {
        _commitHash(keccak256(abi.encodePacked("setBotReward", groupID, botReward)));
        _setBotReward(botReward);
    }

    function announceAndSetTrust(uint160 identityID, uint8 trust) public {
    	_commitHash(keccak256(abi.encodePacked("setTrust", groupID, identityID, trust)));
        _setTrust(identityID, trust);
    }

}
