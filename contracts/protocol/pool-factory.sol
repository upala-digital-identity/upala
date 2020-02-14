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

// Original GuildBank
// TODO move to libraries
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

// The first (most probably) pool factory to be approved by Upala
// Creates Upala and Moloch compatible Guilbanks 
// i.e. the banks that are deliberately vulnerable to bot attacks
contract molochPoolFactory { 

    function createPool(address poolOwner, address token) external returns (address) {
      return new MolochPool(poolOwner);
   }
}


// same as GuildBank but withdrawals are delayed
// bots can withdraw at any time. 
// exposes pool to Upala bot expolision risks
contract MolochPool is GuildBank {

    // DAO public dao; // owner contract reference

    // TODO hardcode approved token
    constructor(address poolOwner, address approvedTokenAddress) public {
        owner = poolOwner;
        // dao = DAO(poolOwner);
    }

    // modified original guildbank withdrawal
    // shareholders will have to announce (request) withdrawals first
    function withdraw(address receiver, uint256 shares, uint256 totalShares) public onlyOwner returns (bool) {
        uint256 amount = approvedToken.balanceOf(address(this)).mul(shares).div(totalShares);
        bytes32 hash = keccak256(abi.encodePacked(receiver, amount));
        // let Upala write hash and time and emit announcement
        upala.announceWithdrawal(receiver, amount, hash); 

        return true;  // TODO remove?
    }

    // shares are burned by moloch before withdrawal, so refund same number of 
    // shares if amount < balance)
    function tryWithdrawal(address receiver, uint amount) external onlyUpala returns (uint) {
        uint256 balance = approvedToken.balanceOf(address(this));
        // try to withdraw as much as possible
        if (balance >= amount) {
            _withdraw(receiver, amount);
            return amount;
        } else {
            _withdraw(receiver, balance);
            // TODO calc shares as if withdrawal is done before announcement
            bladerunner.refundShares(receiver, shares);
            return balance;
        }
    }
    
    // bots are getting paid instantly
    function payBotReward(address bot, uint amount) external onlyUpala { // $$$ 
        _withdraw(bot, amount);
        // TODO
        // return (result, error)
    }
    
    function _withdraw(address recipient, uint amount) internal {  // $$$ 
        emit Withdrawal(receiver, amount);
        require(approvedToken.transfer(recipient, amount), "token transfer to bot failed");
    }


    function hasEnoughFunds(uint256 ammount) returns(bool) external view {
        return (approvedToken.balanceOf(address(this)) >= ammount);
    }
}
