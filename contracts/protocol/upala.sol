pragma solidity ^0.6.0;

// import "./i-upala.sol";
import "../libraries/openzeppelin-contracts/contracts/math/SafeMath.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "../pools/i-pool-factory.sol";
import "../pools/i-pool.sol";
import "hardhat/console.sol";


// The Upala ledger (protocol)
contract Upala is Initializable{
    using SafeMath for uint256;

    IPoolFactory pFactory;
    IPool p;

    /*******
    SETTINGS
    ********/

    uint256 registrationFee;   // spam protection + susteinability


    // any changes that hurt bots rights must be announced an hour in advance
    // changes must be executed within execution window
    uint256 attackWindow;  // 0 - for tests // TODO set to 1 hour at production
    uint256 executionWindow; // 1000 - for tests
    address EXPLODED; // assigned as identity holder after ID explosion

    /***************************
    GROUPS, IDENTITIES AND POOLS
    ***************************/

    // keep track of new groups, identities and pools
    uint160 entityCounter;

    // Groups 
    // Groups are outside contracts with arbitary logic
    // A group id within Upala is permanent. 
    // Ownership provides group upgradability
    // Group manager - is any entity in control of a group.
    mapping(uint160 => address) groupManager;
    mapping(address => uint160) managerToGroup;
    // Pools are created by Upala-approved pool factories
    // Each group may manage their own pool in their own way.
    // But they are all deliberately vulnerable to bot attacks
    mapping(uint160 => address) groupPool;
    // The most important obligation of a group is to pay bot rewards.
    // A group can set its own maximum bot reward
    mapping(uint160 => uint256) baseReward;  // baseReward
    mapping(uint160 => mapping (bytes32 => bool)) roots;  
    

    // Identities
    // Ensures that identities and groups are different entities
    // Ensures that an exploded bot will never be able to get a score or explode again
    // Human, Individual, Identity
    mapping(uint160 => address) identityHolder;
    mapping(address => uint160) holderToIdentity;

    // Pools
    // Pool Factories approved by Upala admin
    mapping(address => bool) approvedPoolFactories;
    // Pools owners by Upala group ID - will allow to switch pools and add other logic.
    mapping(address => uint160) poolsOwners;  

    /************
    ANNOUNCEMENTS
    *************/

    // Any changes that can hurt bot rights must wait for an attackWindow to expire
    mapping(bytes32 => uint) commitsTimestamps;

    /**********
    CONSTRUCTOR
    ***********/

    function initialize () external {
        registrationFee = 0 wei;
        // maxPathLength = 10;
        attackWindow = 0 hours;
        executionWindow = 1000 hours;
        EXPLODED = address(0x0000000000000000000000006578706c6f646564);  // Hex to ASCII = exploded
    }

    /************************************
    REGISTER GROUPS, IDENTITIES AND POOLS
    ************************************/

    function newGroup(address newGroupManager, address poolFactory) external payable returns (uint160, address) {
        require(msg.value == registrationFee, "Incorrect registration fee");  // draft
        entityCounter++;
        groupManager[entityCounter] = newGroupManager;
        groupPool[entityCounter] = _newPool(poolFactory, entityCounter);
        managerToGroup[newGroupManager] = entityCounter;
        return (entityCounter, groupPool[entityCounter]);
    }

    function newIdentity(address newIdentityHolder) external payable returns (uint160) {
        require(msg.value == registrationFee, "Incorrect registration fee");  // draft
        entityCounter++;
        identityHolder[entityCounter] = newIdentityHolder;
        holderToIdentity[newIdentityHolder] = entityCounter;
        return entityCounter;
    }

    // tokens are only stable USDs
    function _newPool(address poolFactory, uint160 poolOwner) private returns (address) {
        require(approvedPoolFactories[poolFactory] == true, "Pool factory is not approved");
        // require PoolOwner exists // todo?
        address newPoolAddress = IPoolFactory(poolFactory).createPool(poolOwner);
        poolsOwners[newPoolAddress] = poolOwner;
        return newPoolAddress;
    }

    // TODO get group from msg.sender
    function setGroupManager(address newGroupManager) external {
        uint160 group = managerToGroup[msg.sender];
        address currentManager = groupManager[group];
        groupManager[group] = newGroupManager;
        delete managerToGroup[currentManager];
        managerToGroup[newGroupManager] = group;
    }

    // TODO get ID from msg.sender
    function setIdentityHolder(address newIdentityHolder)  external {
        uint160 identity = holderToIdentity[msg.sender];
        address currentHolder = identityHolder[identity];
        identityHolder[identity] = newIdentityHolder;
        delete holderToIdentity[currentHolder];
        holderToIdentity[newIdentityHolder] = identity;
    }


    /*********************
    SCORING AND BOT ATTACK
    **********************/

    function verifyTemp() public returns(bool res) { // a mock function before real Merkle is implemented
        return true;
    }

    function getRootTemp(uint160 identityID, uint8 score, bytes32[] memory proof) public returns(bytes32 res) {
        return "0x000000006578706c6f646564";
    }
    
    function verifyScore (uint160 groupID, uint160 identityID, address holder, uint8 score, bytes32[] calldata proof) external {

    }

    // for DApps
    function userScore(uint160 groupID, uint160 identityID, address holder, uint8 score, bytes32[] memory proof) private returns (uint256){
        require(holder == identityHolder[identityID],
            "the holder address doesn't own the user id");
        require (identityHolder[identityID] != EXPLODED,
            "This user has already exploded");

        require (roots[groupID][getRootTemp(identityID, score, proof)] == true);
        uint256 totalScore = baseReward[groupID] * score;
        
        return totalScore;
    }

    // Allows any identity to attack any group, run with the money and self-destruct.
    // Only those with scores will succeed.
    // todo no nonReentrant?
    function attack(uint160 groupID, uint160 identityID, uint8 score, bytes32[] calldata proof)
        external
    {
        uint160 bot = identityID;
        address botOwner = msg.sender;
        uint256 reward = userScore(groupID, identityID, msg.sender, score, proof);

        IPool(groupPool[groupID]).payBotReward(botOwner, reward); // $$$

        // explode
        identityHolder[bot] = EXPLODED;  // to tell exploded IDs apart from non existent (UIP-12)
        delete holderToIdentity[msg.sender];
    }


    /************
    MANAGE GROUPS
    *************/

    /*Announcements*/
    // Announcements prevents front-running bot-exposions. Groups must announce
    // in advance any changes that may hurt bots rights

    // hash = keccak256(groupID, action-type, [parameters], ..secret, ..nonce)
    // secret allows to store commitments independently from groups.
    // nonce may be required for withdrawals or other logic
    function commitHash(bytes32 hash) external returns(uint256 nonce) {
        commitsTimestamps[hash] = now;
        return 0;
    }

    function checkHash(bytes32 hash) internal view returns(bytes32){
        require (commitsTimestamps[hash] != 0, "No such commitment hash");
        require (commitsTimestamps[hash] + attackWindow <= now, "Attack window is not closed yet");
        require (commitsTimestamps[hash] + executionWindow >= now, "Execution window is already closed");
        return hash;
    }

    /*Changes that may hurt bots rights*/

    // Sets the maximum possible bot reward for the group.
    function setBaseReward(uint botReward, bytes32 secret) external {
        uint160 group = managerToGroup[msg.sender];
        bytes32 hash = checkHash(keccak256(abi.encodePacked("setBaseReward", group, botReward)));
        baseReward[group] = botReward;
        delete commitsTimestamps[hash];
        // emit Set("NewBotReward", group, botReward);
    }

    function deleteRoot(bytes32 root) public {
        uint160 group = managerToGroup[msg.sender];
        bytes32 hash = checkHash(keccak256(abi.encodePacked("deleteRoot", group, root)));
        delete commitsTimestamps[hash];
        delete roots[group][root];
    }

    // tries to withdraw as much as possible (bots could have attacked after an announcement) 
    function withdrawFromPool(address recipient, uint amount, bytes32 secret) external returns (uint256){ // $$$
        uint160 group = managerToGroup[msg.sender];
        bytes32 hash = checkHash(keccak256(abi.encodePacked("withdrawFromPool", group, recipient, amount)));
        uint256 withdrawnAmount = IPool(groupPool[group]).withdrawAvailable(recipient, amount);
        delete commitsTimestamps[hash];
        // emit Set("withdrawFromPool", withdrawed);
        return withdrawnAmount;
    }

    /*Changes that don't hurt bots rights*/

    function increaseReward(uint newBotReward) external {
        uint160 group = managerToGroup[msg.sender];
        require (newBotReward > baseReward[group], "To decrease reward, make a commitment first");
        baseReward[group] = newBotReward;
    }

    function publishRoot(bytes32 newRoot) external {
        uint160 group = managerToGroup[msg.sender];
        roots[group][newRoot] = true;
    }

    /**************
    GETTER FUNCTIONS
    ***************/

    // used by gitcoin group (aggregator) to reverse-engineer member trust within a group
    function getBotReward(uint160 group) external view returns (uint) {
        return baseReward[group];
    }

    // returns upala identity id
    function myId() external view returns(uint160) {
        return holderToIdentity[msg.sender];
    }

    function isExploded(uint160 identity) external returns(bool){
        return (identityHolder[identity] == EXPLODED);
    }
    

    function groupIDbyManager(address manager) internal view returns(uint160) {
        return managerToGroup[manager];
    }


    /************************
    UPALA PROTOCOL MANAGEMENT
    *************************/

    // TODO only admin
    function setapprovedPoolFactory(address poolFactory, bool isApproved) external {
        approvedPoolFactories[poolFactory] = isApproved;
    }
    // registrationFee
    // maxPathLength
    // attackWindow
    // executionWindow
    // approvedPoolFactories
}


/* todo consider:

- loops in social graphs. is nonReentrant enough?

*/
