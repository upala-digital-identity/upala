pragma solidity 0.6;

interface IPool {
    function payBotReward(address, uint256) external returns (bool);
    function hasEnoughFunds(uint256) external view returns (bool);
    function withdrawAvailable(address, uint256) external returns (uint256);
    function userScore(address, address, uint8, bytes calldata) external view returns (uint256);
}