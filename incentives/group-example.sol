pragma solidity ^0.5.0;

interface IUpalaGroup {

// function getPoolSize()
// function getMaxBotReward()
// function getMemberScore(address member) 

// function attack(address[] _path)
// function rageQuit()

}

contract UpalaGroup is IUpalaGroup {

    // Honey pot
	uint pool;  // Eth pool of the group
	uint maxBotReward;  // 

	// members and scores
	mapping(address => uint8) membersScores;  // 0-100% Personhood; 0 - not a member?

	function getMemberScore(address member) returns (uint8) {
		// ... descend the path and calc score!!!
		return (membersScores[member]);

	}

	// Bots
	//function attack(uint personhoodScore, bytes8 proofOfScore) {
	// ... descend the path and do harm!!!
	function attack(address[] _path) {
		calculateScore(msg.sender, _path);
		reward = maxBotReward * personhoodScore;
		msg.sender.send(reward);
		// refund by subgroups - pull rewards. 
	}

	// RageQuit???
	function rageQuit() onlyMember {
		rageQuitTrigger();  // exit conditions defined for the group
	}
}



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