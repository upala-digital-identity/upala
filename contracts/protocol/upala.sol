pragma solidity ^0.6.0;

/*/// WARNING

The code is under heavy developement

/// WARNING */

import "./i-upala.sol";
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
contract Upala is IUpala {
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
    uint attackWindow = 0 hours;  // 0 - for tests // TODO set to 1 hour at production

    // keep track of new groups, identities and pools ids
    uint160 entityCounter;

    // Managed by Upala admin
    mapping(address => bool) approvedPoolFactories;

    /***************************
    GROUPS, IDENTITIES AND POOLS
    ***************************/

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
        // Actual bot reward depends on identity score? TODO or maybe not.
        uint256 botReward;  // botReward  .. baseReward

        // [Member botReward within group] = botReward * trust / 100 
        mapping(uint160 => uint8) trust;  // limit, exposure, scoreMultiplier

        // every DApp gets credits of successfull score approvals for its users
        // removed for faster MVP (UIP-3)
        // mapping(address => uint256) appCredits;

        // Queue of execution? experiment
        uint256 annoucementNonce;
        uint256 lastExecutedAnnouncement;
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

    // Humans commit changes, this mapping stores hashes and timestamps
    // Any changes that can hurt bot rights must wait for an hour
    mapping(bytes32 => uint) commitsTimestamps;

    // Every pool spawned by approved Pool Factories
    mapping(address => uint160) poolsOwners;


    constructor () public {
        // todo
    }

    modifier onlyGroupManager(uint160 group) {
        require(groups[group].manager == msg.sender, "msg.sender is not group manager");
        _;
    }

    modifier onlyIdentityHolder(uint160 identity) {
        require(identities[identity].holder == msg.sender, "msg.sender is not identity holder");
        _;
    }



    /************************************
    REGISTER GROUPS, IDENTITIES AND POOLS
    ************************************/

    function newGroup(address groupManager, address poolFactory) external payable override(IUpala) returns (uint160, address) {
        require(msg.value == registrationFee, "Incorrect registration fee");  // draft
        entityCounter++;
        groups[entityCounter].manager = groupManager;
        groups[entityCounter].pool = _newPool(poolFactory, entityCounter);
        managerToGroup[groupManager] = entityCounter;
        return (entityCounter, groups[entityCounter].pool);
    }

    function newIdentity(address identityHolder) external payable override(IUpala) returns (uint160) {
        require(msg.value == registrationFee, "Incorrect registration fee");  // draft
        entityCounter++;
        identities[entityCounter].holder = identityHolder;
        holderToIdentity[identityHolder] = entityCounter;
        return entityCounter;
    }

    // created by approved pool factories
    // tokens are only stable USDs
    function newPool(address poolFactory, uint160 poolOwner) external payable override(IUpala) returns (address) {
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

    function setGroupManager(uint160 group, address newGroupManager) external onlyGroupManager(group) override(IUpala) {
        address currentManager = groups[group].manager;
        groups[group].manager = newGroupManager;
        delete managerToGroup[currentManager];
        managerToGroup[newGroupManager] = group;
    }

    function setIdentityHolder(uint160 identity, address newIdentityHolder)  external onlyIdentityHolder(identity) override(IUpala) {
        address currentHolder = identities[identity].holder;
        identities[identity].holder = newIdentityHolder;
        delete holderToIdentity[currentHolder];
        holderToIdentity[newIdentityHolder] = identity;
    }


    /*********************
    SCORING AND BOT ATTACK
    **********************/
    /*
    The score is first calculated off-chain and then approved on-chain.
    To approve one needs to publish a "path" from ....the topmost group
    (the one for which the score is being approved) down to the identity...reversed
    TODO cooment
    path is an array of addressess.
    */

    // only for users
    function myScore(uint160[] calldata path)
        external
        view
        // TODO onlyValidPath
        override(IUpala)
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
        override(IUpala)
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
        override(IUpala)
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
    // @note experimental. the exact attack algorithm to be approved later
    function attack(uint160[] calldata path)
        external
        override(IUpala)
        onlyIdentityHolder(path[0])  // first member in path must be an identity, managed by message sender
    {
        // get scores along the path (checks validity too)
        uint256[] memory scores = new uint256[](path.length);
        scores = _scores(path);

        uint160 bot = path[0];
        address botOwner = identities[bot].holder; 
        // pay rewards
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
    // TODO overflow safe
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
    ANNOUNCEMENTS
    *************/
    // Announcements prevent front-running bot-exposions. Groups must announce
    // in advance any changes that may hurt bots rights
    /*
    https://medium.com/swlh/exploring-commit-reveal-schemes-on-ethereum-c4ff5a777db8
    https://solidity.readthedocs.io/en/v0.5.3/solidity-by-example.html#id2
    https://gitcoin.co/blog/commit-reveal-scheme-on-ethereum/
    */
    // Used to check announcements
    // anyone can call announced functions after attack window to avoid false announcements
    // TODO hmmm... do we need to hash annoucements it all?
    function checkHash(bytes32 hash) internal view returns(bytes32){
        // check if the commit exists
        require(commitsTimestamps[hash] != 0, "Hash is not found");
        // check if an hour had passed
        require (commitsTimestamps[hash] + attackWindow <= now, "Attack window is not closed yet");
        return hash;
    }

    function announceBotReward(uint160 group, uint botReward) external onlyGroupManager(group) override(IUpala) returns (uint256) {
        groups[group].annoucementNonce++;
        bytes32 hash = keccak256(abi.encodePacked("setBotReward", group, botReward, groups[group].annoucementNonce));
        commitsTimestamps[hash] = now;
        // emit Announce("NewBotReward", msg.sender, botReward, hash)
        return groups[group].annoucementNonce;
    }

    function announceTrust(uint160 group, uint160 member, uint8 trust) external onlyGroupManager(group) returns (uint256) {
        require(member != group, "cannot assign trust to oneself");  // todo what about manager?
        groups[group].annoucementNonce++;
        bytes32 hash = keccak256(abi.encodePacked("trust", group, member, trust, groups[group].annoucementNonce));
        commitsTimestamps[hash] = now;
        // emit Announce("NewRewardstrust", msg.sender, member, trust, hash)
        return groups[group].annoucementNonce;
    }

    // TODO WARNING! any group can attach any pool.
    function announceAttachPool(uint160 group, address pool) external onlyGroupManager(group) override(IUpala) returns (uint256) {
        require(poolsOwners[pool] == group, "Pool is not owned by the group");
        groups[group].annoucementNonce++;
        bytes32 hash = keccak256(abi.encodePacked("attachPool", group, pool, groups[group].annoucementNonce));
        commitsTimestamps[hash] = now;
        return groups[group].annoucementNonce;
    }

    // TODO add recipient?
    // TODO only one active annoucement of a type? A group may generate many announcements in advance.
    function announceWithdrawFromPool(uint160 group, address recipient, uint amount) external onlyGroupManager(group) override(IUpala) returns (uint256) { // $$$
        groups[group].annoucementNonce++;
        bytes32 hash = keccak256(abi.encodePacked("withdrawFromPool", group, recipient, amount, groups[group].annoucementNonce));
        commitsTimestamps[hash] = now;
        // emit Announce("NewRewardsLimit", msg.sender, amount, hash)
        return groups[group].annoucementNonce;
    }




    /************
    MANAGE GROUPS
    *************/
    /*
    Group admin - is any entity in control of a group.
    A group may decide to chose a trusted person, or it may make decisions based on voting.*/


    /*Changes that may hurt bots rights*/
    // anyone can call pre-announced functions after the attack window to avoid false announcements

    // TODO function executeNextAnnouncement(uint160 group) external {}


    // AppCredits. Begin
    // Removed for faster MVP. (UIP-3)
    // function increaseAppCredit(address appAddress, uint256 amount) external override(IUpala){
    //     uint160 groupID = groupIDbyManager(msg.sender);
    //     // console.log("Increase app credit:", appAddress, groupID, amount);
    //     groups[groupID].appCredits[appAddress] = groups[groupID].appCredits[appAddress].add(amount);
    // }

    // function decreaseAppCredit(address appAddress, uint256 amount) external override(IUpala){
    //     uint160 groupID = groupIDbyManager(msg.sender);
    //     groups[groupID].appCredits[appAddress] = groups[groupID].appCredits[appAddress].sub(amount);
    // }

    // function appBalance(uint160 groupID, address appAddress) external view returns(uint256){
    //     // todo permissions (either group or dapp can access)
    //     // console.log("App balance:", appAddress, groupID, groups[groupID].appCredits[appAddress]);
    //     return groups[groupID].appCredits[appAddress];
    // }
    // AppCredits. End



    // Sets the maximum possible bot reward for the group.
    function setBotReward(uint160 group, uint botReward) external override(IUpala) {
        groups[group].lastExecutedAnnouncement++;
        bytes32 hash = checkHash(keccak256(abi.encodePacked("setBotReward", group, botReward, groups[group].lastExecutedAnnouncement)));
        groups[group].botReward = botReward;
        delete commitsTimestamps[hash];
        // emit Set("NewBotReward", hash);
    }

    // function setBotnetLimit(uint160 group, uint160 member, uint limit) external override(IUpala) {
    //     groups[group].lastExecutedAnnouncement++;
    //     bytes32 hash = checkHash(keccak256(abi.encodePacked("setBotnetLimit", group, member, limit, groups[group].lastExecutedAnnouncement)));
    //     groups[group].trust[member] = limit;
    //     delete commitsTimestamps[hash];
    //     // emit Set("setBotnetLimit", hash);
    // }

    function setTrust(uint160 group, uint160 member, uint8 trust) external {
        require (trust <= 100, "Provided trust percent is above 100");
        groups[group].lastExecutedAnnouncement++;
        bytes32 hash = checkHash(keccak256(abi.encodePacked("trust", group, member, trust, groups[group].lastExecutedAnnouncement)));
        groups[group].trust[member] = trust;
        delete commitsTimestamps[hash];
        // emit Set("setBotnetLimit", hash);
    }

    function attachPool(uint160 group, address pool) external override(IUpala) {
        groups[group].lastExecutedAnnouncement++;
        bytes32 hash = checkHash(keccak256(abi.encodePacked("attachPool", group, pool, groups[group].lastExecutedAnnouncement)));
        groups[group].pool = pool;
        delete commitsTimestamps[hash];
    }

    // this may fail due to insufficient funds. TODO what to do?
    function withdrawFromPool(uint160 group, address recipient, uint amount) external override(IUpala) { // $$$
        groups[group].lastExecutedAnnouncement++;
        bytes32 hash = checkHash(keccak256(abi.encodePacked("withdrawFromPool", group, recipient, amount, groups[group].lastExecutedAnnouncement)));
        // tries to withdraw as much as possible (bots could have attacked after an announcement)
        IPool(groups[group].pool).withdrawAvailable(group, recipient, amount, groups[group].lastExecutedAnnouncement);  // add nonce?
        delete commitsTimestamps[hash];
        // emit Set("withdrawFromPool", withdrawed);
    }

    /*Changes that cannot hurt bots rights*/

    /**************
    GETTER FUNCTIONS
    ***************/

    // A member of a group is either a group or an identity.
    // TODO if public, can outside contracts do without Upala?
    // Only group manager can access
    // function getBotnetLimit(uint160 group, uint160 member) external view onlyGroupManager(group) override(IUpala) returns (uint256) {
    //     //...
    //     return (groups[group].trust[member]);
    // }

    function getBotReward(uint160 group) external view override(IUpala) returns (uint) {
        return groups[group].botReward;
    }

    // returns upala identity id
    function myId() external view override(IUpala) returns(uint160) {
        return holderToIdentity[msg.sender];
    }

    function groupIDbyManager(address manager) internal view returns(uint160) {
        return managerToGroup[manager];
    }


    /************************
    UPALA PROTOCOL MANAGEMENT
    *************************/

    // TODO only admin
    function setapprovedPoolFactory(address poolFactory, bool isApproved) external override(IUpala) {
        approvedPoolFactories[poolFactory] = isApproved;
    }
    // registrationFee
    // maxPathLength
    // attackWindow
    // approvedPoolFactories
}


/* todo consider:

- gas costs for calculation and for the attack (consider path length limitation)
- invitations. what if a very expensive group adds a cheap group. Many could decide to explode
- loops in social graphs. is nonReentrant enough?
- who is the manager? it can set scores and it can be a member
- restirict pool size changes
- transfer identity ownership (minimal identity contract)
- Metacartel, moloch, humanity, aragon court,

done:
- front-runnig a bot attack

*/




