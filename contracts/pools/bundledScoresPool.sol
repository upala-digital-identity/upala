pragma solidity ^0.6.0;

import '../libraries/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import '../libraries/openzeppelin-contracts/contracts/math/SafeMath.sol';
import '../libraries/openzeppelin-contracts/contracts/access/Ownable.sol';
import './i-pool.sol';
import '../protocol/upala.sol';
import 'hardhat/console.sol';

/*

Every group to manages its poool in it's own way.
Or even to share one pool among several groups.
*/

// The most important obligation of a group is to pay bot rewards.
contract BundledScoresPool is Ownable {
    using SafeMath for uint256;

    Upala public upala;

    // Dai ERC20 token for the mainnet (fakeDAI for testing)
    IERC20 public approvedToken; // approved token contract reference

    // Metadata. e.g. { title, url, joinLink, dbUrl }
    string public metaData; // json object for future use

    /******
    SCORING
    ******/

    // Base reward gets multiplied by individual scores to get 
    // total score for each user.
    // With base reward we can tweak all users scores simultaneously
    uint256 public baseScore;

    // When verifying their score or exploding, users prove they are in a 
    // score bundle. 
    mapping(bytes32 => uint256) public scoreBundleTimestamp;

    /************
    ANNOUNCEMENTS
    *************/

    // Any changes that can hurt bot rights must wait for an attackWindow
    mapping(bytes32 => uint256) public commitsTimestamps;
    
    /*****
    EVENTS
    *****/

    event MetaDataUpdate(string metadata);
    event NewScoreBundleId(bytes32 newScoreBundleId, uint256 timestamp);
    event ScoreBundleIdDeleted(bytes32 newScoreBundleId);
    event NewBaseScore(uint256 newBaseScore);

    constructor(
        address upalaAddress,
        address approvedTokenAddress,
        address poolManager
    ) public {
        upala = Upala(upalaAddress);
        approvedToken = IERC20(approvedTokenAddress);
        transferOwnership(poolManager);
    }

    
    /***********
    MANAGE GROUP
    ************/

    /* Announcements */
    // Announcements prevents front-running bot-exposions. Groups must announce
    // in advance any changes that may hurt bots rights
    // hash = keccak256(action-type, [parameters], secret) - see below

    function commitHash(bytes32 hash) 
        external 
        onlyOwner 
        returns (uint256 timestamp) 
    {
        uint256 timestamp = now;
        commitsTimestamps[hash] = timestamp;
        return timestamp;
    }

    modifier hasValidCommit(bytes32 hash) {
        require(commitsTimestamps[hash] != 0, 
            'No such commitment hash');
        require(commitsTimestamps[hash] + upala.attackWindow() <= now, 
            'Attack window is not closed yet');
        require(
            commitsTimestamps[hash] + upala.attackWindow() + upala.executionWindow() >= now,
            'Execution window is already closed'
        );
        _;
        delete commitsTimestamps[hash];
    }

    /*Changes that may hurt bots rights (require an announcement)*/

    // todo should this apply to all commits?
    // require(scoreBundleTimestamp[scoreBundleId] > now + attackWindow, 
    // 'Commit is submitted before scoreBundleId');
    
    // Sets the the base score for the group.
    function setBaseScore(uint256 newBaseScore, bytes32 secret)
        external
        onlyOwner
        hasValidCommit(keccak256(abi.encodePacked(
            'setBaseScore', newBaseScore, secret)))
    {
        baseScore = newBaseScore;
        NewBaseScore(newBaseScore);
    }

    function deleteScoreBundleId(bytes32 scoreBundleId, bytes32 secret) 
        external 
        onlyOwner
        hasValidCommit(keccak256(abi.encodePacked(
            'deleteScoreBundleId', scoreBundleId, secret)))
    {
        delete scoreBundleTimestamp[scoreBundleId];
        ScoreBundleIdDeleted(scoreBundleId);
    }

    function withdrawFromPool(address recipient, uint256 amount, bytes32 secret) 
        external 
        onlyOwner
        hasValidCommit(keccak256(abi.encodePacked(
            'withdrawFromPool', secret)))
        returns (uint256) 
    {
        // event is triggered by DAI contract
        return _withdrawAvailable(recipient, amount);
    }

    /*Changes that don't hurt bots rights*/

    function increaseBaseScore(uint256 newBaseScore) external onlyOwner {
        require(newBaseScore > baseScore, 
            'To decrease score, make a commitment first');
        baseScore = newBaseScore;
        NewBaseScore(newBaseScore);
    }

    // Hashes are used for compatibility with Merkle pools.
    function publishScoreBundleId(bytes32 newBundleId) external onlyOwner returns (uint256) {
        require(scoreBundleTimestamp[newBundleId] == 0, 
            'Score bundle id already exists');
        scoreBundleTimestamp[newBundleId] = now;
        NewScoreBundleId(newBundleId, now);
        return now;
    }

    function updateMetadata(string calldata newMetadata) external onlyOwner {
        metaData = newMetadata;
        MetaDataUpdate(newMetadata);
    }

    /****
    FUNDS
    *****/

    // Upala checks funds to make sure the pool has enough funds for attack
    function _balanceIsAbove(uint256 ammount) private view returns (bool) {
        return (approvedToken.balanceOf(address(this)) >= ammount);
    }

    // bots are getting paid instantly
    function _payBotReward(address bot, uint256 amount) private {
        uint256 fee = amount.mul(upala.explosionFeePercent()).div(100);
        require(_withdraw(bot, amount.sub(fee)), 
            'Token transfer to bot failed');
        // UIP-6. Sustainability + mitigating withdrawals by explosion
        require(_withdraw(upala.treasury(), fee), 
            'Explosion fee transfer failed');
    }

    // tries to withdraw as much as possible 
    // (bots can attack after an announcement)
    function _withdrawAvailable(address receiver, uint256 amount) 
        private 
        returns (uint256 whitdrawnAmount) 
    {
        uint256 balance = approvedToken.balanceOf(address(this));
        if (balance >= amount) {
            _withdraw(receiver, amount);
            return amount;
        } else {
            _withdraw(receiver, balance);
            return balance;
        }
    }

    function _withdraw(address recipient, uint256 amount) private returns (bool) {
        return approvedToken.transfer(recipient, amount);
    }

    /***********
    DAPP PAYWALL
    ************/

    // modifier verificationFeeApplied() {
    //     require(paywall.charge(msg.sender, score));
    //     _;
    // }

    // modifier registrationFeeApplied() {
    //     require(paywall.chargeRegistration(msg.sender));
    //     _;
    // }

    // // Paywalls charge only DApps. They have their own balances.
    // // No need to prevent bot explosion front-run
    // function appendPaywall(address newPaywall) {
    //     require(upala.isApprovedPaywall(newPaywall) == true,
    //         "Paywall not approved");
    //     require(Paywall(newPaywall).append() == true,
    //         "Paywall denies pool");
    //     paywall = Paywall(newPaywall);
    // }

    /**************
    GETTER FUNCTIONS
    ***************/

    function getScoreBundleIdTimestamp(bytes32 scoreBundleId) external returns (uint256) {
        return scoreBundleTimestamp[scoreBundleId];
    }

    function groupBaseScore() external view returns (uint256) {
        return baseScore;
    }

    /*********************
    SCORING AND BOT ATTACK
    **********************/
    // Pool-specific 

    // tests only for now
    function myScore(
        address upalaID,
        address scoreAssignedTo,
        uint8 score,
        bytes32 bundleId,
        bytes calldata proof
    ) external view returns (uint256) {
        return _userScore(msg.sender, upalaID, scoreAssignedTo, score, bundleId, proof);
    }

    // dapps
    function userScore(
        address userAddress,
        address upalaID,
        address scoreAssignedTo,
        uint8 score,
        bytes32 bundleId,
        bytes calldata proof
    )
        external
        view
        /// production todo paywall modifier goes here
        returns (uint256)
    {
        return _userScore(userAddress, upalaID, scoreAssignedTo, score, bundleId, proof);
    }

    // Allows any identity to attack the group (pool), 
    // run with the money and self-destruct.
    function attack(
        address upalaID,
        address scoreAssignedTo,
        uint8 score,
        bytes32 bundleId,
        bytes calldata proof
    ) external {
        console.log('hey');

        // calculate reward (and validity)
        uint256 reward = _userScore(msg.sender, upalaID, scoreAssignedTo, score, bundleId, proof);

        // explode (delete id forever)
        upala.explode(upalaID);

        // payout 💸
        _payBotReward(msg.sender, reward);
    }

    function _userScore(
        address ownerOrDelegate,    // user address that shoots verification call
        address upalaID,            // user Upala ID
        address scoreAssignedTo,    // the address used in bundle
        uint8 score,                // assigned score
        bytes32 bundleId,           // bundle hash (root if using Merkle pool)
        bytes memory proof    // a proof that verifies user score is in bundle
    ) private view returns (uint256) {

        require(scoreBundleTimestamp[bundleId] > 0, 
            "Provided score bundle does not exist or deleted");

        require(upala.isOwnerOrDelegate(ownerOrDelegate, upalaID),
            "Not an owner or delegate. Or Upala ID is exploded");

        // a way to validate by address (UIP-22)
        // can still validate from any delegate address
        if (scoreAssignedTo != upalaID && scoreAssignedTo != ownerOrDelegate) {
            require(upala.isOwnerOrDelegate(scoreAssignedTo, upalaID),
                "Score bearing address is not associated with Upala ID");
        }

        uint256 totalScore = baseScore.mul(score);
        require(_balanceIsAbove(totalScore),
            "Pool balance is lower than the total score");


        require(isInBundle(scoreAssignedTo, score, bundleId, proof) == true,
            "Can't validate that scoreAssignedTo-score pair is in the bundle");

        return totalScore;
    }

    // Pool-specific way to validate that userID is in bundle
    function isInBundle(
        address intraBundleUserID,
        uint8 score,
        bytes32 bundleId,
        bytes memory proof
    ) internal view virtual returns (bool) {}
}
