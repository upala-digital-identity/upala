pragma solidity ^0.5.0;

/*/// WARNING

Icredibly dirty and raw code here. Just to show the concept.

/// WARNING */

interface IUpalaGroup {

	function getPoolSize() {}
	function getMaxBotReward() {}
	function isLocked() {}

	function getMemberScore(address member) {}

	function attack(address[] path) {}
	function rewardBot(address _botAddress, uint _user_score) {}
	function rageQuit() {}
}

contract UpalaGroup is IUpalaGroup {

	// Locks the contract if it fails to pay a bot
	// Cryptoeconimic constrain forcing contracts to maintain correct declaredPool size
	// Enables contracts to chose any token, but requires them to pay bot rewards in eth (or DAI)
	bool isLocked = false;   

	// Eth (or DAI?) pool of the group // Honey pot
	// The pool is "declared" because it can differ from the actual pool. 
	// It allows group specific tokens
	// If using locks, is this necessary at all?
	uint declaredPool;

	// The most important obligation of a group is to pay bot rewards.   
	uint maxBotReward;

	mapping(address => uint8) membersScores;  // 0-100% Personhood; 0 - not a member?

	// A member of a group is either a subgroup or a user.
	function getMemberScore(address _member) returns (uint8) {
		if (isLocked == false) {
			return (membersScores[_member]);
		} else {
			return 0;
		}
	}

	// Ascends the path in groups hierarchy and calculate user score
	function calculateUserScore(address _user, address[] _path) internal returns (uint8) {
		uint8 _user_score = 0;
		for (uint i=_path.length-1; i<=0; i--) {
			_user_score = _user_score*address[i].getMemberScore(_user);
        }
		return _user_score;
	}
	
	function rewardBot(address _botAddress, uint _user_score) onlySuper {  // HOW!? todo try from bottom
		_reward = maxBotReward * _user_score / 100;
		if (address(this).balance <  _reward) {
			isLocked = true;  // penalty for hurting bot rights! (the utmost prerogative!)
			// break
		}
		_botAddress.send(_reward);  // Eth used for simplicity. Will probably be changed to DAI
		declaredPool -= _reward;
	}

	function attack(address[] _path) onlyMember {
		uint8 _user_score = 0;
		uint _reward = 0;
		// Ascend the path and do harm!!!
		for (uint i=_path.length-1; i<=0; i--) {
			_user_score = _user_score*address[i].getMemberScore(_user);
			address[i].rewardBot(msg.sender, _user_score);
        }
	}

	// RageQuit???
	function rageQuit() onlyMember {
		rageQuitTrigger();  // exit conditions defined for the group
	}
}

contract ForProfitScoreProviderExample is UpalaGroup {
	
	function calculateUserScore (address user, ) external payable {
		// charge, return score 
	}
}

/*
contract Group is UpalaGroup, Ownable {
	
	// Group and members types
	byte8 groupType = "Hash-Of-Registered-GroupType"; // 0 - members are users
	byte8[] allowedMemberTypes;  // list of allowed types hashes (not applicable for lowest level groups)
	
    // owner is either a trusted user or a voting contract
	// sets entering condition including income pool (income) management, types of groups to be invited

	
	// Apps
	function calculateUserScore(address candidate, address[] _path) {  //payable optionally

	}

	function updateMemberScore(address member, uint8 newScore) onlyAdmin {
		// todo check member type
		require (newScore >= 0 && newScore <= 100);
		membersScores[member] = newScore;
	}

	// Pool
	function encreasePool() external payable {  //onlyAdmin? //or anyone?
		pool+= msg.value;
	}
}
*/
