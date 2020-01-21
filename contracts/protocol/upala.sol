pragma solidity ^0.5.0;

/*/// WARNING

The code is under heavy developement

/// WARNING */

import "../oz/token/ERC20/ERC20.sol";
import "../oz/math/SafeMath.sol";
// import "@openzeppelin/contracts/ownership/Ownable.sol";  // production


/*

The Upala contract is the protocol itself. 
Identity systems can use this contract to comply with universal bot explosion rules. 
These identity systems will then be compatible. 

Upala-native identity systems are presumed to consist of groups of many levels.
Each group is a smart contract with arbitary logic.

Another approach is to use commit-reveal scheme. The reveal will have to be made within a specified window.

*/

contract IUpala {

	function getMaxBotReward(address) external view returns (uint) ;
	function getPoolSize(address) external view returns (uint);
	function isLocked(address) external view returns (bool);

	function getMemberScore(address, address) external view returns (uint8);

	function attack(address[] calldata, address payable, uint) external;
	// function rageQuit() external;
	
	function addFunds(uint) external;
	function withdrawFromPool(uint) external;
}

/*
Bot attacks and contract changes by group dmins go in turn.
The timet prevents front-runnig bot attack, allows botnets to coordinate. 
The Upala timer is to be inherited by all Upala groups.
*/
contract UpalaTimer {

    modifier botsTurn() {
        require(currentTimestampMinute() < 5);
        _;
    }
    
    modifier humansTurn() {
        require(currentTimestampMinute() >= 5);
        _;
    }
    
    function currentTimestampMinute () internal view returns (uint) {
        return now % 3600 / 60;
    }
}

