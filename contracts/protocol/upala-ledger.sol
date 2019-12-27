pragma solidity ^0.5.0;

/*

Upala protocol as a ledger. 

*/

/*/// WARNING

The code is under heavy developement

/// WARNING */

import "../oz/token/ERC20/ERC20.sol";
import "../oz/math/SafeMath.sol";
import "../protocol/upala-group.sol";
// import "@openzeppelin/contracts/ownership/Ownable.sol";  // production

contract UpalaLedger is IUpalaGroup, UpalaTimer{
    using SafeMath for uint256;
    
    IERC20 public approvedToken;    // default = dai
    uint registrationFee = 1 wei;   // spam protection + susteinability
    uint maxPathLength = 10;        // the maximum depth of hierarchy - ensures attack gas cost is always lower than block maximum.
    // Groups
	struct Group {
	    // Locks the contract if it fails to pay a bot
    	// Cryptoeconimic constrain forcing contracts to maintain sufficient pool size
    	// Enables contracts to use funds in any way if they are able to pay bot rewards
    	bool locked;
    	bool registered;
    	
	    uint balance;
    	
    	// The most important obligation of a group is to pay bot rewards.
    	// Actual bot reward depends on user score
    	uint maxBotReward;
    
    	mapping(address => uint8) membersScores;  // 0-100% Personhood; 0 - not a member
        mapping(address => bool) acceptedInvitations;  // true for accepting membership in a superior group
	}
	mapping(address => Group) Groups;
	
	// Users
	struct User {
	    uint balance;
	    bool exploded;
	}
	mapping(address => User) Users;
    
    
    constructor (address _approvedToken) public {
	    approvedToken = IERC20(_approvedToken);
	}
	
    modifier onlyRegistered() {
        require(Groups[msg.sender].registered == true);
        _;
    }
	
	/**********
	GROUP ADMIN
	***********/
	
	// spam protection + self susteinability. Anyone can register a group
	function registerNewGroup(address newGroup) external payable {
	    require(msg.value == registrationFee);
	    require(Groups[newGroup].registered == false);
	    Groups[newGroup].registered == true;
	}
	
	// todo consider front-runnig bot attack
	function setMemberScore(address member, uint8 score) external humansTurn onlyRegistered {
	    require(member != msg.sender);  // cannot be member of self. todo what about owner? 
	    require(score <= 100);
	    Groups[msg.sender].membersScores[member] = score;
	}
	
	// todo try to get rid of it. Try another reward algorith
	// note Hey, with this function we can go down the path
	// + additional spam protection
	function acceptInvitation(address superiorGroup, bool isAccepted) external humansTurn onlyRegistered {
	    require(superiorGroup != msg.sender);
	    Groups[msg.sender].acceptedInvitations[superiorGroup] = isAccepted;
	}
	
	// Pool management
	
	// function addFunds
	// function setMaxBotReward
	// function approveGroup - let superior group spend current group funds. 

	/*******************
	SCORE AND BOT REWARD
	********************/
	
	// Descends the path in groups hierarchy and calculates user score
	// User is represented by an Upala Group too
	function calculateScore(address[] calldata path) external view onlyRegistered returns (uint8, uint) {
	    require(path.length !=0, "path too short");
	    require(path.length <= maxPathLength, "path too long");
		
		// the topmost group is the msg.sender
		address group = msg.sender;
		address member = path[0];
		uint8  member_score = Groups[group].membersScores[member] / 100;
		
		for (uint i=1; i<=path.length-1; i++) {
		    group = path[i-1];
		    member = path[i];
    		member_score *= Groups[group].membersScores[member] / 100;
		}
		
		return (member_score, member_score * Groups[msg.sender].maxBotReward);
	}   

	// experimental
	// Anyone can try to attack, but only those with scores will succeed
	// todo no nonReentrant
	function attack(address[] calldata path) external botsTurn {
	    
	    address bot = msg.sender;
	    require(Users[bot].exploded == false, "bot already exploded");
	    
	    // calculate totalReward
	    uint[] memory botRewards;

	    // bot reward and user score in the closest group above the user (bot)
	    uint8 user_score = Groups[path[path.length-1]].membersScores[bot];
	    uint totalMaxBotReward = user_score * Groups[path[path.length-1]].maxBotReward;
	    botRewards[path.length-1] = totalMaxBotReward;
	    
        // calculate all possible bot rewards
    	for (uint i=path.length-2; i<=0; i--) {
    		user_score *= Groups[path[i]].membersScores[path[i+1]] / 100;
    		botRewards[i] = user_score * Groups[path[i]].maxBotReward;
    		totalMaxBotReward += botRewards[i];
		}
		
		uint totalBotReward = botRewards[0];
		
		// payout proportionally
		uint reward;
		for (uint i=0; i<=path.length-1; i++){
		    reward = totalBotReward * totalMaxBotReward / botRewards[i];
		    
		    // transfer to user (bot)
		    Groups[path[i]].balance.sub(reward);
		    Users[bot].balance.add(reward);
		    
    		// contract must have sufficient funds to pay bot rewards for the next attack
    		if (Groups[path[i]].balance < Groups[path[i]].maxBotReward) {
    			Groups[path[i]].locked = true;  // penalty for hurting bot rights! (the utmost prerogative!)
    		}
		}
		Users[bot].exploded = true;
	}

	
	/**************
	GETTER FUNCTIONS
	***************/
	
	// A member of a group is either a subgroup or a user.
	function getMemberScore(address group, address member) external view returns (uint8) {
		if (Groups[group].locked == false) {
			return (Groups[group].membersScores[member]);
		} else {
			return 0;
		}
	}
	
	function getMaxBotReward(address group) external view returns (uint) {
	    return Groups[group].maxBotReward;
	}
	
	function getPoolSize(address group) external view returns (uint) {
	    return Groups[group].balance;
	}
	
	function isLocked(address group) external view returns (bool) {
	    return Groups[group].locked;
	}

}


/* todo consider:

- gas costs for calculation and for the attack (consider path length limitation)
- invitations. what if a very expensive group adds a cheap group. Many could decide to explode
- loops in social graphs. is nonReentrant enough?
- who is the owner? it can set scores and it can be a member
- restirict pool size changes 

done:
- front-runnig a bot attack

*/




