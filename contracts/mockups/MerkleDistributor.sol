// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "../libraries/openzeppelin-contracts/contracts/cryptography/MerkleProof.sol";

contract MerkleDistributor {
    bytes32 public merkleRoot;

    event Claimed(
        uint256 _index,
        address _identityID,
        uint256 _score
    );

    function publishRoot(bytes32 newMerkleRoot) external {
        merkleRoot = newMerkleRoot;
    }

    function verifyMyScore(address groupID, address identityID, address holder, uint8 score, bytes32[] memory proof) private returns (uint256){
        
    }

    function claim(uint256 index, address identityID, uint256 score, bytes32[] calldata merkleProof) external {
        // require(holder == identityHolder[identityID],
        //     "the holder address doesn't own the user id");
        // require (identityHolder[identityID] != EXPLODED,
        //     "This user has already exploded");
        // pool score is sufficient for explosion
        // Verify the merkle proof.

        bytes32 node = keccak256(abi.encodePacked(index, identityID, score));
        // require (roots[groupID][computeRoot(merkleProof, node)] > 0, 'MerkleDistributor: Invalid proof.');
        require (computeRoot(merkleProof, node) == merkleRoot, 'MerkleDistributor: Invalid proof.');
        // require(MerkleProof.verify(merkleProof, node), 'MerkleDistributor: Invalid proof.');
        emit Claimed(index, identityID, score);
        // uint256 totalScore = baseReward[groupID] * score;
        // return totalScore;
    }


    function computeRoot(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
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
}