// The Upala ledger (protocol)
contract Upala is IUpala, UpalaTimer{
    using SafeMath for uint256;
    
    IERC20 public approvedToken;    // default = dai
    uint registrationFee = 1 wei;   // spam protection + susteinability
    uint maxPathLength = 10;        // the maximum depth of hierarchy - ensures attack gas cost is always lower than block maximum.
    
    // Groups
    // Groups are outside contracts with arbitary logic
	struct Group {
	    // Locks the contract if it fails to pay a bot
    	// Cryptoeconimic constrain forcing contracts to maintain sufficient pool size
    	// Enables contracts to use funds in any way if they are able to pay bot rewards
    	bool locked;
    	
    	// Ensures that a group can be registered only once
    	bool registered;
    	
    	// The most important obligation of a group is to pay bot rewards.
    	// A group can set its own maximum bot reward
    	// Actual bot reward depends on user score
    	uint maxBotReward;
        
        // A group sets scores to it's members
    	mapping(address => uint8) membersScores;  // 0-100% Personhood; 0 - not a member
        
        // A group may or may become a member of a superior group
        mapping(address => bool) acceptedInvitations;  // true for accepting membership in a superior group
	}
	mapping(address => Group) groups;
	
	// Users
	// Ensures that users and groups are different entities
	// Ensures that an exploded bot will never be able to get score or explode again
	struct User {
	    bool registered;
	    bool exploded;
	}
	mapping(address => User) users;
	
	// Accounting
	// A group's balance is its pool. Pools are deliberately vulnerable to bot attacks. 
	// A user balance is only used for a bot reward. 
	mapping(address => uint) balances;
    
    
    constructor (address _approvedToken) public {
	    approvedToken = IERC20(_approvedToken);
	}
	
	/************************
	REGISTER GROUPS AND USERS
	************************/
	// spam protection 
	// + self sustainability.
	// +separate Users from Groups
	
    modifier onlyGroups() {
        require(groups[msg.sender].registered == true);
        _;
    }
    
    modifier onlyUsers() {
        require(users[msg.sender].registered == true);
        _;
    }
	
	function registerNewGroup(address newGroup) external payable {
	    require(msg.value == registrationFee);
	    require(groups[newGroup].registered == false);
	    require(users[newGroup].registered == false);
	    groups[newGroup].registered == true;
	}
	
    function registerNewUser(address newUser) external payable {
	    require(msg.value == registrationFee);
	    require(groups[newUser].registered == false);
	    require(users[newUser].registered == false);
	    users[newUser].registered == true;
	}
	
	
	/**********
	GROUP ADMIN
	***********/
	
	/*
	Group admin - is any entity in control of a group. 
	A group may decide to chose a trusted person, or it may make decisions based on voting.
	*/
	
	// Sets the maximum possible bot reward for the group.
	function setMaxBotReward(uint maxBotReward) external humansTurn onlyGroups {
	    groups[msg.sender].maxBotReward = maxBotReward;
	}
	
	// Sets member scores
	function setMemberScore(address member, uint8 score) external humansTurn onlyGroups {
	    require(member != msg.sender);  // cannot be member of self. todo what about owner? 
	    require(score <= 100);
	    groups[msg.sender].membersScores[member] = score;
	}
	
	// todo try to get rid of it. Try another reward algorith
	// note Hey, with this function we can go down the path
	// + additional spam protection
	function acceptInvitation(address superiorGroup, bool isAccepted) external humansTurn onlyGroups {
	    require(superiorGroup != msg.sender);
	    groups[msg.sender].acceptedInvitations[superiorGroup] = isAccepted;
	}
	
	/********************
	GROUP Pool management
	********************/
	
	// Allows group admin to add funds to the group's pool
	function addFunds(uint amount) external humansTurn onlyGroups {
	    require(approvedToken.transferFrom(msg.sender, address(this), amount), "token transfer to pool failed");
	    balances[msg.sender].add(amount);
	}
	
	// Allows group admin to withdraw funds to the group's pool
	// todo what if a group withdraws just before the botsTurn and others cannot react? 
	// The protocol protects only bot rights. Let groups decide on their side. 
	function withdrawFromPool(uint amount) external humansTurn onlyGroups {
	    _withdraw(msg.sender, amount);
	}
	
	// Allows bot to withdraw it's reward after an attack
	function withdrawBotReward() external botsTurn onlyUsers  {
	    _withdraw(msg.sender, balances[msg.sender]);
	}
	
	function _withdraw(address recipient, uint amount) internal {
	    balances[recipient].sub(amount);
	    require(approvedToken.transfer(recipient, amount), "token transfer to bot failed");
	}
	
    
	/*******************
	SCORE AND BOT REWARD
	********************/
	/*

	The user score is different for every group. 
	The score is first calculated off-chain and then approved on-chain.
	To approve one needs to publish a "path" from the topmost group
	(the one for which the score is being approved) down to the user. 

	path is an array of addressess. The last address is the user. 
	*/


	// Descends the path in groups hierarchy and calculates user score
	// the topmost group must be msg.sender
	function calculateScore(address[] calldata path) external view onlyGroups returns (uint8, uint) {
	    require(path.length !=0, "path too short");
	    require(path.length <= maxPathLength, "path too long");
		
		// the topmost group is the msg.sender
		address group = msg.sender;
		address member = path[0];
		uint8  member_score = groups[group].membersScores[member];
		
		for (uint i=1; i<=path.length-1; i++) {
		    group = path[i-1];
		    member = path[i];
    		member_score *= groups[group].membersScores[member] / 100;
		}
		
		return (member_score, member_score * groups[msg.sender].maxBotReward);
	}   

	// Allows any user to attack any group, run with the money and self-destruct.
	// Only those with scores will succeed.
	// todo no nonReentrant?
	// @note experimental. the exact attack algorithm to be approved later
	function attack(address[] calldata path) external botsTurn {
	    
	    address bot = msg.sender;
	    require(users[bot].exploded == false, "bot already exploded");
	    
	    // calculate totalReward
	    uint[] memory botRewards;

	    // bot reward and user score in the closest group above the user (bot)
	    uint8 user_score = groups[path[path.length-1]].membersScores[bot];
	    uint totalMaxBotReward = user_score * groups[path[path.length-1]].maxBotReward;
	    botRewards[path.length-1] = totalMaxBotReward;

	    // todo protect bot rights - do not let explode for free.
	    
        // calculate all possible bot rewards
    	for (uint i=path.length-2; i<=0; i--) {
    		user_score *= groups[path[i]].membersScores[path[i+1]] / 100;
    		botRewards[i] = user_score * groups[path[i]].maxBotReward;
    		totalMaxBotReward += botRewards[i];
		}
		
		uint totalBotReward = botRewards[0];
		
		// payout proportionally
		uint reward;
		for (uint i=0; i<=path.length-1; i++){
		    reward = totalBotReward * totalMaxBotReward / botRewards[i];
		    
		    // transfer to user (bot)
		    balances[path[i]].sub(reward);
		    balances[bot].add(reward);
		    
    		// contract must have sufficient funds to pay bot rewards for the next attack
    		if (balances[path[i]] < groups[path[i]].maxBotReward) {
    			groups[path[i]].locked = true;  // penalty for hurting bot rights! (the utmost prerogative!)
    		}
		}
		users[bot].exploded = true;
	}

	
	/**************
	GETTER FUNCTIONS
	***************/
	
	// A member of a group is either a roup or a user.
	function getMemberScore(address group, address member) external view returns (uint8) {
		if (groups[group].locked == false) {
			return (groups[group].membersScores[member]);
		} else {
			return 0;
		}
	}
	
	function getMaxBotReward(address group) external view returns (uint) {
	    return groups[group].maxBotReward;
	}
	
	function getPoolSize(address group) external view returns (uint) {
	    return balances[group];
	}
	
	function isLocked(address group) external view returns (bool) {
	    return groups[group].locked;
	}

}

