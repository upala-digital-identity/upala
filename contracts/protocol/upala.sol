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

    IPoolFactory pFactory;
    IPool p;

    /*******
    SETTINGS
    ********/

    uint256 registrationFee;   // spam protection + susteinability


    // any changes that hurt bots rights must be announced an hour in advance
    // changes must be executed within execution window
    uint256 public attackWindow;  // 0 - for tests // TODO set to 1 hour at production
    uint256 public executionWindow; // 1000 - for tests
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
    mapping(uint160 => mapping (bytes32 => uint256)) public roots;  
    

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
    mapping(uint160 => mapping(bytes32 => uint)) public commitsTimestamps;

    /**********
    CONSTRUCTOR
    ***********/

    function initialize () external {
        // todo (is this a good production practice?) 
        // https://forum.openzeppelin.com/t/how-to-use-ownable-with-upgradeable-contract/3336/4
        __Context_init_unchained();
        __Ownable_init_unchained();
        // defaults
        registrationFee = 0 wei;
        attackWindow = 30 minutes;
        executionWindow = 1 hours;
        EXPLODED = address(0x0000000000000000000000006578706c6f646564);  // Hex to ASCII = exploded
    }

    /*************
    REGISTER USERS
    **************/

    // Upala ID can be assigned to an address by a third party
    function newIdentity(address newIdentityHolder) external returns (uint160) {
        entityCounter++;
        require (holderToIdentity[newIdentityHolder] == 0, "Address is already an owner or delegate");
        identityHolder[entityCounter] = newIdentityHolder;
        holderToIdentity[newIdentityHolder] = entityCounter;
        return entityCounter;
    }

    function approveDelegate(address delegate) external {
        uint160 upalaId = holderToIdentity[msg.sender];
        require (identityHolder[upalaId] == msg.sender, "Only identity holder can add or remove delegates");
        holderToIdentity[delegate] = upalaId;
    }

    function removeDelegate(address delegate) external {
        uint160 upalaId = holderToIdentity[msg.sender];
        require (identityHolder[upalaId] == msg.sender, "Only identity holder can add or remove delegates");
        holderToIdentity[delegate] = upalaId;
        delete holderToIdentity[delegate];
    }

    function setIdentityOwner(address newIdentityOwner) external {
        uint160 identity = identityByAddress(msg.sender);
        require (identityHolder[identity] == msg.sender, "Only identity holder can add or remove delegates");
        require (holderToIdentity[newIdentityOwner] == identity || holderToIdentity[newIdentityOwner] == 0, "Address is already an owner or delegate");
        identityHolder[identity] = newIdentityOwner;
        holderToIdentity[newIdentityOwner] = identity;
    }

    function myId() external view returns(uint160) {
        return identityByAddress(msg.sender);
    }

    function myIdOwner() external view  returns(address owner) {
        return identityOwner(identityByAddress(msg.sender));
    }

    function identityByAddress(address ownerOrDelegate) internal view returns(uint160 identity) {
        uint160 identity = holderToIdentity[ownerOrDelegate];
        require (identity > 0, "no id registered for the address");
        return identity;
    }

    function identityOwner(uint160 upalaId) internal view returns(address owner) {
        return identityHolder[upalaId];
    }

    /************************
    REGISTER GROUPS AND POOLS
    *************************/

    function newGroup(address newGroupManager, address poolFactory) external returns (uint160, address) {
        require (managerToGroup[newGroupManager] == 0, "Provided address already manages a group");
        entityCounter++;
        groupManager[entityCounter] = newGroupManager;
        groupPool[entityCounter] = _newPool(poolFactory, entityCounter);
        managerToGroup[newGroupManager] = entityCounter;
        return (entityCounter, groupPool[entityCounter]);
    }

    function getGroupID(address managerAddress) external view returns(uint160 groupID) {
        uint160 groupID = managerToGroup[managerAddress];
        require (groupID > 0, "no id registered for the address");
        return groupID;
    }

    function getGroupPool(uint160 groupID) external view returns(address poolAddress) {
        address poolAddress = groupPool[groupID];
        require (poolAddress != address(0x0), "no pool registered for the group ID");
        return poolAddress;
    }

    // TODO get group from msg.sender
    function setGroupManager(address newGroupManager) external {
        uint160 group = managerToGroup[msg.sender];
        address currentManager = groupManager[group];
        groupManager[group] = newGroupManager;
        delete managerToGroup[currentManager];
        managerToGroup[newGroupManager] = group;
    }

    function upgradePool(address poolFactory, bytes32 secret) external returns (address, uint256) {
        // check committment
        uint160 group = managerToGroup[msg.sender];
        bytes32 hash = keccak256(abi.encodePacked("withdrawFromPool", secret));
        checkHash(group, hash);
        // transfer funds (max available)
        address oldPool = groupPool[group];
        address newPool = _newPool(poolFactory, group);
        uint256 MAX_INT = 2**256 - 1;
        uint256 withdrawnAmount = IPool(oldPool).withdrawAvailable(newPool, MAX_INT);
        // atatch new pool to group
        groupPool[group] = newPool;
        delete commitsTimestamps[group][hash];
        return (newPool, withdrawnAmount);
    }

    // tokens are only stable USDs
    function _newPool(address poolFactory, uint160 poolOwner) private returns (address) {
        require(approvedPoolFactories[poolFactory] == true, "Pool factory is not approved");
        // require PoolOwner exists // todo?
        address newPoolAddress = IPoolFactory(poolFactory).createPool(poolOwner);
        poolsOwners[newPoolAddress] = poolOwner;
        return newPoolAddress;
    }




    /*********************
    SCORING AND BOT ATTACK
    **********************/

    function isExploded(uint160 identity) external returns(bool){
        return (identityHolder[identity] == EXPLODED);
    }

    function verifyTemp() public returns(bool res) { // a mock function before real Merkle is implemented
        return true;
    }

    function getRootTemp(uint160 identityID, uint8 score, bytes32[] memory proof) public returns(bytes32 res) {
        return "0x000000006578706c6f646564";
    }
    
    // for Multipassport (user quering if own score is still verifiable) - hackathon mock
    function verifyMyScore (uint160 groupID, uint160 identityID, uint8 score, bytes32[] calldata proof) external view returns (bool) {
        return true;
    }

    // for DApps - hackathon mock
    function verifyUserScore (uint160 groupID, uint160 identityID, address holder, uint8 score, bytes32[] calldata proof) external returns (bool) {
        return true;
    }
    
    function userScore(uint160 groupID, uint160 identityID, address holder, uint8 score, bytes32[] memory proof) private returns (uint256){
        require(holder == identityHolder[identityID],
            "the holder address doesn't own the user id");
        require (identityHolder[identityID] != EXPLODED,
            "This user has already exploded");
        // pool amount is sufficient for explosion
        require (roots[groupID][getRootTemp(identityID, score, proof)] > 0);
        uint256 totalScore = baseReward[groupID] * score;
        
        return totalScore;
    }

    // Allows any identity to attack any group, run with the money and self-destruct.
    // Only those with scores will succeed.
    // todo no nonReentrant?
    function _attack(uint160 groupID, uint160 identityID, uint8 score, bytes32[] calldata proof)
        external
    {
        uint160 bot = identityID;
        address botOwner = msg.sender;

        // payout
        uint256 reward = userScore(groupID, identityID, msg.sender, score, proof);
        IPool(groupPool[groupID]).payBotReward(botOwner, reward); // $$$

        // explode
        identityHolder[bot] = EXPLODED;  // to tell exploded IDs apart from non existent (UIP-12)
        delete holderToIdentity[msg.sender];
    }

    // hackathon mock
    function attack(uint160 groupID, uint160 identityID, uint8 score, bytes32[] calldata proof)
        external
    {
        uint160 bot = identityID;
        address botOwner = msg.sender;
        identityHolder[bot] = EXPLODED;
        delete holderToIdentity[msg.sender];
    }

    /************
    MANAGE GROUPS
    *************/

    /*Announcements*/
    // Announcements prevents front-running bot-exposions. Groups must announce
    // in advance any changes that may hurt bots rights

    // hash = keccak256(action-type, [parameters], secret)
    function commitHash(bytes32 hash) external returns(uint256 timestamp) {
        uint160 group = managerToGroup[msg.sender];
        uint256 timestamp = now;
        commitsTimestamps[group][hash] = timestamp;
        return timestamp;
    }
 
    function checkHash(uint160 group, bytes32 hash) internal view returns(bool){
        require (commitsTimestamps[group][hash] != 0, "No such commitment hash");
        require (commitsTimestamps[group][hash] + attackWindow <= now, "Attack window is not closed yet");
        require (commitsTimestamps[group][hash] + attackWindow + executionWindow >= now, "Execution window is already closed");
        // todo is it possible to create lock for active commits when changing windows?
        return true;
    }

    /*Changes that may hurt bots rights*/

    // Sets the maximum possible bot reward for the group.
    function setBaseScore(uint botReward, bytes32 secret) external {
        uint160 group = managerToGroup[msg.sender];
        bytes32 hash = keccak256(abi.encodePacked("setBaseScore", botReward, secret));
        checkHash(group, hash);
        baseReward[group] = botReward;
        delete commitsTimestamps[group][hash];
        // emit Set("NewBotReward", group, botReward);
    }

    function deleteRoot(bytes32 root, bytes32 secret) external {
        uint160 group = managerToGroup[msg.sender];
        bytes32 hash = keccak256(abi.encodePacked("deleteRoot", root, secret));
        checkHash(group, hash);
        require(commitsTimestamps[group][hash] > roots[group][root], "Commit is submitted before root");
        delete commitsTimestamps[group][hash];
        delete roots[group][root];
    }

    // tries to withdraw as much as possible (bots could have attacked after an announcement) 
    function withdrawFromPool(address recipient, uint amount, bytes32 secret) external returns (uint256){ // $$$
        uint160 group = managerToGroup[msg.sender];
        bytes32 hash = keccak256(abi.encodePacked("withdrawFromPool", secret));
        checkHash(group, hash);
        uint256 withdrawnAmount = IPool(groupPool[group]).withdrawAvailable(recipient, amount);
        delete commitsTimestamps[group][hash];
        // emit Set("withdrawFromPool", withdrawed);
        return withdrawnAmount;
    }

    /*Changes that don't hurt bots rights*/

    function increaseBaseScore(uint newBotReward) external {
        uint160 group = managerToGroup[msg.sender];
        require (newBotReward > baseReward[group], "To decrease score, make a commitment first");
        baseReward[group] = newBotReward;
    }

    function publishRoot(bytes32 newRoot) external {
        uint160 group = managerToGroup[msg.sender];
        roots[group][newRoot] = now;
    }

    /**************
    GETTER FUNCTIONS
    ***************/

    function groupBaseScore(uint160 groupID) external view returns (uint) {
        return baseReward[groupID];
    }




    /************************
    UPALA PROTOCOL MANAGEMENT
    *************************/

    // TODO only admin
    function setapprovedPoolFactory(address poolFactory, bool isApproved) external {
        approvedPoolFactories[poolFactory] = isApproved;
    }

    function setAttackWindow(uint256 newWindow) onlyOwner external {
        attackWindow = newWindow;
    }

    function setExecutionWindow(uint256 newWindow) onlyOwner external {
        executionWindow = newWindow;
    }
    // registrationFee
    // approvedPoolFactories
}
