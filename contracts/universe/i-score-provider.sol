pragma solidity 0.6;

// Minimal interface for all score providers (not used in prototype)
interface IScoreProvider {
    function getScoreByPath(uint160[] calldata) external returns (uint256);
    function getScoreByManager(address) external returns (uint160, uint256);
}