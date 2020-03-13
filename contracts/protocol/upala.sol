pragma solidity ^0.6.0;

/*/// WARNING

The code is under heavy developement

/// WARNING */

import "../oz/token/ERC20/ERC20.sol";
import "../oz/math/SafeMath.sol";
// import "@openzeppelin/contracts/ownership/Ownable.sol";  // production


/*

The Upala contract is the protocol itself.
Identity systems can use this contract to comply with universal bot explosion rules.
These identity systems will then be compatible.

Upala-native identity systems are presumed to consist of groups of many levels.
Each group is a smart contract with arbitary logic.


*/

contract IUpala {

    function getBotReward(uint160) external view returns (uint);
    function getPoolSize(uint160) external view returns (uint);
    function isLocked(uint160) external view returns (bool);

    function getBotRewardsLimit(uint160, uint160) external view returns (uint8);

    function attack(uint160[] calldata) external;
    // function rageQuit() external;

    function addFunds(uint) external;
    function withdrawFromPool(uint) external;
}


// The Upala ledger (protocol)
contract Upala is IUpala {
    using SafeMath for uint256;

    /*******
    SETTINGS
    ********/

    uint256 registrationFee = 1 wei;   // spam protection + susteinability

    // the maximum depth of hierarchy
    // ensures attack gas cost is always lower than block maximum.
    uint256 maxPathLength = 10;

    // any changes that hurt bots rights must be announced an hour in advance
    uint attackWindow = 1 hours;

    // keep track of new groups, identities and pools ids
    uint160 identitiesCounter;
    uint160 groupsCounter;

    // Managed by Upala admin
    mapping(address => bool) approvedPoolFactories;

    /***************************
    GROUPS, IDENTITIES AND POOLS
    ***************************/

    // Groups are outside contracts with arbitary logic
    struct Group {

        // A group address within Upala is permanent. Ownership provides group upgradability

        // Pools are created by Upala-approved pool factories
        // Each group may manage their own pool in their own way.
        // But they must be made deliberately vulnerable to bot attacks
        address pool;

        // The most important obligation of a group is to pay bot rewards.
        // A group can set its own maximum bot reward
        // Actual bot reward depends on identity score? TODO or maybe not.
        uint256 botReward;

        // A bot net reward. Limits maximum bot rewards for a group member
        // can be unlimited.
        // @dev Used to check membership when calculating score
        mapping(uint160 => uint256) botnetLimit;

        // A group may or may become a member of a superior group
        // true for accepting membership in a superior group
        mapping(uint160 => bool) acceptedInvitations;

        // Queue of execution? experiment
        uint256 annoucementNonce;
        uint256 lastExecutedAnnouncement;
    }
    // These addresses are permanent. Serve as IDs.
    mapping(uint160 => Group) groups;

    // Identities
    // Ensures that identities and groups are different entities
    // Ensures that an exploded bot will never be able to get a score or explode again
    // Human, Individual, Identity
    struct Identity {
        bool exploded;
        address manager;  // wallet, manager, owner
    }
    mapping(uint160 => Identity) identities;

    // Humans commit changes, this mapping stores hashes and timestamps
    // Any changes that can hurt bot rights must wait for an hour
    mapping(bytes32 => uint) commitsTimestamps;

    // Every pool spawned by approved Pool Factories
    mapping(address => bool) approvedPools;


    constructor () public {
        // todo
    }

    modifier onlyGroupManager(uint160 group) {
        require(groups[group].manager == msg.sender, "msg.sender is not group manager");
        _;
    }

    modifier onlyIdentityManager(uint160 identity) {
        require(groups[identity].manager == msg.sender, "msg.sender is not identity manager");
        _;
    }



    /************************************
    REGISTER GROUPS, IDENTITIES AND POOLS
    ************************************/

    function newGroup(address groupManager) external payable returns (uint160) {
        require(msg.value == registrationFee, "Incorrect registration fee");  // draft
        groupsCounter++;
        groups[groupsCounter].manager = groupManager;
        return groupsCounter;
    }

    function newIdentity(address identityManager) external payable returns (uint160) {
        require(msg.value == registrationFee, "Incorrect registration fee");  // draft
        identitiesCounter++;
        identities[identitiesCounter].manager = identityManager;
        return identitiesCounter;
    }

    // created by approved pool factories
    // tokens are only stable USDs
    function newPool(address poolFactory, address poolOwner, address token) external payable returns (address) {
        require(msg.value == registrationFee, "Incorrect registration fee");  // draft
        require(approvedPoolFactories[poolFactory] == true, "Pool factory is not approved");
        // require PoolOwner exists // todo?
        address newPoolAddress = poolFactory.createPool(poolOwner, token);
        approvedPools[newPoolAddress] = true;
        return newPoolAddress;
    }

    function setGroupManager(uint160 group, address newGroupManager) external onlyGroupManager(group) {
        groups[group].manager = newGroupManager;
    }

    function setIdentityManager(uint160 identity, address newIdentityManager)  external onlyIdentityManager(identity) {
        identities[identity].manager = newIdentityManager;
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

    function memberScore(uint160[] calldata path)
        external
        view
        onlyGroupManager(path[path.length-1])  // the last group in path must be managed by the msg.sender
        returns(uint)
    {
        return _memberScore(path);
    }

    // Allows any identity to attack any group, run with the money and self-destruct.
    // Only those with scores will succeed.
    // todo no nonReentrant?
    // @note experimental. the exact attack algorithm to be approved later
    function attack(uint160[] calldata path)
        external
        onlyIdentityManager(path[0])  // first member in path must be an identity, managed by message sender
    {
        uint160 bot = path[0];
        require(identities[bot].exploded == false, "bot already exploded");

        // calculates reward and checks path
        uint unpaidBotReward = _memberScore(path);

        // ascend the path and payout rewards
        for (uint i = 0; i<=path.length-2; i++) {

            member = path[i];
            group = path[i+1];

            // check if the reward is already payed out
            if (unpaidBotReward > 0) {

                groupBotReward = groups[group].botReward;

                if (unpaidBotReward >= groupBotReward) {
                    reward = groupBotReward;
                    unpaidBotReward.sub(reward);
                } else {
                    reward = unpaidBotReward;
                    unpaidBotReward = 0;
                }

                // transfer to identity (bot)
                // balances[group].sub(reward);  // $$$
                // balances[bot].add(reward); // $$$
                groups[group].pool.payBotReward(bot, reward);

                // reduce botnetLimit for the member in the sup group
                // @dev botnetLimit[member] >= botReward is checked when validating path
                groups[group].botnetLimit[member].sub(reward); // $$$
            }
        }

        // explode
        identities[bot].exploded = true;
    }

    // Ascends the path in groups hierarchy and confirms identity score (path validity)
    // TODO overflow safe
    function _memberScore(uint160[] calldata path) private view returns(uint) {
        require (_isValidPath(path), "Provided path is not valid");
        return groups[path[path.length-1]].botReward;
    }

    function _isValidPath(uint160[] calldata path) private view returns(bool) {
        // todo what is valid path length
        require(path.length != 0, "path too short");
        require(path.length <= maxPathLength, "path too long");

        //TODO check invitations?

        // check the path from identity to the top
        for (uint i = 0; i<=path.length-2; i++) {
            member = path[i];
            group = path[i+1];
            // reqiure(balances[group] >= groups[group].botReward);
            require(groups[group].pool.hasEnoughFunds(groups[group].botReward), "A group in path is unable to pay declared bot reward.");
            reqiure(groups[group].botnetLimit[member] >= groups[group].botReward);
        }
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
        require (commitsTimestamps[hash] + attackWindow < now, "Attack window is not closed yet");
        return hash;
    }

    function announceBotReward(uint160 group, uint botReward) external onlyGroupManager(group) returns (uint256) {
        groups[group].annoucementNonce++;
        bytes32 hash = keccak256(abi.encodePacked("setBotReward", msg.sender, botReward, groups[group].annoucementNonce));
        commitsTimestamps[hash] = now;
        // emit Announce("NewBotReward", msg.sender, botReward, hash)
        return groups[group].annoucementNonce;
    }

    function announceBotnetLimit(uint160 group, uint160 member, uint limit) external onlyGroupManager(group) returns (uint256) {
        require(member != msg.sender, "cannot assign limit to oneself");  // todo what about manager?
        groups[group].annoucementNonce++;
        bytes32 hash = keccak256(abi.encodePacked("setBotnetLimit", msg.sender, member, limit, groups[group].annoucementNonce));
        commitsTimestamps[hash] = now;
        // emit Announce("NewRewardsLimit", msg.sender, member, limit, hash)
        return groups[group].annoucementNonce;
    }

    function announceAttachPool(uint160 group, address pool) external onlyGroupManager(group) returns (uint256) {
        require(approvedPools[pool] == true, "Pool is not approved");
        groups[group].annoucementNonce++;
        bytes32 hash = keccak256(abi.encodePacked("attachPool", group, pool, groups[group].annoucementNonce));
        commitsTimestamps[hash] = now;
        return groups[group].annoucementNonce;
    }

    // TODO add recipient?
    // TODO only one active annoucement of a type? A group may generate many announcements in advance.
    function announceWithdrawFromPool(uint160 group, address recipient, uint amount) external onlyGroupManager(group) returns (uint256) { // $$$
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

    // Sets the maximum possible bot reward for the group.
    function setBotReward(uint160 group, uint botReward) external {
        groups[group].lastExecutedAnnouncement++;
        hash = checkHash(keccak256(abi.encodePacked("setBotReward", group, botReward,groups[group].lastExecutedAnnouncement)));
        groups[group].botReward = botReward;
        delete commitsTimestamps[hash];
        // emit Set("NewBotReward", hash);
    }

    function setBotnetLimit(uint160 group, uint160 member, uint limit) external {
        groups[group].lastExecutedAnnouncement++;
        hash = checkHash(keccak256(abi.encodePacked("setBotnetLimit", group, member, limit, groups[group].lastExecutedAnnouncement)));
        groups[msg.sender].botnetLimit[member] = limit;
        delete commitsTimestamps[hash];
        // emit Set("setBotnetLimit", hash);
    }

    function attachPool(uint160 group, address pool) external {
        groups[group].lastExecutedAnnouncement++;
        hash = checkHash(keccak256(abi.encodePacked("attachPool", group, pool, groups[group].lastExecutedAnnouncement)));
        groups[group].pool = pool;
        delete commitsTimestamps[hash];
    }

    // this may fail due to insufficient funds. TODO what to do?
    function withdrawFromPool(uint160 group, address recipient, uint amount) external { // $$$
        groups[group].lastExecutedAnnouncement++;
        hash = checkHash(keccak256(abi.encodePacked("withdrawFromPool", group, recipient, amount, groups[group].lastExecutedAnnouncement)));
        // tries to withdraw as much as possible (bots could have attacked after an announcement)
        groups[group].pool.withdrawAvailable(group, recipient, amount, groups[group].lastExecutedAnnouncement);  // add nonce?
        delete commitsTimestamps[hash];
        // emit Set("withdrawFromPool", withdrawed);
    }

    /*Changes that cannot hurt bots rights*/

    // + additional spam protection
    function acceptInvitation(uint160 group, uint160 superiorGroup, bool isAccepted) external onlyGroupManager(group) {
        require(superiorGroup != msg.sender, "CAnnot accept invitations from oneself");
        groups[msg.sender].acceptedInvitations[superiorGroup] = isAccepted;
    }




    /**************
    GETTER FUNCTIONS
    ***************/

    // A member of a group is either a group or an identity.
    // TODO if public, can outside contracts do without Upala?
    // Only group manager can access
    function getBotnetLimit(uint160 group, uint160 member) external view onlyGroupManager returns (uint8) {
        //...
        return (groups[group].botnetLimit[member]);
    }

    function getBotReward(uint160 group) external view returns (uint) {
        return groups[group].botReward;
    }

    function getPoolSize(uint160 group) external view returns (uint) {
        return balances[group];
    }

    // function isLocked(uint160 group) external view returns (bool) {
    //     return groups[group].locked;
    // }

    /************************
    UPALA PROTOCOL MANAGEMENT
    *************************/

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




