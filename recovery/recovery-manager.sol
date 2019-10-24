contract AgentInerface {
    function start(address) external returns (uint) {}
    function isAgent() public view returns (bool) {}
}

contract AccountRecovery { 
	// Allows an agent being plugged in to verify it is the right contract. 
    bool public isWallet = true;
    bool public isEnoughPossibleWeight = false;
    bool public isInitialized = false;

    address owner;
    address newOwnerCandidate;

    // Agents
    AgentInerface public initializer;

    struct Agent {
        uint8 weight;
        bool approved;
    }
    mapping(address => Agent) agents;
    address[] agentsRegistry;

    // Emitted when an agent is plugged in.
    event LogNewAgent(address newAddress, string moduleName);

	uint8 accumulatedWeight = 0;

    modifier onlyInitializer() {
        require(msg.sender == address(initializer));
        _;
    }

    modifier onlyApprover() {
        require(agents[msg.sender].weight > 0);
        _;
    }

    modifier legalWeight(uin8 weight) { 
    	require (weiht > 10 && weight < 34); 
    	_;
    }

    modifier onlyOnce(){
    	require(agents[msg.sender].approved == false);
        _;
    }

    modifier onlyInitialized(){
    	// todo 
    	_;
    }
    


    // @note When set up requires to add sufficient weight first, then remove an agent. 
    modifier checkPossibleWeight {
    	_;
    	if (isEnoughPossibleWeight == true)
    		require(sufficientPossibleWeight())
    	else
    		isEnoughPossibleWeight = sufficientPossibleWeight()
    	}

    function sufficientPossibleWeight() returns (bool) {
    	uint8 possibleWeight = 0;
    	for(uint i = 0; i < agentsRegistry.length; i++){
    		possibleWeight += agentsRegistry[i].weight;
        }
        if (possibleWeight >=100)
    		return true;
    	else
    		return false;
    }


    function registerInitializer(address initializerAddress, uint8 weight) 
	external 
	onlyOwner
	legalWeight(weight)
	checkPossibleWeight  // needed when switching to another initializer
	{
        AgentInerface candidateContract = AgentInerface(initializerAddress);
        require(candidateContract.isAgent());
        require(isInitialized == false);

        initializer = candidateContract;  // todo assigned before weight check - fix
        agentsRegistry[].push(initializerAddress);
        agents[initializerAddress].weight = weight;
        agents[initializerAddress].approved = false;

    	emit LogNewAgent(initializerAddress, "initializer");
	}

	function registerApprover(address approverAddress, uint8 weight) 
	external
	onlyOwner 
	checkPossibleWeight
	{	
        AgentInerface candidateContract = AgentInerface(approverAddress);
        require(candidateContract.isAgent());
        require(approverAddress != address(initializer));
        require(isInitialized == false);
        require(agents[address(initializer)].weight > 0);  // checks if initializer is set

        agentsRegistry[].push(approverAddress);
        agents[approverAddress].weight = weight;
        agents[approverAddress].approved = false;

        emit LogNewAgent(approverAddress, "approver");
    }




    // can reinitialize at any time
	function initializeRecovery(address newOwner) onlyInitializer {
		require(isEnoughPossibleWeight == true);

		resetApprovals();
	    accumulatedWeight = agents[msg.sender].weight;
	    agents[msg.sender].approved = true;
	    isInitialized = true;
	    newOwnerCandidate = newOwner;

	    // todo emit Is initialized 
	}

	function approve() onlyApprover onlyInitialized onlyOnce {
		agents[msg.sender].approved = true;
	    accumulatedWeight += agents[msg.sender].weight;
	    if (accumulatedWeight >= 100)
	    	recover();
	}

	// todo cannot remove weight <100 only replace

	function resetApprovals() {
		for(uint i = 0; i < agentsRegistry.length; i++){
    		agentsRegistry[i].approved = false;
        }
	}

	function reset() {
		isInitialized = false;
		resetApprovals();
		accumulatedWeight = 0;
	}

	function recover() {
		owner = newOwnerCandidate;
		reset();

		emit NewOwner(newOwnerCandidate);
		
		
	}

	// ....
}