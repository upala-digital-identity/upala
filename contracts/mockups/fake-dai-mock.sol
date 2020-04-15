pragma solidity ^0.6.0;

import "../libraries/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract FakeDai is ERC20 {

    // s
    function freeDaiToTheWorld(address anyAccount, uint256 anyAmount) external {
        _mint(anyAccount, anyAmount);
    }

    // send ETH, receive FakeDAI
    function exchangeETHtoFDAI() external payable {
        _mint(msg.sender, msg.value);
    }
}