pragma solidity ^0.6.0;

import "./upala-group.sol";

contract FreeProvider is UpalaGroup {
	
    // this group proves scores for free. Anyone can add any dapp to get free scores
    function freeAppCredit(address appAddress) external {
        _increaseAppCredit(appAddress, 1000);
    }

}
