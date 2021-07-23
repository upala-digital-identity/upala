pragma solidity ^0.6.0;


import "../libraries/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../libraries/openzeppelin-contracts/contracts/math/SafeMath.sol";
import "../libraries/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./i-pool-factory.sol";
import "./i-pool.sol";
import "../protocol/upala.sol";
import "hardhat/console.sol";
/*

Every group to manages its poool in it's own way.
Or even to share one pool among several groups.
*/


contract BasicPoolFactory {
    
    Upala public upala;

    address public upalaAddress;
    address public approvedTokenAddress;

    event NewPool(address newPoolAddress);

    constructor (address _upalaAddress, address _approvedTokenAddress) public {
        upalaAddress = _upalaAddress;
        upala = Upala(_upalaAddress);
        approvedTokenAddress = _approvedTokenAddress;
    }

    function createPool() external returns (address) {
        address newPoolAddress = address(new BasicPool(upalaAddress, approvedTokenAddress, msg.sender));
        require(upala.approvePool(newPoolAddress) == true, "Cannot approve new pool on Upala");
        NewPool(newPoolAddress);
        return newPoolAddress;
   }
}

// The most important obligation of a group is to pay bot rewards.
// MerkleTreePool
contract BasicPool is Ownable {
    using SafeMath for uint256;

    Upala public upala;
    IERC20 public approvedToken; // approved token contract reference

    /******
    SCORING
    ******/

    // base reward get multiplied by individual scores to get total score for each user
    // with base reward we can tweak all users scores simultaneously
    uint256 public baseScore;
    // merkle roots of trees storing scores
    mapping (bytes32 => uint256) public roots;

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

    // ####### Hackathon mocks begin ##########

    // a mock function before real Merkle is implemented
    function verifyHack() public returns(bool res) { 
        return true;
    }

    // a mock function before real Merkle is implemented
    function getRootHack(bytes32 sfsdf) public returns(uint res) {
        return 1;
    }

    // for DApps - hackathon mock
    function verifyUserScoreHack (address groupID, address identityID, address ownerOrDelegate, uint8 score, bytes32[] calldata proof) external returns (bool) {
        return true;
    }

    // ####### Hackathon mocks end ##########

    // 
    function userScore(address identityID, address userAddress, uint256 index, uint8 score, bytes32[] calldata proof) external returns (uint256) {
        // calculate score (and check validity)
        uint256 totalScore = _userScore(identityID, userAddress, index, score, proof);
        // todo fee to group
        return totalScore;
    }

    // multipass 
    function myScore(uint256 index, address identityID, uint8 score, bytes32[] calldata proof) external view returns (uint256) {
        
        // calculate score (and check validity)
        uint256 totalScore = _userScore(identityID, msg.sender, index, score, proof);

        return totalScore;
    }



    // Allows any identity to attack any group, run with the money and self-destruct.
    // todo no nonReentrant?
    function attack(address identityID, uint256 index, uint8 score, bytes32[] calldata proof)
        external
    {   
        console.log("hey");
        // calculate reward (and validity)
        uint256 reward = _userScore(identityID, msg.sender, index, score, proof);
        console.log(reward);
        // explode (delete id forever)
        upala.deleteID(identityID);

        // payout 💸
        _payBotReward(msg.sender, reward);
    }

    function hack_computeRoot(uint256 index, address identityID, uint8 score, bytes32[] calldata proof) external view returns (bytes32) {
        uint256 hack_score = uint256(score);
        bytes32 leaf = keccak256(abi.encodePacked(index, identityID, hack_score));
        return _computeRoot(proof, leaf);
    }

    function hack_leaf(uint256 index, address identityID, uint8 score, bytes32[] calldata proof) external view returns (bytes32) {
        uint256 hack_score = uint256(score);
        return  keccak256(abi.encodePacked(index, identityID, hack_score));
    }

    function _userScore(address identityID, address ownerOrDelegate, uint256 index, uint8 score, bytes32[] memory proof) private view returns (uint256){
        // check identity validity
        console.log("_userScore");
        require(upala.isOwnerOrDelegate(ownerOrDelegate, identityID), "Address doesn't own an ID or is exploded");
        // TODO check that pool balance is sufficient for explosion
        // check Merkle proof
        uint256 hack_score = uint256(score);
        bytes32 leaf = keccak256(abi.encodePacked(index, identityID, hack_score));
        console.logBytes32(leaf);
        bytes32 computedRoot = _computeRoot(proof, leaf);
        console.logBytes32(computedRoot);
        require (roots[computedRoot] > 0, 'MerkleDistributor: Invalid proof.');
        
        uint256 totalScore = baseScore * score;
        
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

    function deleteRoot(bytes32 root, bytes32 secret) external onlyOwner {
        bytes32 hash = keccak256(abi.encodePacked("deleteRoot", root, secret));
        checkHash(hash);
        require(commitsTimestamps[hash] > roots[root], "Commit is submitted before root");
        delete commitsTimestamps[hash];
        delete roots[root];
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
    function publishScoreBundle(bytes32 newRoot) external  {
        console.log("publishRoot");
        roots[newRoot] = now;
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

    function getRootTimestamp(bytes32 root) external returns (uint256) {
        return roots[root];
    }

    function groupBaseScore() external view returns (uint) {
        return baseScore;
    }
}