/*
Below is an example of group tool. A family of groups (an Upala friendly identity system)
may inherit the shared responsibility to introduce social responsibility.

Here member groups buy shares from a superior group. The superior group puts the income 
to it's pool in the Upala. When a bot attacks, it chopps off the pool and delutes shares value. 

So every member has to watch for other members not to allow bots.

Other group examples (identity systems) are in the ../universe directory
*/
contract SharedResponsibility is UpalaTimer {
    using SafeMath for uint256;

    
    IERC20 public approvedToken;
    IUpala public upala;
    
    mapping (address => uint) sharesBalances;
    uint totalShares;
    
    constructor (address _upala, address _approvedToken) public {
	    approvedToken = IERC20(_approvedToken);
	    upala = IUpala(_upala);
	    // todo add initial funds
	    // todo a bankrupt policy? what if balance is 0 or very close to 0, after a botnet attack.
	    // too much delution problem 
	}
	
	// share responisibiity by buying SHARES
	function buyPoolShares(uint payment) external {
	    uint poolSize = upala.getPoolSize(address(this));
	    uint shares = payment.mul(totalShares).div(poolSize);
	    
	    totalShares += shares;
	    sharesBalances[msg.sender] += shares;
	    
	    approvedToken.transferFrom(msg.sender, address(this), payment);
	    upala.addFunds(payment);
	}
	
    function withdrawPoolShares(uint sharesToWithdraw) external returns (bool) {
        
        require(sharesBalances[msg.sender] >= sharesToWithdraw);
        uint poolSize = upala.getPoolSize(address(this));
        uint amount = poolSize.mul(sharesToWithdraw).div(totalShares);
        
        sharesBalances[msg.sender].sub(sharesToWithdraw);
        totalShares.sub(sharesToWithdraw);
        
        upala.withdrawFromPool(amount);
        return approvedToken.transfer(msg.sender, amount);
    }
}

/* todo consider:

- gas costs for calculation and for the attack (consider path length limitation)
- invitations. what if a very expensive group adds a cheap group. Many could decide to explode
- loops in social graphs. is nonReentrant enough?
- who is the owner? it can set scores and it can be a member
- restirict pool size changes 
- transfer user ownership (minimal user contract)

done:
- front-runnig a bot attack

*/




