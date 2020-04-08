pragma solidity ^0.6.0;

import "../protocol/upala.sol";

contract ProtoGroup {

    /********
    CONSTANTS
    /********/
    // address of the Upala protocol
    // now it works as a guildBank
    Upala upala;

    // the group ID within Upala
    uint160 groupID;
    address groupPool;
    uint256 defaultLimit = 1000000 * 10 ** 18;  // one million dollars [*places little finger near mouth*]

    /******
    SCORING
    /*****/
    mapping (address => uint160[]) chachedPaths;
    mapping (address => uint160) identityIDs;

    // charge DApps for providing users scores
    uint256 scoringFee;

    constructor (address upalaProtocolAddress, address poolFactory) public {
        upala = Upala(upalaProtocolAddress);
        (groupID, groupPool) = upala.newGroup(address(this), poolFactory);
    }

    /******
    SCORING
    /*****/

    function getMyScore(uint160[] calldata path) external returns (address, uint256) {
    }

    function getScoreByPath(uint160[] calldata path) external returns (uint256) {
        // charge();
        // (address identityManager, uint256 score)
        // uint160[] memory memPath = path;
        // return upala.memberScore(memPath);
    }

    function getScoreByManager(address manger) external returns (address, uint256) {
        uint160[] memory path = new uint160[](2);
        path[0] = identityIDs[manger];
        path[1] = groupID;
        (address holder, uint256 score) = upala.memberScore(path);
        return (holder, score);
        // charge();
        //(uint160 identityID, uint256 score)
    }

    // Encrease bot reward through a proposal.
    // Emergency manager can decrease bot reward at any time (announce the decrease)
    function announceBotReward(uint botReward) external {
        upala.announceBotReward(groupID, botReward);
        _setBotReward(botReward);
    }

    function _setBotReward(uint botReward) internal {
        upala.setBotReward(groupID, botReward);
    }

    function _announceBotnetLimit(uint160 member, uint limit) internal {
        // bytes32 hash = keccak256(abi.encodePacked("announceBotnetLimit", member, limit));
        upala.announceBotnetLimit(groupID, member, limit);
    }

    

    function acceptInvitation(uint160 superiorGroup, bool isAccepted) external {
        //...
    }

    // User joins
    function join(uint160 identityID) external {
        identityIDs[msg.sender] = identityID;
        _announceBotnetLimit(identityID, defaultLimit);
    }

    function setBotnetLimit(uint160 identityID) external {
        upala.setBotnetLimit(groupID, identityID, defaultLimit);
    }


    /******
    GETTERS
    /*****/

    function getUpalaGroupID() external view returns (uint160) {
        return groupID;
    }

    function getGroupPoolAddress() external view returns (address) {
        return groupPool;
    }

}
