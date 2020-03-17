pragma solidity 0.6;

interface IScoreProvider {
    function getScoreByPath(uint160[] calldata) external returns (address, uint256);
    function getScoreByManager(address) external returns (uint160, uint256);
}