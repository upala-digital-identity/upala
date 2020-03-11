pragma solidity ^0.5.0;

contract Empty {
}

contract AddressGenerator {
    
    uint256 nonce = 1;
    
    function generateAddress () external returns (uint256) {
        // address randomish = address(uint160(uint(keccak256(abi.encodePacked(nonce)))));
        
        return nonce++;
    }
}

contract MyContract {
    
    function hey() external {
        
    }
}