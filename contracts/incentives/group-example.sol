pragma solidity ^0.5.0;

/*/// WARNING

Raw code here. Just to show the concept.

/// WARNING */

contract IUpalaGroup {

	// function getPoolSize() external view;
	function getMaxBotReward() external view returns (uint) ;
	function isLocked() external view returns (bool);

	function getMemberScore(address) external view returns (uint8);

	function attack(address[] calldata, address payable, uint) external;
	// function rageQuit() external;
}

contract UpalaGroup is IUpalaGroup{

	// Locks the contract if it fails to pay a bot
	// Cryptoeconimic constrain forcing contracts to maintain correct declaredPool size
	// Enables contracts to chose any token, but requires them to pay bot rewards in eth (or DAI)
	bool locked = false;

	// Eth (or DAI?) pool of the group // Honey pot
	// The pool is "declared" because it can differ from the actual pool. 
	// It allows group specific tokens
	// If using locks, is this necessary at all?
	// uint declaredPool;

	// The most important obligation of a group is to pay bot rewards.   
	uint maxBotReward;

	mapping(address => uint8) membersScores;  // 0-100% Personhood; 0 - not a member?
    // membersScores[this.address] = 0; todo. cannot be member of self
    
    modifier onlyMember() {
        require(msg.sender != address(this));
        require(membersScores[msg.sender] > 0);
        _;
    }
	

	// Ascends the path in groups hierarchy and calculates user score
	// User is represented by an Upala Group too
	function calculateScore(address _member, address[] memory _path) internal view returns (uint8) {
	    require(_path.length !=0, "path too short");
		uint8 _user_score = IUpalaGroup(_path[_path.length-1]).getMemberScore(_member);	
    	// _path[i] - group address
    	// _path[i+1] - member address
    	for (uint i=_path.length-2; i<=0; i--) {
    		_user_score = _user_score * IUpalaGroup(_path[i]).getMemberScore(_path[i+1]);
		}
		return _user_score;
	}
	
	// Bot explosion
	function rewardBot(address payable _botAddress, uint _user_score) internal { 
		uint _reward = maxBotReward * _user_score / 100;
		if (address(this).balance <  _reward) {
			locked = true;  // penalty for hurting bot rights! (the utmost prerogative!)
			// break
		}
		_botAddress.send(_reward);  // Eth used for simplicity. Will probably be changed to DAI
		// require(token.transfer(address(guildBank), _reward), "token transfer failed");
	}

	// bottom-up recursive attack
	function attack(address[] calldata _path, address payable _bot, uint _remainingReward) external onlyMember {
	    // calculate maxBotReward and payout the sum starting from the bottom. Stop when the sum is payed.
	 	uint _currentGroupReward = this.getMaxBotReward() * this.getMemberScore(msg.sender);  // todo is this simplification correct?
	 	IUpalaGroup nextUpalaGroup = IUpalaGroup(_path[_path.length-1]);
	 	
	 	rewardBot(_bot, _currentGroupReward);
		
		address[] memory _newPath = _path;
		nextUpalaGroup.attack(popFromMemoryArray_Hacked(_newPath), _bot, _remainingReward - _currentGroupReward);
	}

	
	/**************
	GETTER FUNCTIONS
	***************/
	
	// A member of a group is either a subgroup or a user.
	function getMemberScore(address _member) external view returns (uint8) {
		if (locked == false) {
			return (membersScores[_member]);
		} else {
			return 0;
		}
	}
	
	function getMaxBotReward() external view returns (uint) {
	    return maxBotReward;
	}
	function isLocked() external view returns (bool) {
	    return locked;
	}

	/****
    UTILS 
	*****/

	function popFromMemoryArray_Hacked(address[] memory _memoryArray) private pure returns (address[] memory) {
	 	address[] memory _newMemoryArray = _memoryArray;
	 	if (_newMemoryArray.length != 0) {
	 	    assembly { mstore(_newMemoryArray, sub(mload(_newMemoryArray), 1)) }  // credits - https://ethereum.stackexchange.com/questions/51891/how-to-pop-from-decrease-the-length-of-a-memory-array-in-solidity?rq=1
	 	    return _newMemoryArray;
	 	} else {
	 	    return _newMemoryArray;
	 	}
	 	
	}
}

// In order to be destroyable there must be a user entity or a ledger of users. 
// Here is the entity option. 
contract UpalaUser is UpalaGroup {
    
    bool exploded = false;
    
    // path
    function Explode (address[] calldata _path) external {  // public for testing
        
        require (!exploded, "already exploded");
        
        uint _rewardToClaim = IUpalaGroup(_path[0]).getMaxBotReward() * calculateScore(msg.sender, _path);
        IUpalaGroup(_path[_path.length-1]).attack(_path, msg.sender, _rewardToClaim);
        exploded = true;
    }
    
    // todo payable fallback?
}

    /*****************
    EXAMPLES OF GROUPS 
	*****************/
	
contract SimpleMembershipGroup is UpalaGroup {
    function addMember(address candidate, uint8 candidateScore) public {  // public for testing
        membersScores[candidate] = candidateScore;
    }
}

contract ScoreProvider is SimpleMembershipGroup {
	function getUserScore (address member, address[] calldata _path) external payable returns (uint8) {
		return calculateScore(member, _path);
	}
}

contract GroupOfGroups is SimpleMembershipGroup {

}

contract GroupOfUsers is SimpleMembershipGroup {

}




	// RageQuit???
	//function rageQuit() external onlyMember {
		// rageQuitTrigger();  // exit conditions defined for the group
	//}




