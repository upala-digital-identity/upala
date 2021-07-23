pragma solidity ^0.6.0;


import "../libraries/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../libraries/openzeppelin-contracts/contracts/math/SafeMath.sol";
import "../libraries/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../libraries/openzeppelin-contracts/contracts/cryptography/ECDSA.sol";
import "./i-pool-factory.sol";
import "./i-pool.sol";
import "../protocol/upala.sol";
import "hardhat/console.sol";
/*

Every group to manages its poool in it's own way.
Or even to share one pool among several groups.
*/

// production todo create IPool
contract SignedScoresPoolFactory {
    
    Upala public upala;
    address public upalaAddress;
    address public approvedTokenAddress;

    event NewPool(address newPoolAddress);

    constructor (address _upalaAddress, address _approvedTokenAddress) public {
        upalaAddress = _upalaAddress;
        upala = Upala(_upalaAddress);
        approvedTokenAddress = _approvedTokenAddress;
    }
    // todo title, baseScore, type
    function createPool() external returns (address) {
        address newPoolAddress = address(new SignedScoresPool(upalaAddress, approvedTokenAddress, msg.sender));
        require(upala.approvePool(newPoolAddress) == true, "Cannot approve new pool on Upala");
        NewPool(newPoolAddress);
        return newPoolAddress;
   }
}

