pragma solidity 0.5.3;

import "./oz/Ownable.sol";
import "./oz/IERC20.sol";
import "./oz/SafeMath.sol";

/*

An experiment. As described in Upala docs.
This design could bring a possibility for every group to manage its poool in
it's own way. Or even to share one pool among several groups - a simpler 
way of creating shared responsibility than shares of shares model here
../playground/shared-responsibility-pool.sol

*/


contract molochPoolFactory { 

    function createMolochPool(approvedTokenAddress) external returns (address) {
      return new MolochPool(approvedTokenAddress);            
   }

contract GuildBank is Ownable {
    using SafeMath for uint256;

    IERC20 public approvedToken; // approved token contract reference

    event Withdrawal(address indexed receiver, uint256 amount);

    constructor(address approvedTokenAddress) public {
        approvedToken = IERC20(approvedTokenAddress);
    }

    function withdraw(address receiver, uint256 shares, uint256 totalShares) public onlyOwner returns (bool) {
        uint256 amount = approvedToken.balanceOf(address(this)).mul(shares).div(totalShares);
        emit Withdrawal(receiver, amount);
        return approvedToken.transfer(receiver, amount);
    }
}

// same as GuildBank but withdrawals are delayed
// bots can withdraw at any time. 
// exposes pool to Upala bot expolision risks
contract MolochPool is GuildBank {

    // shareholders will have to announce withddrawals first
    function withdraw(address receiver, uint256 shares, uint256 totalShares) public onlyOwner returns (bool) {
        uint256 amount = approvedToken.balanceOf(address(this)).mul(shares).div(totalShares);
        emit Withdrawal(receiver, amount);

        bytes32 hash = keccak256(abi.encodePacked(receiver, amount));
        // let Upala write hash and time and emit announcement
        upala.announceWithdrawal(receiver, amount, hash); 

        return true;  // TODO remove
    }

    // TODO will fail if insufficient funds - it's ok, wrap it with try/catch
    // shares are burned by moloch before withdrawal, so refund same number of 
    // shares if token transfer fails
    function withdrawFromPool(address receiver, uint256 shares, uint256 totalShares) external { // $$$
        uint256 amount = approvedToken.balanceOf(address(this)).mul(shares).div(totalShares);
        bytes32 hash = upala.checkHash(keccak256(abi.encodePacked(receiver, amount)));

        _withdraw(receiver, amount);
        // on error
        refundShares(receiver, shares)

        upala.deleteHash(hash);
        // emit Set("withdrawFromPool", hash);

    }
    
    // bots are getting paid instantly
    function payBotReward(address bot, uint amount) external onlyUpala  { // $$$ 
        _withdraw(bot, amount);
    }
    
    function _withdraw(address recipient, uint amount) internal {  // $$$ 
        require(approvedToken.transfer(recipient, amount), "token transfer to bot failed");
    }
    
}