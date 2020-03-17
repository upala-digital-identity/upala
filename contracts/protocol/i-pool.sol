pragma solidity 0.6;

interface IPool {
    function payBotReward(address, uint256) external returns (address);
    function hasEnoughFunds(uint256) external view returns (bool);
    function withdrawAvailable(uint160, address, uint256, uint256) external;
}