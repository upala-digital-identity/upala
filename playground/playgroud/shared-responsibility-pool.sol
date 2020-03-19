
/*
Below is an example of group tool. A family of groups (an Upala friendly identity system)
may inherit the shared responsibility to introduce social responsibility.

Here member groups buy shares from a superior group. The superior group puts the income 
to it's pool in the Upala. When a bot attacks, it chopps off the pool and delutes shares value. 

So every member has to watch for other members not to allow bots.

Other group examples (identity systems) are in the ../universe directory
*/
contract SharedResponsibility is UpalaTimer {
    using SafeMath for uint256;

    
    IERC20 public approvedToken;
    IUpala public upala;
    
    mapping (address => uint) sharesBalances;
    uint totalShares;
    
    constructor (address _upala, address _approvedToken) public {
        approvedToken = IERC20(_approvedToken);
        upala = IUpala(_upala);
        // todo add initial funds
        // todo a bankrupt policy? what if balance is 0 or very close to 0, after a botnet attack.
        // too much delution problem 
    }
    
    // share responisibiity by buying SHARES
    function buyPoolShares(uint payment) external {
        uint poolSize = upala.getPoolSize(address(this));
        uint shares = payment.mul(totalShares).div(poolSize);
        
        totalShares += shares;
        sharesBalances[msg.sender] += shares;
        
        approvedToken.transferFrom(msg.sender, address(this), payment);
        upala.addFunds(payment);
    }
    
    function withdrawPoolShares(uint sharesToWithdraw) external returns (bool) {
        
        require(sharesBalances[msg.sender] >= sharesToWithdraw);
        uint poolSize = upala.getPoolSize(address(this));
        uint amount = poolSize.mul(sharesToWithdraw).div(totalShares);
        
        sharesBalances[msg.sender].sub(sharesToWithdraw);
        totalShares.sub(sharesToWithdraw);
        
        upala.withdrawFromPool(amount);
        return approvedToken.transfer(msg.sender, amount);
    }
}
/* 
Pay royalties down or up the path 
Check DAI savings rates, aDAI!!!, Compound - how they pay interest
https://ethresear.ch/t/pooled-payments-scaling-solution-for-one-to-many-transactions/590
https://medium.com/cardstack/scalable-payment-pools-in-solidity-d97e45fc7c5c
*/