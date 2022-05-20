pragma solidity ^0.8.0;

interface IPoolFactory {
    function createPool(address) external returns (address);
    function isPoolFactory() external view returns(bool);
}