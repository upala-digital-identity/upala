pragma solidity ^0.5.0;

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

    function getBotReward(address) external view returns (uint) ;
    function getPoolSize(address) external view returns (uint);
    function isLocked(address) external view returns (bool);

    function getBotRewardsLimit(address, address) external view returns (uint8);

    function attack(address[] calldata, address payable, uint) external;
    // function rageQuit() external;
    
    function addFunds(uint) external;
    function withdrawFromPool(uint) external;
}


// The Upala ledger (protocol)
contract Upala is IUpala {
    using SafeMath for uint256;
    
    IERC20 public approvedToken;    // default = dai
    uint256 registrationFee = 1 wei;   // spam protection + susteinability

    // the maximum depth of hierarchy
    // ensures attack gas cost is always lower than block maximum.
    uint256 maxPathLength = 10;

    // any changes that hurt bots rights must be announced an hour in advance
    uint attackWindow = 1 hour;
    
    // keep track of new groups, users and pools ids
    uint256 entityCounter;

    // Groups are outside contracts with arbitary logic
    struct Group {

        // A group address within Upala is permanent. Ownership provides group upgradability  
        address owner;

        // Pools are created by Upala-approved pool factories
        // Each group may manage their own pool in their own way.
        // But they must be made deliberately vulnerable to bot attacks 
        address pool;

        // The most important obligation of a group is to pay bot rewards.
        // A group can set its own maximum bot reward
        // Actual bot reward depends on user score? TODO or maybe not.
        uint256 botReward;
        
        // A bot net reward. Limits maximum bot rewards for a group member
        // can be unlimited.
        // @dev Used to check membership when calculating score
        mapping(address => uint256) private botnetLimit; // TODO private?

        // A group may or may become a member of a superior group
        // true for accepting membership in a superior group
        mapping(address => bool) private acceptedInvitations;
    }
    // These addresses are permanent. Serve as IDs.
    mapping(address => Group) groups;
    
    // Users
    // Ensures that users and groups are different entities
    // Ensures that an exploded bot will never be able to get a score or explode again
    // Human, Individual, Identity
    struct User {
        bool exploded;
        address owner;  // wallet
    }
    mapping(address => User) users;
    
    // Internal Accounting - deprecated
    // A group's balance is its pool. Pools are deliberately vulnerable to bot attacks. W
    // A user balance is only used for a bot reward. 
    // mapping(address => uint) balances;
    
    // Humans commit changes, this mapping stores hashes and timestamps
    // Any changes that can hurt bot rights must wait for an hour
    mapping(bytes32 => uint) commitsTimestamps;
    
    // Managed by Upala admin
    mapping(address => bool) approvedPoolFactories;

    // Every pool spawned by approved Pool Factories
    mapping(address => bool) approvedPools;
    

    constructor (address _approvedToken) public {
        approvedToken = IERC20(_approvedToken);
    }
    

    // spam protection 
    // + self sustainability.
    // + separates Users from Groups
    
    modifier onlyGroups() {
        require(groups[msg.sender].registered == true);
        _;
    }
    
    // modifier onlyUsers() {
    //     require(users[msg.sender].registered == true);
    //     _;
    // }

    modifier onlyGroupOwner(address group) {
        require(groups[group].owner == msg.sender);
        _;
    }

    modifier onlyUserOwner(address user) {
        require(groups[user].owner == msg.sender);
        _;
    }



    /*******************************
    REGISTER GROUPS, USERS AND POOLS
    ********************************/
    
    // Nonce is enough, the address is used for internal housekeeping only
    function newEntityID() external returns (address) {
        entityCounter++;
        // TODO do we need an address or just uint160?
        return address(uint160(uint(keccak256(abi.encodePacked(entityCounter)))));
    }
    
    function newGroup(address groupOwner) external payable {
        require(msg.value == registrationFee);
        groups[newEntityID()].owner == groupOwner;
    }

    function newUser(address userOwner) external payable {
        require(msg.value == registrationFee);
        users[newEntityID()].owner == userOwner;
    }

    // created by approved pool factories
    // tokens are only stable USDs
    function newPool(address poolFactory, address poolOwner, address token) external payable {
        require(msg.value == registrationFee);
        require(approvedPoolFactories[poolFactory] == true);
        address newPool = poolFactory.createPool(poolOwner, token);
        approvedPools[newPool] == true;
    }

    function transferGroupOwnership(address group, address newOwner) external onlyGroupOwner(group) {
        groups[group].owner = newOwner;
    }

    function transferUserOwnership(address user, address newOwner)  external onlyUserOwner(user) {
        users[user].owner = newOwner;
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
    function checkHash(bytes32 hash) returns(bool) internal view returns(bytes32){
        // check if the commit exists
        require(commitsTimestamps[hash] != 0);
        // check if an hour had passed
        require (commitsTimestamps[hash] + attackWindow < now);
        return hash;
    }

    function announceBotReward(address group, uint botReward) external onlyGroupOwner(group) {
        bytes32 hash = keccak256(abi.encodePacked("setBotReward", msg.sender, botReward)));
        commitsTimestamps[hash] = now;
        // emit Announce("NewBotReward", msg.sender, botReward, hash)
    }

    function announceBotnetLimit(address group, address member, uint limit) external onlyGroupOwner(group) {
        require(member != msg.sender);  // cannot be member of self. todo what about owner? 
        bytes32 hash = keccak256(abi.encodePacked("setBotnetLimit", msg.sender, member, limit));
        commitsTimestamps[hash] = now;
        // emit Announce("NewRewardsLimit", msg.sender, member, limit, hash)
    }

    function announceAttachPool(address group, address group, address pool) external onlyGroupOwner(group) {
        require(approvedPools[pool] == true);
        bytes32 hash = keccak256(abi.encodePacked("attachPool", group, pool)));
        commitsTimestamps[hash] = now;
    }

    // TODO add recipient?
    function announceWithdrawFromPool(address group, address recipient, uint amount) external onlyGroupOwner(group) { // $$$
        bytes32 hash = keccak256(abi.encodePacked("withdrawFromPool", group, recipient, amount));
        commitsTimestamps[hash] = now;
        // emit Announce("NewRewardsLimit", msg.sender, amount, hash)
    }




    /************
    MANAGE GROUPS
    *************/
    /*
    Group admin - is any entity in control of a group. 
    A group may decide to chose a trusted person, or it may make decisions based on voting.*/


    /*Functions that may hurt bots rights*/

    // Sets the maximum possible bot reward for the group.
    function setBotReward(address group, uint botReward) external {
        hash = checkHash(keccak256(abi.encodePacked("setBotReward", group, botReward)));
        groups[group].botReward = botReward;
        delete commitsTimestamps[hash];
        // emit Set("NewBotReward", hash);
    }

    function setBotnetLimit(address group, address member, uint limit) external {
        hash = checkHash(keccak256(abi.encodePacked("setBotnetLimit", group, member, limit)));
        groups[msg.sender].botnetLimit[member] = limit;
        delete commitsTimestamps[hash];
        // emit Set("setBotnetLimit", hash);
    }

    function attachPool(address group, address pool) external {
        hash = checkHash(keccak256(abi.encodePacked("attachPool", group, pool)));
        groups[group].pool = pool;
        delete commitsTimestamps[hash];
    }

    // this may fail due to insufficient funds. TODO what to do?
    function withdrawFromPool(address group, address recipient, uint amount) external { // $$$
        hash = checkHash(keccak256(abi.encodePacked("withdrawFromPool", group, recipient, amount)));
        // try to withdraw as much as possible (bots could have attacked after announcement)
        withdrawed = groups[group].pool.tryWithdrawal(recipient, amount);
        delete commitsTimestamps[hash];
        // emit Set("withdrawFromPool", withdrawed);
    }

    /*Cannot hurt bots rights*/

    // + additional spam protection
    function acceptInvitation(address group, address superiorGroup, bool isAccepted) external onlyGroupOwner(group) {
        require(superiorGroup != msg.sender);
        groups[msg.sender].acceptedInvitations[superiorGroup] = isAccepted;
    }



    /*********************
    SCORING AND BOT ATTACK
    **********************/
    /*
    The score is first calculated off-chain and then approved on-chain.
    To approve one needs to publish a "path" from ....the topmost group
    (the one for which the score is being approved) down to the user...reversed
    TODO cooment
    path is an array of addressess. 
    */

    function _isValidPath(address[] calldata path) internal returns(bool) {
        // todo what is valid path length
        require(path.length !=0, "path too short");
        require(path.length <= maxPathLength, "path too long");

        //TODO check invitations?

        // check the path from user to the top
        for (uint i=0; i<=path.length-2; i++) {
            member = path[i];
            group = path[i+1];
            // reqiure(balances[group] >= groups[group].botReward);
            require(groups[group].pool.hasEnoughFunds(groups[group].botReward));

            reqiure(groups[group].botnetLimit[member] >= groups[group].botReward); 
        }
    }
    

    // Ascends the path in groups hierarchy and confirms user score (path validity)
    // TODO overflow safe
    function _memberScore(address[] calldata path) private view returns(uint) {
        require (_isValidPath(path));
        return groups[path[path.length-1]].botReward;
    }


    function memberScore(address[] calldata path) external view onlyGroups returns(uint) {
        // the topmost group must be msg.sender
        require(path[path.length-1] == msg.sender);
        return _memberScore(path);
    }

    // Allows any user to attack any group, run with the money and self-destruct.
    // Only those with scores will succeed.
    // todo no nonReentrant?
    // @note experimental. the exact attack algorithm to be approved later
    function attack(address[] calldata path) external {
        
        address bot = msg.sender;
        require(path[0] == bot);
        require(users[bot].exploded == false, "bot already exploded");

        // calculates reward and checks path
        uint unpaidBotReward = _memberScore(path);
        
        // ascend the path and payout rewards
        for (uint i=0; i<=path.length-2; i++) {

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
                
                // transfer to user (bot)
                // balances[group].sub(reward);  // $$$
                // balances[bot].add(reward); // $$$
                groups[group].pool.payBotReward(bot, reward);

                // reduce botnetLimit for the member in the sup group
                // @dev botnetLimit[member] >= botReward is checked when validating path
                groups[group].botnetLimit[member].sub(reward); // $$$
            }
        }

        // explode
        users[bot].exploded = true;
    }

    
    /**************
    GETTER FUNCTIONS
    ***************/
    
    // A member of a group is either a roup or a user.
    // TODO if public, can outside contracts do without Upala?
    // Only group owner can access
    function getBotnetLimit(address group, address member) external view onlyGroupOwner returns (uint8) {
        //...
        return (groups[group].botnetLimit[member]);
    }
    
    function getBotReward(address group) external view returns (uint) {
        return groups[group].botReward;
    }
    
    function getPoolSize(address group) external view returns (uint) {
        return balances[group];
    }
    
    // function isLocked(address group) external view returns (bool) {
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
- who is the owner? it can set scores and it can be a member
- restirict pool size changes 
- transfer user ownership (minimal user contract)
- Metacartel, moloch, humanity, aragon court, 

done:
- front-runnig a bot attack

*/




