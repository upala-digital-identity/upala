pragma solidity 0.6;


import "../libraries/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../libraries/openzeppelin-contracts/contracts/math/SafeMath.sol";

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
contract MolochPool is NotGuildBank {

    // DAO public dao; // owner contract reference

    // saves unpaid amount to be refunded in shares
    mapping (uint256 => uint256) unpaidAmount;

    // TODO hardcode approved token
    constructor(address approvedTokenAddress) public {
        // owner = poolOwner;
        // dao = DAO(poolOwner);
    }

    // Upala checks funds to make sure the pool has enough funds to fund a bot attack
    function hasEnoughFunds(uint256 ammount) external view onlyUpala returns(bool) {
        return (approvedToken.balanceOf(address(this)) >= ammount);
    }

    // bots are getting paid instantly
    function payBotReward(address bot, uint amount) external onlyUpala { // $$$ 
        _withdraw(bot, amount);
        // TODO
        // return (result, error)
    }

    // try to withdraw as much as possible
    // shares are burned by moloch before withdrawal, so refund same number of shares if amount < balance
    function withdrawAvailable(uint160 group, address receiver, uint256 amount, uint256 nonce) external onlyUpala returns (uint) {
        uint256 balance = approvedToken.balanceOf(address(this));
        if (balance >= amount) {
            _withdraw(receiver, amount);
            return amount;  // TODO remove ?
        } else {
            _withdraw(receiver, balance);
            unpaidAmount[nonce] = amount.sub(balance);
            return balance;  // TODO remove ?
        }
    }

    function _withdraw(address recipient, uint amount) private {  // $$$ 
        emit Withdrawal(receiver, amount);
        require(approvedToken.transfer(recipient, amount), "token transfer to bot failed");
    }

    /**************
    GETTER FUNCTIONS
    ***************/

    function getUnpaidAmount(uint256 nonce) external returns (uint256) {
        return unpaidAmount[nonce];
    }
}
