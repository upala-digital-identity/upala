pragma solidity 0.6;

interface IPool {
    function payBotReward(address, uint256) external returns (bool);
    function hasEnoughFunds(uint256) external view returns (bool);
    function withdrawAvailable(uint160, address, uint256, uint256) external returns (uint256);
}