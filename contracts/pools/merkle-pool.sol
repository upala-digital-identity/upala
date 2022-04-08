pragma solidity ^0.8.0;

import 'contracts/pools/bundledScoresPool.sol';

contract MerklePoolFactory {
    
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
        address newPoolAddress = address(new MerklePool(upalaAddress, approvedTokenAddress, msg.sender));
        require(upala.registerPool(newPoolAddress, msg.sender) == true, "Cannot approve new pool on Upala");
        NewPool(newPoolAddress);
        return newPoolAddress;
   }
}

contract MerklePool is BundledScoresPool {

    /************
    ANNOUNCEMENTS
    *************/

    // Any changes that can hurt bot rights must wait for an attackWindow
    mapping(bytes32 => uint256) public commitsTimestamps;

    constructor(
        address upalaAddress,
        address approvedTokenAddress,
        address poolManager) 
    BundledScoresPool(
        upalaAddress, 
        approvedTokenAddress, 
        poolManager) 
    public {}

    function isInBundle(
        address intraBundleUserID,
        uint8 score,
        bytes32 bundleId,
        bytes memory indexAndProof
    ) internal view override returns (bool) {
        uint256 index = hack_extractIndex(indexAndProof); 
        bytes32 leaf = keccak256(abi.encodePacked(index, intraBundleUserID, score));
        bytes32[] memory proof = hack_extractProof(indexAndProof);
        bytes32 computedRoot = _computeRoot(proof, leaf);
        return(scoreBundleTimestamp[computedRoot] > 0);
    }


    /* Announcements */
    // Announcements prevents front-running bot-exposions. Groups must announce
    // in advance any changes that may hurt bots rights
    // hash = keccak256(action-type, [parameters], secret) - see below

    function commitHash(bytes32 hash) 
        external 
        onlyOwner 
        returns (uint256 timestamp) 
    {
        uint256 timestamp = block.timestamp;
        commitsTimestamps[hash] = timestamp;
        return timestamp;
    }

    modifier hasValidCommit(bytes32 hash) {
        require(commitsTimestamps[hash] != 0, 
            'No such commitment hash');
        require(commitsTimestamps[hash] + upala.attackWindow() <= block.timestamp, 
            'Attack window is not closed yet');
        require(
            commitsTimestamps[hash] + upala.attackWindow() + upala.executionWindow() >= block.timestamp,
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
        hasValidCommit(keccak256(abi.encodePacked(
            'setBaseScore', newBaseScore, secret)))
    {
        _setBaseScore(newBaseScore);
    }

    function deleteScoreBundleId(bytes32 scoreBundleId, bytes32 secret) 
        external 
        hasValidCommit(keccak256(abi.encodePacked(
            'deleteScoreBundleId', scoreBundleId, secret)))
    {
        _deleteScoreBundleId(scoreBundleId);
    }

    function withdrawFromPool(address recipient, uint256 amount, bytes32 secret) 
        external 
        hasValidCommit(keccak256(abi.encodePacked(
            'withdrawFromPool', secret)))
        returns (uint256) 
    {
        // event is triggered by DAI contract
        return _withdrawFromPool(recipient, amount);
    }

    /*Changes that don't hurt bots rights*/

    function increaseBaseScore(uint256 newBaseScore) external onlyOwner {
        require(newBaseScore > baseScore, 
            'To decrease score, make a commitment first');
        _setBaseScore(newBaseScore);
    }


    // todo
    function hack_extractIndex(bytes memory indexAndProof) private pure returns (uint256) {
        return (1);
    }

    // todo
    function hack_extractProof(bytes memory indexAndProof) private pure returns (bytes32[] memory) {
        bytes32[] memory extracted;
        extracted[0] = bytes32("candidate1");
        return (extracted);
    }

    function _computeRoot(bytes32[] memory proof, bytes32 leaf) private pure returns (bytes32) {
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

    function hack_computeRoot(uint256 index, address identityID, uint8 score, bytes32[] calldata proof) external view returns (bytes32) {
        uint256 hack_score = uint256(score);
        bytes32 leaf = keccak256(abi.encodePacked(index, identityID, hack_score));
        return _computeRoot(proof, leaf);
    }

    function hack_leaf(uint256 index, address identityID, uint8 score, bytes32[] calldata proof) external view returns (bytes32) {
        uint256 hack_score = uint256(score);
        return  keccak256(abi.encodePacked(index, identityID, hack_score));
    }
}