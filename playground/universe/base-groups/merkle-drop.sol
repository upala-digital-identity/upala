// https://blog.ricmoo.com/merkle-air-drops-e6406945584d
// Credits - https://github.com/trustlines-protocol/merkle-drop/blob/master/contracts/contracts/MerkleDrop.sol
pragma solidity ^0.6.0;

import "../../libraries/openzeppelin-contracts/contracts/access/Ownable.sol";

contract usingMerkleDrop is Ownable {

    bytes32 public root;

    function publishNewRoot(bytes32 newRoot) external onlyOwner {
        root = newRoot;
    }

    function verifyEntitled(uint160 upalaID, uint8 value, bytes32[] memory proof) public view returns (bool) {
        // We need to pack the 20 bytes address to the 32 bytes value
        // to match with the proof made with the python merkle-drop package
        bytes32 leaf = keccak256(abi.encodePacked(upalaID, value));
        return verifyProof(leaf, proof);
    }

    function verifyProof(bytes32 leaf, bytes32[] memory proof) internal view returns (bool) {
        bytes32 currentHash = leaf;

        for (uint i = 0; i < proof.length; i += 1) {
            currentHash = parentHash(currentHash, proof[i]);
        }

        return currentHash == root;
    }

    function parentHash(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        if (a < b) {
            return keccak256(abi.encode(a, b));
        } else {
            return keccak256(abi.encode(b, a));
        }
    }
}