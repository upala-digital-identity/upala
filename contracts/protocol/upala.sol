pragma solidity ^0.6.0;

/*/// WARNING

The code is under heavy developement

/// WARNING */

// import "./i-upala.sol";
import "../libraries/openzeppelin-contracts/contracts/math/SafeMath.sol";
import "../pools/i-pool-factory.sol";
import "../pools/i-pool.sol";
import "@nomiclabs/buidler/console.sol";

/*
The Upala contract is the protocol itself.
Identity systems can use this contract to comply with universal bot explosion rules.
These identity systems will then be compatible.

Upala-native identity systems are presumed to consist of groups of many levels.
Each group is a smart contract with arbitary logic.
*/





// The Upala ledger (protocol)
contract Upala {
    using SafeMath for uint256;

    IPoolFactory pFactory;
    IPool p;

    /*******
    SETTINGS
    ********/

    uint256 registrationFee = 0 wei;   // spam protection + susteinability

    // the maximum depth of hierarchy
    // ensures attack gas cost is always lower than block maximum.
    uint256 maxPathLength = 10;

    // any changes that hurt bots rights must be announced an hour in advance
    // changes must be executed within execution window
    uint256 attackWindow = 0 hours;  // 0 - for tests // TODO set to 1 hour at production
    uint256 executionWindow = 1000 hours; // 1000 - for tests

    /***************************
    GROUPS, IDENTITIES AND POOLS
    ***************************/

    // keep track of new groups, identities and pools ids
    uint160 entityCounter;

    // Managed by Upala admin
    mapping(address => bool) approvedPoolFactories;

    // Groups are outside contracts with arbitary logic
    struct Group {

        // A group address within Upala is permanent. Ownership provides group upgradability
        address manager;

        // Pools are created by Upala-approved pool factories
        // Each group may manage their own pool in their own way.
        // But they must be made deliberately vulnerable to bot attacks
        address pool;

        // The most important obligation of a group is to pay bot rewards.
        // A group can set its own maximum bot reward
        uint256 botReward;  // botReward  .. baseReward

        // [Member botReward within group] = botReward * trust / 100 
        mapping(uint160 => uint8) trust;  // limit, exposure, scoreMultiplier, rewardMultiplier

        // removed for faster MVP (UIP-3, UIP-8)
        // mapping(address => uint256) appCredits;
        // uint256 annoucementNonce;
        // uint256 lastExecutedAnnouncement;
    }
    // These addresses are permanent. Serve as IDs.
    mapping(uint160 => Group) groups;
    mapping(address => uint160) managerToGroup;

    // Identities
    // Ensures that identities and groups are different entities
    // Ensures that an exploded bot will never be able to get a score or explode again
    // Human, Individual, Identity
    struct Identity {
        address holder;  // wallet, manager, owner
    }
    mapping(uint160 => Identity) identities;
    mapping(address => uint160) holderToIdentity;

    // Every pool spawned by approved Pool Factories
    mapping(address => uint160) poolsOwners;

    /************
    ANNOUNCEMENTS
    *************/

    // Humans commit changes, this mapping stores hashes and timestamps
    // Any changes that can hurt bot rights must wait for an attackWindow to expire
    mapping(bytes32 => uint) commitsTimestamps;


    constructor () public {
        // todo
    }


    /************************************
    REGISTER GROUPS, IDENTITIES AND POOLS
    ************************************/

    function newGroup(address groupManager, address poolFactory) external payable returns (uint160, address) {
        require(msg.value == registrationFee, "Incorrect registration fee");  // draft
        entityCounter++;
        groups[entityCounter].manager = groupManager;
        groups[entityCounter].pool = _newPool(poolFactory, entityCounter);
        managerToGroup[groupManager] = entityCounter;
        return (entityCounter, groups[entityCounter].pool);
    }

    function newIdentity(address identityHolder) external payable returns (uint160) {
        require(msg.value == registrationFee, "Incorrect registration fee");  // draft
        entityCounter++;
        identities[entityCounter].holder = identityHolder;
        holderToIdentity[identityHolder] = entityCounter;
        return entityCounter;
    }

    // created by approved pool factories
    // tokens are only stable USDs
    function newPool(address poolFactory, uint160 poolOwner) external payable returns (address) {
        // TODO check poolOwner exists
        require(msg.value == registrationFee, "Incorrect registration fee");  // draft
        return _newPool(poolFactory, poolOwner);
    }

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
        address currentManager = groups[group].manager;
        groups[group].manager = newGroupManager;
        delete managerToGroup[currentManager];
        managerToGroup[newGroupManager] = group;
    }

    // TODO get ID from msg.sender
    function setIdentityHolder(address newIdentityHolder)  external {
        uint160 identity = holderToIdentity[msg.sender];
        address currentHolder = identities[identity].holder;
        identities[identity].holder = newIdentityHolder;
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
        require(identities[path[0]].holder == msg.sender,
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
        require(holder == identities[path[0]].holder,
            "the holder address doesn't own the id");
        require(groups[path[path.length-1]].manager == msg.sender, 
            "the last group in the path is not managed by the msg.sender");
        return (_memberScore(path));
    }

    // only for dapps
    function userScore(address holder, uint160[] calldata path)
        external
        // TODO onlyValidPath
        
        returns(uint256)
    {
        require(holder == identities[path[0]].holder,
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
        require(identities[path[0]].holder == msg.sender, "msg.sender is not identity holder");
        
        // get scores along the path (checks validity too)
        uint256[] memory scores = new uint256[](path.length);
        scores = _scores(path);

        // pay rewards
        uint160 bot = path[0];
        address botOwner = identities[bot].holder;  
        uint160 group;
        for (uint i = 0; i<=path.length-2; i++) {
            group = path[i+1];
            IPool(groups[group].pool).payBotReward(botOwner, scores[i]); // $$$
            }

        // explode
        delete groups[path[1]].trust[bot]; // delete bot score in the above group
        delete identities[bot];
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

            require (groups[group].trust[member] > 0, "Not a member");
            
            memberReward = groups[group].botReward * groups[group].trust[member] / 100; // TODO overflow-safe mul!
            require(IPool(groups[group].pool).hasEnoughFunds(memberReward), "A group in path is unable to pay declared bot reward.");
            scores[i] = memberReward;
        }

        return scores;
    }




    /************
    MANAGE GROUPS
    *************/
    /*
    Group admin - is any entity in control of a group.
    A group may decide to chose a trusted person, or it may make decisions based on voting.*/

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

    // https://medium.com/swlh/exploring-commit-reveal-schemes-on-ethereum-c4ff5a777db8
    // https://solidity.readthedocs.io/en/v0.5.3/solidity-by-example.html#id2
    // https://gitcoin.co/blog/commit-reveal-scheme-on-ethereum/


    /*Changes that may hurt bots rights*/

    // Sets the maximum possible bot reward for the group.
    function setBotReward(uint botReward, bytes32 secret) external {
        uint160 group = managerToGroup[msg.sender];
        bytes32 hash = checkHash(keccak256(abi.encodePacked("setBotReward", group, botReward)));
        groups[group].botReward = botReward;
        delete commitsTimestamps[hash];
        // emit Set("NewBotReward", group, botReward);
    }

    function setTrust(uint160 member, uint8 trust, bytes32 secret) external {
        uint160 group = managerToGroup[msg.sender];
        require (trust <= 100, "Provided trust percent is above 100");
        bytes32 hash = checkHash(keccak256(abi.encodePacked("setTrust", group, member, trust)));
        groups[group].trust[member] = trust;
        delete commitsTimestamps[hash];
        // emit Set("setBotnetLimit", hash);
    }

    function attachPool(address pool, bytes32 secret) external {
        uint160 group = managerToGroup[msg.sender];
        bytes32 hash = checkHash(keccak256(abi.encodePacked("attachPool", group, pool)));
        groups[group].pool = pool;
        delete commitsTimestamps[hash];
    }

    function withdrawFromPool(address recipient, uint amount, bytes32 secret) external { // $$$
        uint160 group = managerToGroup[msg.sender];
        bytes32 hash = checkHash(keccak256(abi.encodePacked("withdrawFromPool", group, recipient, amount)));
        // tries to withdraw as much as possible (bots could have attacked after an announcement)
        IPool(groups[group].pool).withdrawAvailable(group, recipient, amount, 0);
        delete commitsTimestamps[hash];
        // emit Set("withdrawFromPool", withdrawed);
    }

    /*Changes that cannot hurt bots rights*/

    /**************
    GETTER FUNCTIONS
    ***************/

    function getBotReward(uint160 group) external view returns (uint) {
        return groups[group].botReward;
    }

    // returns upala identity id
    function myId() external view returns(uint160) {
        return holderToIdentity[msg.sender];
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

- gas costs for calculation and for the attack (consider path length limitation)
- invitations. what if a very expensive group adds a cheap group. Many could decide to explode
- loops in social graphs. is nonReentrant enough?
- who is the manager? it can set scores and it can be a member

*/
