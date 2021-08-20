pragma solidity ^0.6.0;

// 
contract RequiringUserDeposit {

    uint256 public depositAmount; // = 2 * 10 ** 18;  // just for display (deposit is not implemented)

    function getGroupDepositAmount() external view returns (uint256) {
        return depositAmount;
    }
}