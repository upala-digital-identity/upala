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
    address EXPLODED; // assigned as identity holder after ID explosion

    /*******
    SETTINGS
    ********/
    // any changes that hurt bots rights must be announced an hour in advance
    uint256 public attackWindow;  // 0 - for tests // TODO set to 1 hour at production
    // changes must be executed within execution window
    uint256 public executionWindow; // 1000 - for tests


    /***************************
    GROUPS, IDENTITIES AND POOLS
    ***************************/

    // Groups 
    // Groups can be managed by outside contracts (or simple address) with arbitary logic
    // A group id within Upala is permanent. 
    // Ownership provides group upgradability.
    // Group manager - is any entity in control of a group.
    mapping(address => address) groupManager;
    mapping(address => address) public managerToGroup;
    // Pools are created by Upala-approved pool factories
    // Each group may manage their own pool in their own way.
    // But they are all deliberately vulnerable to bot attacks
    mapping(address => address) groupPool;
    // The most important obligation of a group is to pay bot rewards.
    // A group can set its own maximum bot reward
    mapping(address => uint256) baseReward;  // baseReward
    // merkle roots of trees storing scores
    mapping(address => mapping (bytes32 => uint256)) public roots;
    

    // Identities
    // Identity owner. Can change owner, can assign delegates
    mapping(address => address) identityOwner; // idOwner
    // Addresses that can use the associated id (delegates and oner).
    // Also used to retrieve id by address
    mapping(address => address) delegateToIdentity;

    // Pools
    // Pool Factories approved by Upala admin
    mapping(address => bool) approvedPoolFactories;
    // Pools owners by Upala group ID - will allow to switch pools and add other logic.
    mapping(address => address) poolsOwners;  

    /************
    ANNOUNCEMENTS
    *************/

    // Any changes that can hurt bot rights must wait for an attackWindow to expire
    mapping(address => mapping(bytes32 => uint)) public commitsTimestamps;

    /*****
    EVENTS
    *****/

    event Claimed(
        uint256 _index,
        address _identityID,
        uint256 _score
    );

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
    function newIdentity(address newidentityOwner) external returns (address) {
        address newId = address(uint(keccak256(abi.encodePacked(msg.sender, now))));
        require (delegateToIdentity[newidentityOwner] == address(0x0), "Address is already an owner or delegate");
        identityOwner[newId] = newidentityOwner;
        delegateToIdentity[newidentityOwner] = newId;
        return newId;
    }

    function approveDelegate(address delegate) external {
        address upalaId = delegateToIdentity[msg.sender];
        require (identityOwner[upalaId] == msg.sender, "Only identity holder can add or remove delegates");
        delegateToIdentity[delegate] = upalaId;
    }

    function removeDelegate(address delegate) external {
        require(delegate != msg.sender, "Cannot remove oneself");
        address upalaId = delegateToIdentity[msg.sender];
        require (identityOwner[upalaId] == msg.sender, "Only identity holder can add or remove delegates");
        // delegateToIdentity[delegate] = upalaId; // todo what is this line?
        // todo check if deleting the only delegate
        delete delegateToIdentity[delegate];
    }

    function setIdentityOwner(address newIdentityOwner) external {
        address identity = _identityByAddress(msg.sender);
        require (identityOwner[identity] == msg.sender, "Only identity holder can add or remove delegates");
        require (delegateToIdentity[newIdentityOwner] == identity || delegateToIdentity[newIdentityOwner] == address(0x0), "Address is already an owner or delegate");
        identityOwner[identity] = newIdentityOwner;
        delegateToIdentity[newIdentityOwner] = identity;
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

    /************************
    REGISTER GROUPS AND POOLS
    *************************/

    function newGroup(address newGroupManager, address poolFactory) external returns (address, address) {
        require (managerToGroup[newGroupManager] == address(0x0), "Provided address already manages a group");

        address newGroupId = address(uint(keccak256(abi.encodePacked(msg.sender, now))));
        groupManager[newGroupId] = newGroupManager;
        groupPool[newGroupId] = _newPool(poolFactory, newGroupId);
        managerToGroup[newGroupManager] = newGroupId;
        return (newGroupId, groupPool[newGroupId]);
    }

    function getGroupID(address managerAddress) external view returns(address groupID) {
        address groupID = managerToGroup[managerAddress];
        require (groupID != address(0x0), "no group registered for the address");  // TODO why this doesn't work?!
        return groupID;
    }

    function getGroupPool(address groupID) external view returns(address poolAddress) {
        address poolAddress = groupPool[groupID];
        require (poolAddress != address(0x0), "no pool registered for the group ID");
        return poolAddress;
    }

    // TODO get group from msg.sender
    function setGroupManager(address newGroupManager) external {
        address group = managerToGroup[msg.sender];
        address currentManager = groupManager[group];
        groupManager[group] = newGroupManager;
        delete managerToGroup[currentManager];
        managerToGroup[newGroupManager] = group;
    }

    function upgradePool(address poolFactory, bytes32 secret) external returns (address, uint256) {
        // check committment
        address group = managerToGroup[msg.sender];
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
    function _newPool(address poolFactory, address poolOwner) private returns (address) {
        require(approvedPoolFactories[poolFactory] == true, "Pool factory is not approved");
        // require PoolOwner exists // todo?
        address newPoolAddress = IPoolFactory(poolFactory).createPool(poolOwner);
        poolsOwners[newPoolAddress] = poolOwner;
        return newPoolAddress;
    }




    /*********************
    SCORING AND BOT ATTACK
    **********************/

    // ####### Hackathon mocks begin ##########

    // a mock function before real Merkle is implemented
    function verifyHack() public returns(bool res) { 
        return true;
    }

    // a mock function before real Merkle is implemented
    function getRootHack(address identityID, uint8 score, bytes32[] memory proof) public returns(bytes32 res) {
        return "0x000000006578706c6f646564";
    }

    // for DApps - hackathon mock
    function verifyUserScoreHack (address groupID, address identityID, address holder, uint8 score, bytes32[] calldata proof) external returns (bool) {
        return true;
    }

    // ####### Hackathon mocks end ##########



    // checks if the identity is already exploded
    function isExploded(address identity) external returns(bool){
        return (identityOwner[identity] == EXPLODED);
    }

    function myScore(uint256 index, address groupID, address identityID, uint256 score, bytes32[] calldata merkleProof) external {
        require(msg.sender == identityOwner[identityID],
            "the holder address doesn't own the user id");
        require (identityOwner[identityID] != EXPLODED,
            "This user has already exploded");
        // TODO check that pool balance is sufficient for explosion

        // Verify the merkle proof.
        bytes32 leaf = keccak256(abi.encodePacked(index, identityID, score));
        require (roots[groupID][_computeRoot(merkleProof, leaf)] > 0, 'MerkleDistributor: Invalid proof.');
        
        emit Claimed(index, identityID, score);
        // uint256 totalScore = baseReward[groupID] * score;
        // return totalScore;
    }

    // Allows any identity to attack any group, run with the money and self-destruct.
    // todo no nonReentrant?
    function attack(address groupID, address identityID, uint8 score, bytes32[] calldata proof)
        external
    {
        address bot = identityID;
        address botOwner = msg.sender;

        // payout
        uint256 reward = _userScore(groupID, identityID, msg.sender, score, proof);
        IPool(groupPool[groupID]).payBotReward(botOwner, reward); // $$$

        // explode
        identityOwner[bot] = EXPLODED;  // to tell exploded IDs apart from non existent (UIP-12)
        delete delegateToIdentity[msg.sender];
    }

    function _userScore(address groupID, address identityID, address holder, uint8 score, bytes32[] memory proof) private returns (uint256){
        require(holder == identityOwner[identityID],
            "the holder address doesn't own the user id");
        require (identityOwner[identityID] != EXPLODED,
            "This user has already exploded");
        // pool amount is sufficient for explosion
        require (roots[groupID][getRootHack(identityID, score, proof)] > 0);
        uint256 totalScore = baseReward[groupID] * score;
        
        return totalScore;
    }

    function _computeRoot(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash;
    }

    /************
    MANAGE GROUPS
    *************/

    /*Announcements*/
    // Announcements prevents front-running bot-exposions. Groups must announce
    // in advance any changes that may hurt bots rights

    // hash = keccak256(action-type, [parameters], secret)
    function commitHash(bytes32 hash) external returns(uint256 timestamp) {
        address group = managerToGroup[msg.sender];
        uint256 timestamp = now;
        commitsTimestamps[group][hash] = timestamp;
        return timestamp;
    }
 
    function checkHash(address group, bytes32 hash) internal view returns(bool){
        require (commitsTimestamps[group][hash] != 0, "No such commitment hash");
        require (commitsTimestamps[group][hash] + attackWindow <= now, "Attack window is not closed yet");
        require (commitsTimestamps[group][hash] + attackWindow + executionWindow >= now, "Execution window is already closed");
        // todo is it possible to create lock for active commits when changing windows?
        return true;
    }

    /*Changes that may hurt bots rights*/

    // Sets the maximum possible bot reward for the group.
    function setBaseScore(uint botReward, bytes32 secret) external {
        address group = managerToGroup[msg.sender];
        bytes32 hash = keccak256(abi.encodePacked("setBaseScore", botReward, secret));
        // todo not checknig hash timestamp
        checkHash(group, hash);
        baseReward[group] = botReward;
        delete commitsTimestamps[group][hash];
        // emit Set("NewBotReward", group, botReward);
    }

    function deleteRoot(bytes32 root, bytes32 secret) external {
        address group = managerToGroup[msg.sender];
        bytes32 hash = keccak256(abi.encodePacked("deleteRoot", root, secret));
        checkHash(group, hash);
        require(commitsTimestamps[group][hash] > roots[group][root], "Commit is submitted before root");
        delete commitsTimestamps[group][hash];
        delete roots[group][root];
    }

    // tries to withdraw as much as possible (bots could have attacked after an announcement) 
    function withdrawFromPool(address recipient, uint amount, bytes32 secret) external returns (uint256){ // $$$
        address group = managerToGroup[msg.sender];
        bytes32 hash = keccak256(abi.encodePacked("withdrawFromPool", secret));
        checkHash(group, hash);
        uint256 withdrawnAmount = IPool(groupPool[group]).withdrawAvailable(recipient, amount);
        delete commitsTimestamps[group][hash];
        // emit Set("withdrawFromPool", withdrawed);
        return withdrawnAmount;
    }

    /*Changes that don't hurt bots rights*/

    function increaseBaseScore(uint newBotReward) external {
        address group = managerToGroup[msg.sender];
        require (newBotReward > baseReward[group], "To decrease score, make a commitment first");
        baseReward[group] = newBotReward;
    }

    function publishRoot(bytes32 newRoot) external {
        address group = managerToGroup[msg.sender];
        require(group != address(0x0), "No group associated with the manager");
        roots[group][newRoot] = now;
    }

    /**************
    GETTER FUNCTIONS
    ***************/

    function groupBaseScore(address groupID) external view returns (uint) {
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
    // approvedPoolFactories
}
