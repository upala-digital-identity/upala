// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import "../libraries/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../libraries/openzeppelin-contracts/contracts/cryptography/MerkleProof.sol";

contract MerkleDistributor {
    address public immutable token;
    bytes32 public immutable merkleRoot;

    event Claimed(
        uint256 _index,
        address _account,
        uint256 _amount
    );

    constructor(address token_, bytes32 merkleRoot_) public {
        token = token_;
        merkleRoot = merkleRoot_;
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external {
        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');

        // require(IERC20(token).transfer(account, amount), 'MerkleDistributor: Transfer failed.');

        emit Claimed(index, account, amount);
    }


}
