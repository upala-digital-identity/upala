pragma solidity ^0.5.0;

/*/// WARNING

Raw code here. Just to show the concept.

/// WARNING */

import "../oz/ownership/Ownable.sol";
import "../oz/token/ERC20/ERC20.sol";
import "../oz/math/SafeMath.sol";
// import "@openzeppelin/contracts/ownership/Ownable.sol";  // production

contract IUpalaGroup {

	// function getPoolSize() external view;
	function getMaxBotReward() external view returns (uint) ;
	function isLocked() external view returns (bool);

	function getMemberScore(address) external view returns (uint8);

	function attack(address[] calldata, address payable, uint) external;
	// function rageQuit() external;
}

contract UpalaGroup is IUpalaGroup, Ownable{
    using SafeMath for uint256;
    
    IERC20 public approvedToken;  // default = dai
	
	// Locks the contract if it fails to pay a bot
	// Cryptoeconimic constrain forcing contracts to maintain sufficient pool size
	// Enables contracts to use funds in any way if they are able to pay bot rewards
	bool locked = false;

	// The most important obligation of a group is to pay bot rewards.
	// Actual bot reward depends on user score
	uint maxBotReward;

	mapping(address => uint8) membersScores;  // 0-100% Personhood; 0 - not a member
    mapping(address => bool) acceptedInvitations;  // true for accepting membership in a superior group
    
    
    modifier onlyMember() {
        require(membersScores[msg.sender] > 0);
        _;
    }
    
    // attacks and contract changes go in turn
    // prevent front-runnig bot attack. Allows botnets to coordinate. 
    modifier botsTurn() {
        require(currentTimestampMinute() < 5);
        _;
    }
    
    modifier humansTurn() {
        require(currentTimestampMinute() >= 5);
        _;
    }
	
	constructor (address _approvedToken) public {
	    approvedToken = IERC20(_approvedToken);
	}
	
	/****
	ADMIN
	*****/
	
	// todo consider front-runnig bot attack
	function setMemberScore(address member, uint8 score) external humansTurn onlyOwner {
	    require(member != address(this));  // cannot be member of self. todo what about owner? 
	    membersScores[member] = score;
	}
	
	// todo try to get rid of it. Try another reward algorith
	// note Hey, with this function we can go down the path
	function acceptInvitation(address superiorGroup, bool isAccepted) external humansTurn onlyOwner {
	    require(superiorGroup != address(this));
	    acceptedInvitations[superiorGroup] = isAccepted;
	}
	
	// function addFunds
	// function setMaxBotReward

	/*******************
	SCORE AND BOT REWARD
	********************/
	
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
	function _rewardBot(address payable botAddress, uint user_score) internal { 
		uint reward = maxBotReward * user_score / 100;
		
		// contract must have sufficient funds to pay bot rewards for the next attack
		if (approvedToken.balanceOf(address(this)) < reward.add(maxBotReward)) {
			locked = true;  // penalty for hurting bot rights! (the utmost prerogative!)
		}
		require(approvedToken.transfer(botAddress, reward), "token transfer to bot failed");
	}

	// bottom-up recursive attack
	function attack(address[] calldata path, address payable bot, uint remainingReward) external onlyMember botsTurn {
	    // calculate maxBotReward and payout the sum starting from the bottom. Stop when the sum is payed.
	 	uint currentGroupReward = maxBotReward * membersScores[msg.sender];  // todo is this simplification correct?
	 	IUpalaGroup nextUpalaGroup = IUpalaGroup(path[path.length-1]);
	 	
	 	_rewardBot(bot, currentGroupReward);
		
		address[] memory newPath = path;
		nextUpalaGroup.attack(popFromMemoryArray_Hacked(newPath), bot, remainingReward - currentGroupReward);
	}

	
	/**************
	GETTER FUNCTIONS
	***************/
	
	// A member of a group is either a subgroup or a user.
	function getMemberScore(address member) external view returns (uint8) {
		if (locked == false) {
			return (membersScores[member]);
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

	function popFromMemoryArray_Hacked(address[] memory memoryArray) private pure returns (address[] memory) {
	 	address[] memory newMemoryArray = memoryArray;
	 	if (newMemoryArray.length != 0) {
	 	    assembly { mstore(newMemoryArray, sub(mload(newMemoryArray), 1)) }  // credits - https://ethereum.stackexchange.com/questions/51891/how-to-pop-from-decrease-the-length-of-a-memory-array-in-solidity?rq=1
	 	    return newMemoryArray;
	 	} else {
	 	    return newMemoryArray;
	 	}
	 	
	}
	
	function currentTimestampMinute () internal view returns (uint) {
        return now % 3600 / 60;
    }
    
    
}

// In order to be destroyable there must be a user entity or a ledger of users. 
// Here is the entity option. 
contract UpalaUser is UpalaGroup {
    
    bool exploded = false;
    
    // path
    function Explode (address[] calldata path) external {  // public for testing
        
        require (!exploded, "already exploded");
        
        uint rewardToClaim = IUpalaGroup(path[0]).getMaxBotReward() * calculateScore(msg.sender, path);
        IUpalaGroup(path[path.length-1]).attack(path, msg.sender, rewardToClaim);
        exploded = true;
    }
    
    // todo payable fallback?
}

/* todo consider:

- gas costs for calculation and for the attack (consider path length limitation)
- invitations. what if a very expensive group adds a cheap group. Many could decide to explode
- loops in social graphs. is nonReentrant enough?
- who is owner? it can set scores and it can be a member
- front-runnig a bot attack

*/

    /*****************
    EXAMPLES OF GROUPS (OUTDATED)
	*****************/
	
contract SimpleMembershipGroup is UpalaGroup {
    function addMember(address candidate, uint8 candidateScore) public {  // public for testing
        membersScores[candidate] = candidateScore;
    }
}

contract ScoreProvider is SimpleMembershipGroup {
    
    mapping(address => uint8) cachedUserScores;
    
	function getUserScore (address member, address[] calldata _path) external payable returns (uint8) {
		return calculateScore(member, _path);
	}
	function getUserScoreCached (address user) external payable returns (uint8) {
	    return cachedUserScores[user];
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




