contract GroupTypesRegister {
    function start(address) external returns (uint) {}
}

contract Group {
	// Honey pot
	uint pool;  // Eth pool of the group
	uint maxBotReward;  // 

	// Group and members types
	bool lowestLevel = false;  // false - members are groups, true - members are users
	byte8 groupType = "Hash-Of-Registered-GroupType";
	byte8[] allowedMemberTypes;  // list of allowed types hashes (not applicable for lowest level groups)

	// members and scores d
	// address[] members;
	mapping(address => uint8) membersScores;  // 0-100% Personhood; 0 - not a member?
	
	// 
	address admin;  // either a trusted user or a voting contract
	// sets entering condition including income pool (income) management, types of groups to be invited


	modifier onlyAdmin() {
		require (msg.sender == admin);  // todo
		_; 
	}

	function setNewAdmin(address newAdmin) external onlyAdmin {
		admin = newAdmin;
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

	
	// Bots
	//function attack(uint personhoodScore, bytes8 proofOfScore) {
	function attack(address[] _path) {
		// ... descend the path and do harm!!!
		calculateScore(msg.sender, _path);
		reward = maxBotReward * personhoodScore;
		msg.sender.send(reward);
	}

	// Apps
	function checkScore(address candidate, address[] _path) returns (uint8) {
		// ... descend the path and calc score!!!
		return (calculateScore(candidate, _path));

	}

	// RageQuit???
	function rageQuit() onlyMember {
		rageQuitTrigger();  // exit conditions defined for the group
	}
}