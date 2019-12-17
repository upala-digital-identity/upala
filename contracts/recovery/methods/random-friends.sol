contract RandomFriend {

	address[] friends;
	uint8[] selectedVerifiers;
	uint8[] participatedVerifiers;

	uint8 defaultVerifiersSetLength = 5;
	uint8 defaultRoundLength = 5 days;
	uint8 roundExpirationTime;

	uint8 requiredNumOfVerifications;
	uint8 currentNumOfVerifications;

	bool started = false;
	bool isAgent = true;


	// SETUP
	modifier onlyUnlocked() { 
		require (started == false); 
		_; 
	}

	modifier onlyAuthorized() {
		require (SomeAccessControl.isAuthorized(msg.sender));  // todo
		_; 
	}

	function addFriend(address friendsAddress) onlyUnlocked onlyAuthorized {
		// todo check friends.length < 255
		friends[].push(friendsAddress);
		emit FriendAdded(friendsAddress);
	}

	function removeFriend(address friendsAddress) onlyUnlocked onlyAuthorized {
		friends[].pop(friendsAddress);
		emit FriendRemoved(friendsAddress);
	}

	function setupAgent(address recoveryManager, uint8 requiredNumOfVerifications) {
		recoveryManager = recoveryManager;  // todo
		requiredNumOfVerifications = requiredNumOfVerifications
	}

 	
	// APPROVALS

	modifier onlyVerifier() { 
		require (selectedVerifiers[].search(msg.sender) > 0);  // todo search function
		_; 
	}

	function approve() onlyVerifier {
		selectedVerifiers[].pop(msg.sender);
		participatedVerifiers[].push(msg.sender);
		currentNumOfVerifications++;
		if (currentNumOfVerifications == requiredNumOfVerifications) {
			agentConfirms();
		}
	}

	function reject() onlyVerifier {
		//... todo???
	}



	// CONTROL

	function addVerifier() {
		uint random_number = uint(block.blockhash(block.number-1))%10 + 1;
		friends[].pop(friendsAddress);
		selectedVerifiers[].push(friends[verifierIndex]);
	}

	function batchAddVerifiers(uint8 numOfVerifiers) {
		for(uint8 i = 0; i < numOfVerifiers; i++){
    		addVerifier();  // todo check numOfVerifiers < friends.length - selectedVerifiers.length
        }
        setRoundExpirationTime();
	}

	function setRoundExpirationTime()	{
		roundExpirationTime = now + defaultRoundLength;
	}

	// anyone can add more veriviers if it takes too long. 
	function addVerifiers() external {
		if (roundExpirationTime < now) {
			batchAddVerifiers(defaultVerifiersSetLength);
		}
	}
	

	// CONTROL
	
	modifier onlyRecoveryManager() { 
		require (SomeAccessControl.isRecoveryManagerContract(msg.sender));  //todo
		_;
	}

	function start() external onlyRecoveryManager {
 		started = true;
 		currentNumOfVerifications = 0;
 		selectedVerifiers.length = 0
		participatedVerifiers.length = 0;
		batchAddVerifiers(defaultVerifiersSetLength);
 	}

	function agentConfirms() internal {
		started = false;
		recoveryManager.approve();
	}
}