pragma solidity ^0.6.0;

// import "./i-upala.sol";
import "../libraries/openzeppelin-contracts/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../pools/i-pool-factory.sol";
import "../pools/i-pool.sol";
import "hardhat/console.sol";


// The Upala ledger (protocol)
contract Upala is OwnableUpgradeable{
    using SafeMath for uint256;

    // assigned as identity holder after ID explosion
    address EXPLODED; 

    /*******
    SETTINGS
    ********/

    // any changes that hurt bots rights must be announced an hour in advance
    uint256 public attackWindow;  // 0 - for tests // TODO set to 1 hour at production
    // changes must be executed within execution window
    uint256 public executionWindow; // 1000 - for tests


    /*********
    IDENTITIES
    **********/

    // Identity owner. Can change owner, can assign delegates
    mapping(address => address) identityOwner; // idOwner
    // Addresses that can use the associated id (delegates and oner).
    // Also used to retrieve id by address
    mapping(address => address) delegateToIdentity;

    /****
    POOLS
    *****/

    // Pool Factories approved by Upala admin
    mapping(address => bool) public approvedPoolFactories;
    // Pools created by approved pool factories
    mapping(address => address) public approvedPools;

    /*****
    EVENTS
    *****/

    // Identity management
    event NewIdentity(address upalaId, address owner);
    event DelegateApproved(address upalaId, address delegate);
    event DelegateRemoved(address upalaId, address delegate);
    event NewIdentityOwner(address upalaId, address owner);
    event Exploded(address upalaId);

    // used to register new pools in graph
    // helps define pool ABI by poolFactoryAddress
    event NewPool(address newPoolAddress, address poolFactoryAddress);
    event NewPoolFactoryStatus(address poolFactory, bool isApproved);

    // Dapps
    event NewDApp(address dappAddress);

    // protocol settings
    event NewAttackWindow(uint256 newWindow);
    event NewExecutionWindow(uint256 newWindow);

    /**********
    CONSTRUCTOR
    ***********/

    function initialize () external {
        // todo (is this a good production practice?) 
        // https://forum.openzeppelin.com/t/how-to-use-ownable-with-upgradeable-contract/3336/4
        __Context_init_unchained();
        __Ownable_init_unchained();
        // defaults
        attackWindow = 30 minutes;
        executionWindow = 1 hours;
        EXPLODED = address(0x0000000000000000000000006578706c6f646564);  // Hex to ASCII = exploded
    }

    /*************
    REGISTER USERS
    **************/

    // Upala ID can be assigned to an address by a third party
    function newIdentity(address newIdentityOwner) external returns (address) {
        address newId = address(uint(keccak256(abi.encodePacked(msg.sender, now))));
        require (delegateToIdentity[newIdentityOwner] == address(0x0), "Address is already an owner or delegate");
        identityOwner[newId] = newIdentityOwner;
        delegateToIdentity[newIdentityOwner] = newId;
        NewIdentity(newId, newIdentityOwner);
        return newId;
    }

    function approveDelegate(address delegate) external {
        address upalaId = delegateToIdentity[msg.sender];
        require (identityOwner[upalaId] == msg.sender, "Only identity holder can add or remove delegates");
        delegateToIdentity[delegate] = upalaId;
        DelegateApproved(upalaId, delegate);
    }

    function removeDelegate(address delegate) external {
        require(delegate != msg.sender, "Cannot remove oneself");
        address upalaId = delegateToIdentity[msg.sender];
        require (identityOwner[upalaId] == msg.sender, "Only identity holder can add or remove delegates");
        // delegateToIdentity[delegate] = upalaId; // todo what is this line?
        // todo check if deleting the only delegate
        delete delegateToIdentity[delegate];
        DelegateRemoved(upalaId, delegate);
    }
    
    // todo check again carefully. Delegate must exist (or created) 
    function setIdentityOwner(address newIdentityOwner) external {
        address identity = _identityByAddress(msg.sender);
        require (identityOwner[identity] == msg.sender, "Only identity holder can add or remove delegates");
        require (delegateToIdentity[newIdentityOwner] == identity || delegateToIdentity[newIdentityOwner] == address(0x0), "Address is already an owner or delegate");
        identityOwner[identity] = newIdentityOwner;
        delegateToIdentity[newIdentityOwner] = identity;
        NewIdentityOwner(identity, newIdentityOwner);  // todo manage delegates in graph
    }

    // can be called by any delegate address to get id (used for tests)
    function myId() external view returns(address) {
        return _identityByAddress(msg.sender);
    }

    // can be called by any delegate address to get id owner (used for tests)
    function myIdOwner() external view  returns(address owner) {
        return _identityOwner(_identityByAddress(msg.sender));
    }

    function _identityByAddress(address ownerOrDelegate) internal view returns(address identity) {
        address identity = delegateToIdentity[ownerOrDelegate];
        require (identity != address(0x0), "no id registered for the address");
        return identity;
    }

    function _identityOwner(address upalaId) internal view returns(address owner) {
        return identityOwner[upalaId];
    }

    // production todo may be required by regulators
    // function removeIdentity(address name) external {
        
    // }

    /********
    EXPLODING
    *********/

    function isOwnerOrDelegate(address ownerOrDelegate, address identity) external view returns (bool) {
        // todo check delegate
        require(identity == delegateToIdentity[ownerOrDelegate],
            "the address is not an owner or delegate of the id");
        require (identityOwner[identity] != EXPLODED,
            "The id is already exploded");
        return true;
    }

    // checks if the identity is already exploded
    function isExploded(address identity) external returns(bool){
        return (identityOwner[identity] == EXPLODED);
    }

    // checks if the identity is already exploded
    function deleteID(address identity) external onlyApprovedPool returns(bool){
        identityOwner[identity] = EXPLODED;
        Exploded(identity);
        // delete delegateToIdentity[msg.sender];
        // todo deleting all other delegates?
        return true;
    }

    /****
    POOLS
    *****/

    // only pools created by approved factories (admin can swtich on and off all pools by a factory)
    modifier onlyApprovedPool() {
        require(approvedPoolFactories[approvedPools[msg.sender]] == true);
        _;
    }

    modifier onlyApprovedPoolFactory() {
        require(approvedPoolFactories[msg.sender] == true, "Pool factory is not approved");
        _;
    }

    // pool factories approve all pool they generate
    function approvePool(address newPool) external onlyApprovedPoolFactory returns(bool) {
        approvedPools[newPool] = msg.sender;
        NewPool(newPool, msg.sender);
        return true;
    }

    // TODO only admin
    // Admin can swtich on and off all pools by a factory (both creation of new pools and approval of existing ones)
    function setApprovedPoolFactory(address poolFactory, bool isApproved) external {
        approvedPoolFactories[poolFactory] = isApproved;
        NewPoolFactoryStatus(poolFactory, isApproved);
    }

    /****
    DAPPS
    *****/

    function registerDApp() external {
        NewDApp(msg.sender);
    }

    /************************
    UPALA PROTOCOL MANAGEMENT
    *************************/

    function setAttackWindow(uint256 newWindow) onlyOwner external {
        console.log("setAttackWindow");
        attackWindow = newWindow;
        NewAttackWindow(newWindow);
    }

    function setExecutionWindow(uint256 newWindow) onlyOwner external {
        executionWindow = newWindow;
        NewExecutionWindow(newWindow);
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
    //     require(approvedPaywallFactories[msg.sender] == true, "Paywall factory is not approved");
    //     _;
    // }

    // // paywall factories approve all paywall they generate
    // function approvePaywall(address newPaywall) external onlyApprovedPaywallFactory returns(bool) {
    //     approvedPaywalls[newPaywall] = msg.sender;
    //     NewPaywall(newPaywall, msg.sender);
    //     return true;
    // }

    // // TODO only admin
    // // Admin can swtich on and off all paywalls by a factory (both creation of new paywalls and approval of existing ones)
    // function setApprovedPaywallFactory(address paywallFactory, bool isApproved) external {
    //     approvedPaywallFactories[paywallFactory] = isApproved;
    // }

    // function isApprovedPaywall(paywall) external {
    //     return true;
    // }

}
