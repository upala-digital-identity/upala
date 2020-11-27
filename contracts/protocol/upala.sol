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

    // the maximum depth of hierarchy
    // ensures attack gas cost is always lower than block maximum.
    uint256 maxPathLength;

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
    mapping(uint160 => uint256) groupBotReward;  // baseReward
    // Member botReward within group = botReward * trust / 100 
    // limit, exposure, scoreMultiplier, rewardMultiplier
    mapping(uint160 => mapping (uint160 => uint8)) memberTrust;  
    

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
        maxPathLength = 10;
        attackWindow = 0 hours;
        executionWindow = 1000 hours;
        EXPLODED = 0x0000000000000000000000006578706c6f646564;  // Hex to ASCII = exploded
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

    // only for users
    function myScore(uint160[] calldata path)
        external
        view
        // TODO onlyValidPath
        
        returns(uint256)
    {
        require(identityHolder[path[0]] == msg.sender,
            "identity is not owned by the msg.sender"
        );
        return (_memberScore(path));
    }

    // only for groups
    function memberScore(address holder, uint160[] calldata path)
        external
        view
        // TODO onlyValidPath
        
        returns(uint256)
    {
        require(holder == identityHolder[path[0]],
            "the holder address doesn't own the id");
        require(groupManager[path[path.length-1]] == msg.sender, 
            "the last group in the path is not managed by the msg.sender");
        return (_memberScore(path));
    }

    // only for dapps
    function userScore(address holder, uint160[] calldata path)
        external
        // TODO onlyValidPath
        
        returns(uint256)
    {
        require(holder == identityHolder[path[0]],
            "the holder address doesn't own the user id");
        // will break if score is <0 or invalid path
        uint256 score = _memberScore(path);
        return score;
    }

    // Allows any identity to attack any group, run with the money and self-destruct.
    // Only those with scores will succeed.
    // todo no nonReentrant?
    function attack(uint160[] calldata path)
        external
    { 
        // first member in path must be an identity, managed by message sender
        require(identityHolder[path[0]] == msg.sender, "msg.sender is not identity holder");
        
        // get scores along the path (checks validity too)
        uint256[] memory scores = new uint256[](path.length);
        scores = _scores(path);

        // pay rewards
        uint160 bot = path[0];
        address botOwner = identityHolder[bot];  
        uint160 group;
        for (uint i = 0; i<=path.length-2; i++) {
            group = path[i+1];
            IPool(groupPool[group]).payBotReward(botOwner, scores[i]); // $$$
            }

        // explode
        identityHolder[bot] = EXPLODED;  // to tell exploded IDs apart from non existent (UIP-12)
        delete memberTrust[path[1]][bot]; // delete bot score in the above group
        delete holderToIdentity[msg.sender];
    }

    // Ascends the path in groups hierarchy and confirms identity score (path validity)
    function _memberScore(uint160[] memory path)
        private
        view
        returns (uint256)
    {
        // get scores along the path (checks validity too)
        uint256[] memory scores = new uint256[](path.length);
        scores = _scores(path);

        // sumup the scores
        uint256 score = 0;
        for (uint i = 0; i<=path.length-2; i++) {
            score += scores[i];
        }
        return score;
    }

    // checks path for validity and returns an array of scores, corresponding to path
    function _scores(uint160[] memory path) private view returns (uint256[] memory) {
        require(path.length != 0, "path too short");
        require(path.length <= maxPathLength, "path too long");

        uint256[] memory scores = new uint256[](path.length);

        uint160 member;
        uint160 group;
        uint256 memberReward;
        for (uint i = 0; i<=path.length-2; i++) {
            member = path[i];
            group = path[i+1];

            require (memberTrust[group][member] > 0, "Not a member");
            
            memberReward = groupBotReward[group] * memberTrust[group][member] / 100; // TODO overflow-safe mul!
            require(IPool(groupPool[group]).hasEnoughFunds(memberReward), "A group in path is unable to pay declared bot reward.");
            scores[i] = memberReward;
        }

        return scores;
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
    function setBotReward(uint botReward, bytes32 secret) external {
        uint160 group = managerToGroup[msg.sender];
        bytes32 hash = checkHash(keccak256(abi.encodePacked("setBotReward", group, botReward)));
        groupBotReward[group] = botReward;
        delete commitsTimestamps[hash];
        // emit Set("NewBotReward", group, botReward);
    }

    function setTrust(uint160 member, uint8 trust, bytes32 secret) external {
        uint160 group = managerToGroup[msg.sender];
        require (trust <= 100, "Provided trust percent is above 100");
        bytes32 hash = checkHash(keccak256(abi.encodePacked("setTrust", group, member, trust)));
        memberTrust[group][member] = trust;
        delete commitsTimestamps[hash];
        // emit Set("setBotnetLimit", hash);
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
        require (newBotReward > groupBotReward[group], "To decrease reward, make an announcement first");
        groupBotReward[group] = newBotReward;
    }

    function increaseTrust(uint160 member, uint8 newTrust) external {
        uint160 group = managerToGroup[msg.sender];
        require (newTrust <= 100, "Provided trust percent is above 100");
        require (newTrust > memberTrust[group][member], "To decrease trust, make an announcement first");
        memberTrust[group][member] = newTrust;
    }

    /**************
    GETTER FUNCTIONS
    ***************/

    // used by gitcoin group (aggregator) to reverse-engineer member trust within a group
    function getBotReward(uint160 group) external view returns (uint) {
        return groupBotReward[group];
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
