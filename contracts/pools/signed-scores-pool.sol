pragma solidity ^0.8.2;

import '../pools/bundledScoresPool.sol';
import '@openzeppelin/contracts/proxy/Clones.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';

contract SignedScoresPoolFactory {  // important!!! naming convention poolType + 'Factory'
    Upala public upala;
    address public upalaAddress;
    address public approvedTokenAddress;
    address immutable implementation;
    address immutable impltnOwner;

    constructor(address _upalaAddress, address _approvedTokenAddress) public {
        upalaAddress = _upalaAddress;
        upala = Upala(_upalaAddress);
        approvedTokenAddress = _approvedTokenAddress;
        address _implementation = address(new SignedScoresPool());
        implementation = _implementation;
        impltnOwner = msg.sender;
        // owner is "address(this)" to prevent ownership transfer before registration
        SignedScoresPool(_implementation).initialize(upalaAddress, approvedTokenAddress, address(this));
    }

    function createPool() external returns (address) {
        address newPoolAddress = Clones.clone(implementation);
        _initializePool(newPoolAddress, msg.sender);
        _registerPool(newPoolAddress, msg.sender);
        return newPoolAddress;
    }

    // allows to use template as pool too
    function registerImplementationAsPool() external {
        SignedScoresPool(implementation).transferOwnership(impltnOwner);
        _registerPool(implementation, impltnOwner);
    }

    function _registerPool(address pool, address poolOwner) private {
        require(upala.registerPool(pool, poolOwner) == true, 
            'Pool: Cannot approve new pool on Upala');
    }

    function _initializePool(address pool, address poolOwner) private {
        SignedScoresPool(pool).initialize(upalaAddress, approvedTokenAddress, poolOwner);
    }

    // needed when approveing pool factory by admin
    function isPoolFactory() external view returns(bool) {
        return true;
    }
}

// The most important obligation of a group is to pay bot rewards.
contract SignedScoresPool is BundledScoresPool {
    using ECDSA for bytes32;

    // Pool-specific score management
    function setBaseScore(uint256 newBaseScore)
        external
    {
        _setBaseScore(newBaseScore);
    }

    function deleteScoreBundleId(bytes32 scoreBundleId) 
        external 
    {
        _deleteScoreBundleId(scoreBundleId);
    }

    function withdrawFromPool(address recipient, uint256 amount) 
        external 
        returns (uint256) 
    {
        _withdrawFromPool(recipient, amount);
    }

    // Pool-specific way to validate that userID is in bundle
    // SignedScoresPool requires every score to be signed by pool manager
    function isInBundle(
        address intraBundleUserID,
        uint8 score,
        bytes32 bundleId,
        bytes memory signature
    ) internal view override returns (bool) {
        return(
            recoverEthSigned(
                keccak256(abi.encodePacked(intraBundleUserID, score, bundleId)),
                signature
            ) == owner()
        );
    }

    function recoverEthSigned(bytes32 message, bytes memory signature) internal view returns (address) {
        return message.toEthSignedMessageHash().recover(signature);
    }
    
    // is used for testing only (yep, a bit dirty, but trying to move fast)
    function testRecover(bytes32 message, bytes calldata signature) external view returns (address) {
        return recoverEthSigned(message, signature);
    }
}
