pragma solidity ^0.5.0;

/*/// WARNING

Icredibly dirty and raw code here. Just to show the concept.

/// WARNING */

interface IUpalaGroup {

	function getPoolSize() external view;
	function getMaxBotReward() external view;
	function isLocked() external view;

	function getMemberScore(address) external view returns (uint8);

	function attack(address[] calldata, address payable, uint8) external;
	function rageQuit() external;
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
	// uint declaredPool;

	// The most important obligation of a group is to pay bot rewards.   
	uint maxBotReward;

	mapping(address => uint8) membersScores;  // 0-100% Personhood; 0 - not a member?
    
    modifier onlyMember() {
        require(membersScores[msg.sender] > 0);
        _;
    }
	// A member of a group is either a subgroup or a user.
	function getMemberScore(address _member) external view returns (uint8) {
		if (isLocked == false) {
			return (membersScores[_member]);
		} else {
			return 0;
		}
	}

	// Ascends the path in groups hierarchy and calculate user score
	function calculateUserScore(address _user, address[] memory _path) internal returns (uint8) {
		uint8 _user_score = 0;
		for (uint i=_path.length-1; i<=0; i--) {
			_user_score = _user_score * IUpalaGroup(_path[i]).getMemberScore(_user);
        }
		return _user_score;
	}
	
	// Bot explosion
	function rewardBot(address payable _botAddress, uint _user_score) internal { 
		uint _reward = maxBotReward * _user_score / 100;
		if (address(this).balance <  _reward) {
			isLocked = true;  // penalty for hurting bot rights! (the utmost prerogative!)
			// break
		}
		_botAddress.send(_reward);  // Eth used for simplicity. Will probably be changed to DAI
	}

	// bottom-up recursive attack
	function attack(address[] calldata _path, address payable _bot, uint8 _score) external onlyMember {
	 	address nextGroup = _path[_path.length-1];
	 	IUpalaGroup nextUpalaGroup = IUpalaGroup(_path[_path.length-1]);
	 	address[] memory _newPath = _path;
	 	delete _newPath[_path.length-1]; // pop is not available todo
		uint8 _user_score = _score * membersScores[msg.sender];
		rewardBot(_bot, _user_score);
		nextUpalaGroup.attack(_newPath, _bot, _user_score);
	}

	// RageQuit???
	function rageQuit() external onlyMember {
		// rageQuitTrigger();  // exit conditions defined for the group
	}
}

// contract ForProfitScoreProviderExample is UpalaGroup {
	
	// function calculateUserScore (address user, ) external payable {
		// charge, return score 
	// }
// }


// In order to be destroyable there must be a user entity or a ledger of users. 
contract User {
	function attack (address[] calldata _path) external {
		// address _target = address[0];
		// _target.attack(_path);
	}
}
