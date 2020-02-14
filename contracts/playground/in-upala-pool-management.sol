
/**
 * Trying to detach groups pools from Upala
 */
contract UpalaManagesPools is Upala{

    // TODO will fail if insufficient funds
    function withdrawFromPool(address group, uint amount) external { // $$$
        hash = checkHash(keccak256(abi.encodePacked(group, amount)));
        _withdraw(group, amount);
        delete commitsTimestamps[hash];
        // emit Set("withdrawFromPool", hash);
    }

    // Allows group admin to add funds to the group's pool
    // TODO unlock group
    // can hurt bots rights?
    // can anyone add funds? no. if an intermediary group is low on money a botnet
    // may redirect it's rewards to fill the pool and thus fund the attack
    // TODO only groupOwners.
    function addFunds(uint amount) external onlyGroups { // $$$
        require(approvedToken.transferFrom(msg.sender, address(this), amount), "token transfer to pool failed");
        balances[msg.sender].add(amount);
    }
    
    // Allows bot to withdraw it's reward after an attack
    function withdrawBotReward() external botsTurn onlyUsers  { // $$$ 
        _withdraw(msg.sender, balances[msg.sender]);
    }
    
    function _withdraw(address recipient, uint amount) internal {  // $$$ 
        balances[recipient].sub(amount); 
        require(approvedToken.transfer(recipient, amount), "token transfer to bot failed"); 
    }
  }
}