pragma solidity ^0.6.0;

interface IUpala {
    // users and bots (wallets)
    function newIdentity(address) external payable returns (uint160);
    function setIdentityHolder(uint160, address)  external;
    function attack(uint160[] calldata) external;
    function myId() external view returns(uint160);

    // groups
    function newGroup(address groupManager, address poolFactory) external payable returns (uint160, address);
    function newPool(address, uint160) external payable returns (address);

    // groups (only managers)
    function setGroupManager(uint160, address) external;
    function memberScore(uint160[] calldata) external view returns(uint256);
    function announceBotReward(uint160, uint) external returns (uint256);
    function announceBotnetLimit(uint160, uint160, uint) external returns (uint256);
    function announceAttachPool(uint160, address) external returns (uint256);
    function announceWithdrawFromPool(uint160, address, uint) external returns (uint256);
    function acceptInvitation(uint160, uint160, bool) external;
    function getBotnetLimit(uint160, uint160) external view returns (uint256);

    // groups (anyone)
    function setBotReward(uint160, uint) external;
    function setBotnetLimit(uint160, uint160, uint) external;
    function attachPool(uint160, address) external;
    function withdrawFromPool(uint160, address, uint) external;

    function getBotReward(uint160) external view returns (uint256);

    // Upala admin
    function setapprovedPoolFactory(address, bool) external;
}
