pragma solidity ^0.6.0;

import 'contracts/pools/bundledScoresPool.sol';
import '../libraries/openzeppelin-contracts/contracts/cryptography/ECDSA.sol';

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
contract SignedScoresPool is BundledScoresPool {
    using ECDSA for bytes32;

    constructor(
        address upalaAddress,
        address approvedTokenAddress,
        address poolManager) 
    BundledScoresPool(
        upalaAddress, 
        approvedTokenAddress, 
        poolManager) 
    public {}

    // Pool-specific way to validate that userID is in bundle
    // SignedScoresPool requires every score to be signed by pool manager
    // production todo security check (see ECDSA.sol, 
    // https://solidity-by-example.org/signature/)
    // https://ethereum.stackexchange.com/questions/76810/sign-message-with-web3-and-verify-with-openzeppelin-solidity-ecdsa-sol
    // https://docs.openzeppelin.com/contracts/2.x/utilities
    function isInBundle(
        address intraBundleUserID,
        uint8 score,
        bytes32 bundleId,
        bytes memory signature
    ) internal view override returns (bool) {
        return(
            keccak256(abi.encodePacked(intraBundleUserID, score, bundleId))
                .toEthSignedMessageHash()
                .recover(signature) == owner());
    }

    function hack_recover(bytes32 message, bytes calldata signature) external view returns (address) {
        return message.toEthSignedMessageHash().recover(signature);
    }
}
