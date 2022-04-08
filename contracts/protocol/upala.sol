pragma solidity ^0.8.0;

// import "./i-upala.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../pools/i-pool-factory.sol";
import "../pools/i-pool.sol";
import "hardhat/console.sol";


// The Upala ledger (protocol)
contract Upala is OwnableUpgradeable{
    using SafeMath for uint256;

    /*******
    SETTINGS
    ********/

    // funds
    uint8 public explosionFeePercent;
    address public treasury;

    // any changes that hurt bots rights must be announced an hour in advance
    uint256 public attackWindow; 
    // changes must be executed within execution window
    uint256 public executionWindow; // 1000 - for tests
    
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
    mapping(address => bool) public approvedPoolFactories;
    // Pools created by approved pool factories
    mapping(address => address) public poolParent;

    /****
    DAPPS
    *****/

    mapping(address => bool) public registeredDapps;

    /*****
    EVENTS
    *****/

    // Identity management
    event NewIdentity(address upalaId, address owner);
    event NewDelegateStatus(address upalaId, address delegate, bool isApproved);
    event NewIdentityOwner(address upalaId, address owner);
    event Exploded(address upalaId);

    // used to register new pools in graph
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

    function initialize () external {
        // todo (is this a good production practice?) 
        // https://forum.openzeppelin.com/t/how-to-use-ownable-with-upgradeable-contract/3336/4
        // __Context_init_unchained();  // todo why it breaks? ask OZ
        // __Ownable_init_unchained();  // ... with this line 
        __Ownable_init();
        // defaults
        console.log("sdfsdf");
        explosionFeePercent = 3;
        treasury = owner();
        attackWindow = 30 minutes;
        executionWindow = 1 hours;
        // Hex to ASCII = exploded
        EXPLODED = address(0x0000000000000000000000006578706c6f646564);  
    }

    /****
    USERS
    *****/

    // Creates UpalaId
    // Upala ID can be assigned to an address by a third party
    function newIdentity(address newIdentityOwner) external returns (address) {
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

    modifier onlyIdOwner() {
        require (identityOwner[delegateToIdentity[msg.sender]] == msg.sender, 
            "Only identity holder can add or remove delegates");
        _;
    }

    // UIP-23
    // must be called by an address receiving delegation prior to delegation
    // to cancel use 0x0 address for UpalaId
    function approveDelegation(address upalaId) external {   // askDelegation
        require(delegateToIdentity[msg.sender] == address(0x0), 
            "Already a delegate");
        candidateDelegateToIdentity[msg.sender] = upalaId;
    }

    // Creates delegate for the UpalaId. // todo delegate hijack
    function approveDelegate(address delegate) external onlyIdOwner {  // newDelegate // setDelegate
        require (delegate != address(0x0),
            "Cannot use an empty addess");
        require (delegate != msg.sender,
            "Cannot approve oneself as delegate");
        address upalaId = delegateToIdentity[msg.sender];
        require(candidateDelegateToIdentity[delegate] == upalaId,
            "Delegatee must confirm delegation first");
        delegateToIdentity[delegate] = upalaId;
        delete candidateDelegateToIdentity[delegate];
        NewDelegateStatus(upalaId, delegate, true);
    }

    // Stop being a delegate (called by delegate)
    function stopDelegation() external {  // dropDelegation
        address upalaId = delegateToIdentity[msg.sender];
        require(upalaId != address(0x0),
            "Must be a delegate");  // what about exploded?
        address idOwner = identityOwner[upalaId];
        require(idOwner != msg.sender, 
            "Cannot remove identity owner");
        delete delegateToIdentity[msg.sender];
        NewDelegateStatus(upalaId, msg.sender, false);
    }

    // Removes delegate for the UpalaId. 
    function removeDelegate(address delegate) external onlyIdOwner {
        require(delegate != msg.sender, 
            "Cannot remove oneself");
        require(delegateToIdentity[msg.sender] == delegateToIdentity[delegate],
            "UpalaId must be same for delegate and id owner");
        delete delegateToIdentity[delegate];
        NewDelegateStatus(delegateToIdentity[msg.sender], delegate, false);
    }
    
    // Sets new UpalaId owner. Only allows to transfer ownership to an 
    // existing delegate (owner is a speial case of delegate)
    function setIdentityOwner(address newIdentityOwner) external onlyIdOwner {
        address upalaId = delegateToIdentity[msg.sender];
        require (delegateToIdentity[newIdentityOwner] == upalaId, 
            "Address is not a delegate for current UpalaId");
        identityOwner[upalaId] = newIdentityOwner;
        NewIdentityOwner(upalaId, newIdentityOwner);
    }
    
    // production todo may be required by regulators
    // just explode with 0 reward!
    // function removeIdentity(address name) external {
    // }

    // can be called by any delegate address to get id (used for tests)
    function myId() external view returns(address) {
        return delegateToIdentity[msg.sender];
    }

    // can be called by any delegate address to get id owner (used for tests)
    function myIdOwner() external view returns(address owner) {
        return identityOwner[delegateToIdentity[msg.sender]];
    }

    /****
    POOLS
    *****/

    // only pools created by approved factories 
    // (admin can swtich on and off all pools by a factory)
    modifier onlyApprovedPool() {
        // msg.sender is a pool address
        require(approvedPoolFactories[poolParent[msg.sender]] == true,
            "Parent pool factory is disapproved");
        _;
    }

    modifier onlyApprovedPoolFactory() {
        require(approvedPoolFactories[msg.sender] == true, 
            "Pool factory is not approved");
        _;
    }

    // pool factories can register pools they generate
    function registerPool(address newPool, address poolManager) 
        external 
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
        onlyApprovedPool 
        returns(bool)
    {
        identityOwner[identity] = EXPLODED;
        Exploded(identity);
        return true;
    }

    /****
    DAPPS
    *****/
    // Needed for subgraph
    // todo Probably there's a simpler way to do this 

    function registerDApp() external {
        registeredDapps[msg.sender] = true;
        NewDAppStatus(msg.sender, true);
    }

    function unRegisterDApp() external {
        require(registeredDapps[msg.sender] == true,
            "DApp is not registered");
        delete registeredDapps[msg.sender];
        NewDAppStatus(msg.sender, false);
    }

    /************************
    UPALA PROTOCOL MANAGEMENT
    *************************/

    // Note. When decreasing attackWindow or executionWindow make sure to let 
    // all group managers to know in advance as it affects commits life.
    function setAttackWindow(uint256 newWindow) onlyOwner external {
        console.log("setAttackWindow");  // production todo remove
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

    /******
    GETTERS
    *******/

    // getExecutionWindow() ?

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
