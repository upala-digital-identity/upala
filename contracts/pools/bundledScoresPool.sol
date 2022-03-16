pragma solidity ^0.8.0;

/* 
Every group manages its poool in it's own way.
The most important obligation of a group is to pay bot rewards.

BundledScoresPool is a pool that allows storing user scores off-chain.
There are two types of such pool: Signed scores pool and Merkle pool.

Merkle pool is for the nearest future. 
*/

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './i-pool.sol';
import '../protocol/upala.sol';
import 'hardhat/console.sol';

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

    // Bytes32 is used for compatibility with Merkle pools.
    function publishScoreBundleId(bytes32 newBundleId) 
        external 
        onlyOwner 
        returns (uint256) 
    {
        require(scoreBundleTimestamp[newBundleId] == 0, 
            'Score bundle id already exists');
        scoreBundleTimestamp[newBundleId] = block.timestamp;
        NewScoreBundleId(newBundleId, block.timestamp);
        return block.timestamp;
    }

    function updateMetadata(string calldata newMetadata) 
        external 
        onlyOwner 
    {
        metaData = newMetadata;
        MetaDataUpdate(newMetadata);
    }

    // the functions below affect bot rights (group managers can fron-run an 
    // exploding bot). For Merkle pool commit-reveal process is needed.
    // No way to mitigate that with signed scores pool, thus no commit-reveal

    function _setBaseScore(uint256 newBaseScore)
        internal
        onlyOwner
    {
        baseScore = newBaseScore;
        NewBaseScore(newBaseScore);
    }

    function _deleteScoreBundleId(bytes32 scoreBundleId) 
        internal 
        onlyOwner
    {
        delete scoreBundleTimestamp[scoreBundleId];
        ScoreBundleIdDeleted(scoreBundleId);
    }

    // tries to withdraw as much as possible 
    // (bots can attack after an announcement)
    // this is part of management
    // Merkle pools will require commit-reveal scheme for this
    function _withdrawFromPool(address receiver, uint256 amount) 
        internal 
        onlyOwner
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
        // event is triggered by DAI contract
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
        address caller,    // user address that shoots the verification call
        address upalaID,            // user Upala ID
        address scoreAssignedTo,    // the address or UpalaID used in bundle
        uint8 score,                // assigned score
        bytes32 bundleId,           // bundle hash (root if using Merkle pool)
        bytes memory proof    // a proof that verifies user score is in bundle
    ) private view returns (uint256) {

        require(scoreBundleTimestamp[bundleId] > 0, 
            "Provided score bundle does not exist or deleted");

        if (scoreAssignedTo == upalaID || scoreAssignedTo == caller) {
            upala.isOwnerOrDelegate(caller, upalaID);
        } else {  // scoreAssignedTo is caller delegate
            upala.isOwnerOrDelegate(scoreAssignedTo, upalaID);
        }
        
        // require(
        //     upala.isOwnerOrDelegate(caller, upalaID) ||  // todo if throws here, it will not go further (see upala.sol)
        //     upala.isOwnerOrDelegate(scoreAssignedTo, upalaID),  // a way to validate by address (UIP-22)
        //     "Not an owner or delegate."
        //     "Upala ID is exploded,"
        //     "or score bearing address is not associated with Upala ID");
        //     // todo or Upala ID is not created yet (if we remove it from this contract)

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
