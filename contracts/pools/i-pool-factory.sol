pragma solidity 0.6;

interface IPoolFactory {
    function createPool(uint160) external returns (address);
}