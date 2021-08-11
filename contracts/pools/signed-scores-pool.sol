pragma solidity ^0.6.0;

import '../libraries/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import '../libraries/openzeppelin-contracts/contracts/math/SafeMath.sol';
import '../libraries/openzeppelin-contracts/contracts/access/Ownable.sol';
import '../libraries/openzeppelin-contracts/contracts/cryptography/ECDSA.sol';
import './i-pool-factory.sol';
import './i-pool.sol';
import '../protocol/upala.sol';
import 'hardhat/console.sol';

/*

Every group to manages its poool in it's own way.
Or even to share one pool among several groups.
*/

// production todo create IPool
contract SignedScoresPoolFactory {
    Upala public upala;
    address public upalaAddress;
    address public approvedTokenAddress;

    constructor(address _upalaAddress, address _approvedTokenAddress) public {
        upalaAddress = _upalaAddress;
        upala = Upala(_upalaAddress);
        approvedTokenAddress = _approvedTokenAddress;
    }

    function createPool() external returns (address) {
        address newPoolAddress = address(
            new SignedScoresPool(upalaAddress, approvedTokenAddress, msg.sender));

        require(upala.registerPool(newPoolAddress) == true, 
            'Cannot approve new pool on Upala');
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
    /* {
        title,
        url,
        joinLink,
        dbUrl
        } */
    string public metaData; // json object for future use

    /******
    SCORING
    ******/

    // base reward get multiplied by individual scores 
    // to get total score for each user
    // with base reward we can tweak all users scores simultaneously
    uint256 public baseScore;

    mapping(bytes32 => uint256) public scoreBundleIds;

    /************
    ANNOUNCEMENTS
    *************/

    // Any changes that can hurt bot rights must wait for an attackWindow
    mapping(bytes32 => uint256) public commitsTimestamps;

    // DApp integration
    mapping(address => bool) registeredDApps;

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
        baseScore = 1;
        upala = Upala(upalaAddress);
        approvedToken = IERC20(approvedTokenAddress);
        transferOwnership(poolManager);
    }

    /*********************
    SCORING AND BOT ATTACK
    **********************/

    // tests only for now
    function myScore(
        address uID,
        uint8 score,
        bytes32 bundleId,
        bytes calldata signature
    ) external view returns (uint256) {
        return _userScore(msg.sender, uID, score, bundleId, signature);
    }

    // Allows any identity to attack any group, 
    // run with the money and self-destruct.
    // production todo nonReentrant?
    function attack(
        address uID,
        uint8 score,
        bytes32 bundleId,
        bytes calldata signature
    ) external {
        console.log('hey');

        // calculate reward (and validity)
        uint256 reward = _userScore(msg.sender, uID, score, bundleId, signature);

        // explode (delete id forever)
        upala.explode(uID);

        // payout 💸
        _payBotReward(msg.sender, reward);
    }

    // dapps
    function userScore(
        address userAddress,
        address uID,
        uint8 score,
        bytes32 bundleId,
        bytes calldata signature
    )
        external
        view
        /// production todo paywall modifier goes here
        returns (uint256)
    {
        return _userScore(userAddress, uID, score, bundleId, signature);
    }

    function _userScore(
        address ownerOrDelegate,
        address uID,
        uint8 score,
        bytes32 bundleId,
        bytes memory signature
    ) private view returns (uint256) {
        // todo check bundleId exists

        // check identity validity
        require(upala.isOwnerOrDelegate(ownerOrDelegate, uID), 
            "Address doesn't own an Upala ID or is exploded");

        // TODO check that pool balance is sufficient for explosion
        uint256 totalScore = baseScore.mul(score);
        require(_hasEnoughFunds(score), 
            'Pool balance is lower than the total score');

        // check signature
        // production todo security check (see ECDSA.sol, 
        // https://solidity-by-example.org/signature/)
        // https://ethereum.stackexchange.com/questions/76810/sign-message-with-web3-and-verify-with-openzeppelin-solidity-ecdsa-sol
        // https://docs.openzeppelin.com/contracts/2.x/utilities
        require(
            keccak256(abi.encodePacked(uID, score, bundleId))
                .toEthSignedMessageHash()
                .recover(signature) == owner(),
            'Invalid signature or signer is not group owner'
        );

        return totalScore;
    }

    function hack_recover(bytes32 message, bytes calldata signature) external view returns (address) {
        return message.toEthSignedMessageHash().recover(signature);
    }

    /***********
    MANAGE GROUP
    ************/

    /*Announcements*/

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
    // require(scoreBundleIds[scoreBundleId] > now + attackWindow, 
    // 'Commit is submitted before scoreBundleId');
    
    // Sets the the base score for the group.
    function setBaseScore(uint256 newBaseScore, bytes32 secret)
        external
        onlyOwner
        hasValidCommit(
            keccak256(abi.encodePacked('setBaseScore', newBaseScore, secret)))
    {
        baseScore = newBaseScore;
        NewBaseScore(newBaseScore);
    }

    function deleteScoreBundleId(bytes32 scoreBundleId, bytes32 secret) 
        external 
        onlyOwner
        hasValidCommit(
            keccak256(abi.encodePacked('deleteScoreBundleId', scoreBundleId, secret)))
    {
        delete scoreBundleIds[scoreBundleId];
        ScoreBundleIdDeleted(scoreBundleId);
    }


    function withdrawFromPool(address recipient, uint256 amount, bytes32 secret) 
        external 
        onlyOwner
        hasValidCommit(
            keccak256(abi.encodePacked('withdrawFromPool', secret)))
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

    // Score bundleId ids are generated by the contract.
    // we don't need to care about block hash manipulation, we could
    // similary use incremented numbers. Hashes are used for compatibility
    // with Merkle pools.
    // todo do we need hashes generated by contract?
    function publishScoreBundleId() external onlyOwner returns (bytes32) {
        bytes32 newScoreBundleId = blockhash(block.number);
        scoreBundleIds[newScoreBundleId] = now;
        NewScoreBundleId(newScoreBundleId, now);
        return newScoreBundleId;
    }

    function updateMetadata(string calldata newMetadata) external onlyOwner {
        metaData = newMetadata;
        MetaDataUpdate(newMetadata);
    }

    /****
    FUNDS
    *****/

    // Upala checks funds to make sure the pool has enough funds for attack
    function _hasEnoughFunds(uint256 ammount) private view returns (bool) {
        return (approvedToken.balanceOf(address(this)) >= ammount);
    }

    // bots are getting paid instantly
    function _payBotReward(address bot, uint256 amount) private returns (bool) {
        require(_withdraw(bot, amount), 'token transfer to bot failed');
        return true;
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
        return scoreBundleIds[scoreBundleId];
    }

    function groupBaseScore() external view returns (uint256) {
        return baseScore;
    }
}
