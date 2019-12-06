contract TypesRegister {
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

	// members and scores
	// address[] members;
	mapping(address => uint8) membersScores;  // 0-100% Personhood; 0 - not a member?
	
	// 
	address admin;  // either a trusted user or a voting contract


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

	
	// Bots
	//function attack(uint personhoodScore, bytes8 proofOfScore) {
	function attack(attackPath[]) {
		// ... descend the path and do harm!!!
		reward = maxBotReward * personhoodScore;
		msg.sender.send(reward);
	}

	// Apps
	function checkScore(address candidate, uint personhoodScore, bytes8 proofOfScore) returns (bool) {
		/// !!!!!!!!!!!!!!!!! how ??? !!!!!!!!!!!!!!!!! 
		require (scoreIsCorrect(msg.sender, personhoodScore, proofOfScore));
		/// !!!!!!!!!!!!!!!!! how ??? !!!!!!!!!!!!!!!!! 

		return (scoreIsCorrect(candidate, personhoodScore, proofOfScore));

	}

	// RageQuit???
	function rageQuit() onlyMember {

	}
}