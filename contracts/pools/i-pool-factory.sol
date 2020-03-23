pragma solidity 0.6;

interface IPoolFactory {
    function createPool(uint160, address) external returns (address);
}