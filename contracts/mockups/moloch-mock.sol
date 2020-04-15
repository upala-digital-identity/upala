pragma solidity ^0.6.0;

// use for mocking Moloch and Metacartel onchain
// TODO create real Moloch moch
contract MolochMock {

    mapping (address => bool) members;

    // no UX workaround
    function join() external payable {
        require(msg.value > 0, "Send any ammount of ETH to join the DAO");
        members[msg.sender] = true;
    }

    // replace with real Moloch membership check
    function isMember(address candidate) external view returns (bool) {
        return members[candidate];
    }
}