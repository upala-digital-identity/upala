pragma solidity ^0.6.0;

import "../libraries/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract FakeDai is ERC20 {
    // s
    function freeDaiToTheWorld(address anyAccount, uint256 anyAmount) external {
        _mint(anyAccount, anyAmount);
    }


    // function _mint(address account, uint256 amount) internal virtual {
    //     require(account != address(0), "ERC20: mint to the zero address");

    //     _beforeTokenTransfer(address(0), account, amount);

    //     _totalSupply = _totalSupply.add(amount);
    //     _balances[account] = _balances[account].add(amount);
    //     emit Transfer(address(0), account, amount);
    // }
}