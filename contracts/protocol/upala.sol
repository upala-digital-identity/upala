pragma solidity ^0.8.2;

// import "./i-upala.sol"; // todo finalize interface
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../pools/i-pool-factory.sol";
import "../pools/i-pool.sol";

// The Upala ledger (protocol)
contract Upala is Initializable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    using SafeMathUpgradeable for uint256;

    /*******
    SETTINGS
    ********/

    // funds
    uint8 explosionFeePercent;
    address treasury;

    // any changes that hurt bots rights must be announced an hour in advance
    uint256 attackWindow; 
    // changes must be executed within execution window
    uint256 executionWindow; // 1000 - for tests
    
    /****
    USERS
    *****/

    // Identity owner. Can change owner, can assign delegates
    mapping(address => address) identityOwner; // idOwner
    // Addresses that can use the associated id (delegates and oner).
    // Also used to retrieve id by address
    mapping(address => address) delegateToIdentity;
    // candidates are used in pairing delegates and UpalaID (UIP-23)
    mapping(address => address) candidateDelegateToIdentity;
    // assigned as identity holder after ID explosion
    address EXPLODED; 

    /****
    POOLS
    *****/

    // Pool Factories approved by Upala admin
    mapping(address => bool) approvedPoolFactories;
    // Pools created by approved pool factories
    mapping(address => address) poolParent;

    /****
    DAPPS
    *****/

    mapping(address => bool) registeredDapps;

    /*****
    EVENTS
    *****/

    // Identity management
    event NewIdentity(address upalaId, address owner);
    event NewCandidateDelegate(address upalaId, address delegate);
    event NewDelegate(address upalaId, address delegate);
    event DelegateDeleted(address upalaId, address delegate);
    event NewIdentityOwner(address upalaId, address oldOwner, address newOwner);
    event Exploded(address upalaId);

    // Keeps track of new pools in graph
    // helps define pool ABI by factory address
    event NewPool(address poolAddress, address poolManager, address factory);
    event NewPoolFactoryStatus(address poolFactory, bool isApproved);

    // Dapps
    event NewDAppStatus(address dappAddress, bool isRegistered);

    // Protocol settings
    event NewAttackWindow(uint256 newWindow);
    event NewExecutionWindow(uint256 newWindow);
    event NewExplosionFeePercent(uint8 newFee);
    event NewTreasury(address newTreasury);

    /**********
    CONSTRUCTOR
    ***********/

    function initialize () external initializer {
        // initializers
        __UUPSUpgradeable_init();
        __Ownable_init();
        __Pausable_init();
        // defaults
        explosionFeePercent = 3;
        treasury = owner();
        attackWindow = 30 minutes;
        executionWindow = 1 hours;
        // ASCII to Hex "exploded"
        EXPLODED = address(0x0000000000000000000000006578706c6f646564);
        // emit events for subgraph
        NewAttackWindow(attackWindow);
        NewExecutionWindow(executionWindow);
        NewExplosionFeePercent(explosionFeePercent);
        NewTreasury(treasury);
    }

    /****
    USERS
    *****/
    // REGISTRATION
    // Creates UpalaId
    // Upala ID can be assigned to an address by a third party
    function newIdentity(address newIdentityOwner) external whenNotPaused returns (address) {
        require (newIdentityOwner != address(0x0),
            "Cannot use an empty addess");
        require (delegateToIdentity[newIdentityOwner] == address(0x0), 
            "Address is already an owner or delegate");
        // UpalaIDs are n non-deterministic. Cannot assign scores to Upala ID
        // before Upala ID is created. 
        address newId = address(uint160(uint256(keccak256(abi.encodePacked(
            newIdentityOwner, block.timestamp))))); // UIP-22.
        identityOwner[newId] = newIdentityOwner;
        delegateToIdentity[newIdentityOwner] = newId;
        NewIdentity(newId, newIdentityOwner);
        return newId;
    }
    
    // can be called by any delegate address to get id (used for tests)
    function myId() external view returns(address) {
        return delegateToIdentity[msg.sender];
    }

    // can be called by any delegate address to get id owner (used for tests)
    function myIdOwner() external view returns(address owner) {
        return identityOwner[delegateToIdentity[msg.sender]];
    }

    function isExploded(address upalaId) external view returns(bool) {
        if (identityOwner[upalaId] == EXPLODED) {
            return true;
        } else {
            return false;
        }
    }

    modifier onlyIdOwner() {
        require (identityOwner[delegateToIdentity[msg.sender]] == msg.sender, 
            "Upala: Only identity owner can manage delegates and ownership");
        _;
    }

    // DELEGATION
    // UIP-23
    // must be called by an address receiving delegation prior to delegation
    // to cancel delegation request use 0x0 address as UpalaId
    function askDelegation(address upalaId) external whenNotPaused {
        require(delegateToIdentity[msg.sender] == address(0x0), 
            "Already a delegate");
        candidateDelegateToIdentity[msg.sender] = upalaId;
        NewCandidateDelegate(upalaId, msg.sender);
    }

    // Creates delegate for the UpalaId. // todo delegate hijack
    function approveDelegate(address delegate) external whenNotPaused onlyIdOwner {  // newDelegate // setDelegate
        require(delegate != address(0x0),
            "Cannot use an empty addess");
        require(delegate != msg.sender,
            "Cannot approve oneself as delegate");
        address upalaId = delegateToIdentity[msg.sender];
        require(candidateDelegateToIdentity[delegate] == upalaId,
            "Delegatee must confirm delegation first");
        delegateToIdentity[delegate] = upalaId;
        delete candidateDelegateToIdentity[delegate];
        NewDelegate(upalaId, delegate);
    }

    // Stop being a delegate (called by delegate)
    // Can be called afrer id explosion as well
    function dropDelegation() external whenNotPaused {
        _removeDelegate(delegateToIdentity[msg.sender], msg.sender);
    }

    // Removes delegate for the UpalaId (called by Upala id owner)
    function removeDelegate(address delegate) external whenNotPaused onlyIdOwner {
        _removeDelegate(delegateToIdentity[msg.sender], delegate);
    }

    function _removeDelegate(address upalaId, address delegate) internal {
        require(upalaId != address(0x0),
            "Upala: Must be an existing Upala ID");
        require(upalaId == delegateToIdentity[delegate],
            "Upala: Must be an existing delegate");
        address idOwner = identityOwner[upalaId];
        require(idOwner != delegate,
            "Upala: Cannot remove identity owner");
        delete delegateToIdentity[delegate];
        DelegateDeleted(upalaId, delegate);
    }
    
    // OWNERSHIP AND DELETION
    // Sets new UpalaId owner. Only allows to transfer ownership to an 
    // existing delegate (owner is a speial case of delegate)
    function setIdentityOwner(address newIdentityOwner) external whenNotPaused onlyIdOwner {
        address upalaId = delegateToIdentity[msg.sender];
        require (delegateToIdentity[newIdentityOwner] == upalaId, 
            "Upala: Address must be a delegate for the current UpalaId");
        identityOwner[upalaId] = newIdentityOwner;
        NewIdentityOwner(upalaId, msg.sender, newIdentityOwner);
    }
    
    // GDPR. To clear records, remove all delegatews and explode with 0 reward


    /****
    POOLS
    *****/

    // only pools created by approved factories 
    // (admin can swtich on and off all pools by a factory)
    modifier onlyApprovedPool() {
        // msg.sender is a pool address
        require(approvedPoolFactories[poolParent[msg.sender]] == true,
            "Upala: Parent pool factory is not approved");
        _;
    }

    modifier onlyApprovedPoolFactory() {
        require(approvedPoolFactories[msg.sender] == true, 
            "Upala: Pool factory is not approved");
        _;
    }

    // pool factories can register pools they generate
    function registerPool(address newPool, address poolManager) 
        external
        whenNotPaused
        onlyApprovedPoolFactory
        returns(bool) 
    {
        // msg.sender is an approved pool factory address
        poolParent[newPool] = msg.sender;
        emit NewPool(newPool, poolManager, msg.sender);
        return true;
    }

    // Admin can swtich on and off all pools by a factory 
    // (both creation of new pools and permissions of existing ones)
    function approvePoolFactory(address poolFactory, bool isApproved) 
        external 
        onlyOwner
    {
        approvedPoolFactories[poolFactory] = isApproved;
        NewPoolFactoryStatus(poolFactory, isApproved);
    }

    function isApprovedPoolFactory(address poolFactory) external view returns (bool) {
        return approvedPoolFactories[poolFactory];
    }

    // used by pools to check validity of address and upala id
    function isOwnerOrDelegate(address ownerOrDelegate, address identity) 
        external 
        view
        onlyApprovedPool
        returns (bool) 
    {
        require(identity == delegateToIdentity[ownerOrDelegate],
            "Upala: No such id, not an owner or not a delegate of the id");
        require (identityOwner[identity] != EXPLODED,
            "Upala: The id is already exploded");
        return true;
    }

    // explodes ID
    function explode(address identity) 
        external
        whenNotPaused
        onlyApprovedPool
        returns(bool)
    {
        delete delegateToIdentity[identityOwner[identity]];
        identityOwner[identity] = EXPLODED;
        Exploded(identity);
        return true;
    }

    /****
    DAPPS
    *****/
    // Needed for subgraph
    // Subgraph creates templates to monitor DApps
    // Tracks which pool the DApp approves of

    function registerDApp() external whenNotPaused {
        registeredDapps[msg.sender] = true;
        NewDAppStatus(msg.sender, true);
    }

    function unRegisterDApp() external whenNotPaused {
        require(registeredDapps[msg.sender] == true,
            "Upala: DApp is not registered");
        delete registeredDapps[msg.sender];
        NewDAppStatus(msg.sender, false);
    }

    /************************
    UPALA PROTOCOL MANAGEMENT
    *************************/

    // Note. When decreasing attackWindow or executionWindow make sure to let 
    // all group managers to know in advance as it affects commits life.
    function setAttackWindow(uint256 newWindow) onlyOwner external {
        attackWindow = newWindow;
        NewAttackWindow(newWindow);
    }

    function setExecutionWindow(uint256 newWindow) onlyOwner external {
        executionWindow = newWindow;
        NewExecutionWindow(newWindow);
    }

    function setExplosionFeePercent(uint8 newFee) onlyOwner external {
        explosionFeePercent = newFee;
        NewExplosionFeePercent(newFee);
    }

    function setTreasury(address newTreasury) onlyOwner external {
        // production todo make sure treasury is ERC-20 compatible
        treasury = newTreasury;
        NewTreasury(newTreasury);
    }

    function pause() onlyOwner external {
        _pause();
    }

    function unpause() onlyOwner external {
        _unpause();
    }

    /************
    UPGRADABILITY
    *************/
    //requirement of UUPSUpgradeable contract 
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /******
    GETTERS
    *******/

    function getAttackWindow() public view returns (uint256) {
        return attackWindow;
    }

    function getExecutionWindow() public view returns (uint256) {
        return executionWindow;
    }

    function getExplosionFeePercent() public view returns (uint8) {
        return explosionFeePercent;
    }

    function getTreasury() public view returns (address) {
        return treasury;
    }

    // /*******
    // PAYWALLS
    // ********/
    // // groups can append any paywall they chose to charge dapps.

    // modifier onlyApprovedPaywallFactory() {
    //     require(approvedPaywallFactories[msg.sender] == true, 
    //          "Paywall factory is not approved");
    //     _;
    // }

    // // paywall factories approve all paywall they generate
    // function approvePaywall(address newPaywall) 
    //     external 
    //     onlyApprovedPaywallFactory 
    //     returns(bool) 
    // {
    //     approvedPaywalls[newPaywall] = msg.sender;
    //     NewPaywall(newPaywall, msg.sender);
    //     return true;
    // }

    // // TODO only admin
    // Admin can swtich on and off all paywalls by a factory 
    // (both creation of new paywalls and approval of existing ones)
    // function setApprovedPaywallFactory(
    //     address paywallFactory, 
    //     bool isApproved
    // ) 
    //     external 
    // {
    //     approvedPaywallFactories[paywallFactory] = isApproved;
    // }

    // function isApprovedPaywall(paywall) external {
    //     return true;
    // }

}
