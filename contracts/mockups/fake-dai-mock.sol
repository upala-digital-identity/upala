pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FakeDai is ERC20 {

    constructor (string memory name_, string memory symbol_) ERC20(name_, symbol_) public {
    }

    function freeDaiToTheWorld(address anyAccount, uint256 anyAmount) external {
        _mint(anyAccount, anyAmount);
    }

    // send ETH, receive FakeDAI
    receive() external payable {
        _mint(msg.sender, msg.value);
    }
}