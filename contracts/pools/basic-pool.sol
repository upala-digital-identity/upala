pragma solidity ^0.6.0;


import "../libraries/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../libraries/openzeppelin-contracts/contracts/math/SafeMath.sol";
import "./i-pool-factory.sol";
import "./i-pool.sol";

/*

Every group to manages its poool in it's own way.
Or even to share one pool among several groups.
*/

// Creates Upala and Moloch compatible Guilbanks
// i.e. the banks that are deliberately vulnerable to bot attacks
contract BasicPoolFactory is IPoolFactory {

    address public approvedToken;

    constructor (address approvedTokenAddress) public {
        approvedToken = approvedTokenAddress;
    }

    function createPool(uint160 poolManager) external override (IPoolFactory) returns (address) {
        poolManager;  // just silencing warnings // basic pool doesn't have a pool Manager
        return address(new BasicPool(msg.sender, approvedToken));
   }
}

// bots can withdraw at any time. 
// exposes pool to Upala bot expolision risks
contract BasicPool is IPool {
    using SafeMath for uint256;

    IERC20 public approvedToken; // approved token contract reference

    address upala;

    // TODO hardcode approved token
    constructor(address upalaContract, address approvedTokenAddress) public {
        upala = upalaContract;
        approvedToken = IERC20(approvedTokenAddress);
    }

    modifier onlyUpala() {
        require(msg.sender == upala);
        _;
    }

    // Upala checks funds to make sure the pool has enough funds to fund a bot attack
    function hasEnoughFunds(uint256 ammount) external view onlyUpala override(IPool) returns(bool) {
        return (approvedToken.balanceOf(address(this)) >= ammount);
    }

    // bots are getting paid instantly
    function payBotReward(address bot, uint amount) external onlyUpala override(IPool) returns(bool)  {
        require(_withdraw(bot, amount), "token transfer to bot failed");
        return true;
    }

    // basic pool does not allow withdrawals
    function withdrawAvailable(uint160 group, address receiver, uint256 amount, uint256 nonce) external onlyUpala override(IPool) returns (uint256) {
        group; receiver; amount; nonce;  // just silencing warnings
        return 0; 
    }

    function _withdraw(address recipient, uint amount) internal returns (bool) {
        return approvedToken.transfer(recipient, amount);
    }
}