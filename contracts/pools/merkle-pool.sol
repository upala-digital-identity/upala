pragma solidity ^0.6.0;

import 'contracts/pools/bundledScoresPool.sol';
import "./i-pool-factory.sol";
import "./i-pool.sol";
import "hardhat/console.sol";
/*

Every group to manages its poool in it's own way.
Or even to share one pool among several groups.
*/


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
        require(upala.registerPool(newPoolAddress) == true, "Cannot approve new pool on Upala");
        NewPool(newPoolAddress);
        return newPoolAddress;
   }
}

// The most important obligation of a group is to pay bot rewards.
// MerkleTreePool
contract MerklePool is BundledScoresPool {

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