// The most important obligation of a group is to pay bot rewards.
contract SignedScoresPool is Ownable {
    using SafeMath for uint256;
    using ECDSA for bytes32;


    Upala public upala;
    IERC20 public approvedToken; // approved token contract reference

    // Metadata
    string public poolType;  // auto-assigned by pool factory
    /* metadata:{
        title,
        url,
        joinLink,
        dbUrl
        } */

    string public metaData;  // json object for future use


    /******
    SCORING
    ******/

    // base reward get multiplied by individual scores to get total score for each user
    // with base reward we can tweak all users scores simultaneously
    uint256 public baseScore;
  
    mapping (bytes32 => uint256) public scoreBundles;

    /************
    ANNOUNCEMENTS
    *************/

    // Any changes that can hurt bot rights must wait for an attackWindow to expire
    mapping(bytes32 => uint) public commitsTimestamps;

    /*****
    EVENTS
    *****/

    event Claimed(
        uint256 _index,
        address _identity,
        uint256 _score
    );

    constructor(address upalaAddress, address approvedTokenAddress, address poolManager) public {
        baseScore = 1;
        upala = Upala(upalaAddress);
        approvedToken = IERC20(approvedTokenAddress);
        transferOwnership(poolManager);
        
    }

    /*********************
    SCORING AND BOT ATTACK
    **********************/

    // tests only for now
    function myScore(address identityID, uint8 score, bytes calldata signature) external view returns (uint256) {
        
        // calculate score (and check validity)
        uint256 totalScore = _userScore(msg.sender, identityID, score, signature);

        return totalScore;
    }

    // dapps 
    function userScore(address userAddress, address identityID, uint8 score, bytes calldata signature) external view returns (uint256) {
        
        // calculate score (and check validity)
        uint256 totalScore = _userScore(userAddress, identityID, score, signature);

        return totalScore;
    }

    // Allows any identity to attack any group, run with the money and self-destruct.
    // todo no nonReentrant?
    function attack(address identityID, uint8 score, bytes calldata signature)
        external
    {   
        console.log("hey");
        // calculate reward (and validity)
        uint256 reward = _userScore(msg.sender, identityID, score, signature);
        console.log(reward);
        // explode (delete id forever)
        upala.deleteID(identityID);

        // payout 💸
        _payBotReward(msg.sender, reward);
    }

    function _userScore(address ownerOrDelegate, address identityID, uint8 score, bytes memory signature) private view returns (uint256){
        // check identity validity
        require(upala.isOwnerOrDelegate(ownerOrDelegate, identityID), "Address doesn't own an ID or is exploded");
        // TODO check that pool balance is sufficient for explosion
        // todo security check (see ECDSA.sol, https://solidity-by-example.org/signature/)
        // https://ethereum.stackexchange.com/questions/76810/sign-message-with-web3-and-verify-with-openzeppelin-solidity-ecdsa-sol
        // https://docs.openzeppelin.com/contracts/2.x/utilities        
        // check signature
        uint256 version = 1;
        // bytes32 hash = ;
        // bytes32 ethHash = ;
        require (keccak256(abi.encodePacked(identityID, score, version))
            .toEthSignedMessageHash()
            .recover(signature) == owner(), 
            'Invalid signature or signer is not group owner'
        );
        
        uint256 totalScore = baseScore * score; // todo overflow safe
        
        return totalScore;
    }
    

    /***********
    MANAGE GROUP
    ************/

    /*Announcements*/
    // Announcements prevents front-running bot-exposions. Groups must announce
    // in advance any changes that may hurt bots rights

    // hash = keccak256(action-type, [parameters], secret)
    function commitHash(bytes32 hash) external onlyOwner returns(uint256 timestamp)  {
        uint256 timestamp = now;
        commitsTimestamps[hash] = timestamp;
        return timestamp;
    }
 
    function checkHash(bytes32 hash) internal view returns(bool){
        
        require (commitsTimestamps[hash] != 0, "No such commitment hash");
        require (commitsTimestamps[hash] + upala.attackWindow() <= now, "Attack window is not closed yet");
        require (commitsTimestamps[hash] + upala.attackWindow() + upala.executionWindow() >= now, "Execution window is already closed");
        // todo is it possible to create lock for active commits when changing windows?
        return true;
    }

    /*Changes that may hurt bots rights*/

    // Sets the maximum possible bot reward for the group.
    function setBaseScore(uint botReward, bytes32 secret) external onlyOwner {
        bytes32 hash = keccak256(abi.encodePacked("setBaseScore", botReward, secret));
        // todo not checknig hash timestamp
        checkHash(hash);
        baseScore = botReward;
        delete commitsTimestamps[hash];
        // emit Set("NewBotReward", group, botReward);
    }

    function deleteScoreBundle(bytes32 scoreBundle, bytes32 secret) external onlyOwner {
        bytes32 hash = keccak256(abi.encodePacked("deleteScoreBundle", scoreBundle, secret));
        checkHash(hash);
        require(commitsTimestamps[hash] > scoreBundles[scoreBundle], "Commit is submitted before scoreBundle");
        delete commitsTimestamps[hash];
        delete scoreBundles[scoreBundle];
    }

    // tries to withdraw as much as possible (bots could have attacked after an announcement) 
    function withdrawFromPool(address recipient, uint amount, bytes32 secret) external onlyOwner returns (uint256){ // $$$
        bytes32 hash = keccak256(abi.encodePacked("withdrawFromPool", secret));
        checkHash(hash);
        uint256 withdrawnAmount = _withdrawAvailable(recipient, amount);
        delete commitsTimestamps[hash];
        // emit Set("withdrawFromPool", withdrawed);
        return withdrawnAmount;
    }

    /*Changes that don't hurt bots rights*/

    function increaseBaseScore(uint newBotReward) external onlyOwner {
        require (newBotReward > baseScore, "To decrease score, make a commitment first");
        baseScore = newBotReward;
    }

    // todo onlyOwner
    // Score bundle ids are generated by the contract. 
    // we don't need to care about block hash manipulation, we could 
    // similary use incremented numbers. Hashes are used for compatibility 
    // with Merkle pools. 
    function publishScoreBundle() external returns (bytes32) {
        bytes32 newScoreBundle = blockhash(block.number);
        scoreBundles[newScoreBundle] = now;
        return newScoreBundle;
    }

    // function upgradePool(address poolFactory, bytes32 secret) external returns (address, uint256) {
    // }


    /****
    FUNDS
    *****/

    // Upala checks funds to make sure the pool has enough funds to fund a bot attack
    function hasEnoughFunds(uint256 ammount) private view returns(bool) {
        return (approvedToken.balanceOf(address(this)) >= ammount);
    }

    // bots are getting paid instantly
    function _payBotReward(address bot, uint amount) private returns(bool)  {
        require(_withdraw(bot, amount), "token transfer to bot failed");
        return true;
    }

    function _withdrawAvailable(address receiver, uint256 amount) private returns (uint256 whitdrawnAmount) {
        uint256 balance = approvedToken.balanceOf(address(this));
        if (balance >= amount) {
            _withdraw(receiver, amount);
            return amount;
        } else {
            _withdraw(receiver, balance);
            return balance;
        }
    }

    function _withdraw(address recipient, uint amount) private returns (bool) {
        return approvedToken.transfer(recipient, amount);
    }

    /**************
    GETTER FUNCTIONS
    ***************/

    function getScoreBundleTimestamp(bytes32 scoreBundle) external returns (uint256) {
        return scoreBundles[scoreBundle];
    }

    function groupBaseScore() external view returns (uint) {
        return baseScore;
    }

    /***************
    DAPP INTEGRATION
    ****************/

    // DApps need to call this on every pool they want to approve
    // this may be chargable 
    function registerDapp() external {
        // check if dapp lib version is compatible with this pool type
        // emit DappRegistered
    }

    function unregisterDapp() external {

    }
}