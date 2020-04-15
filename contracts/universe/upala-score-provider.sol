pragma solidity ^0.6.0;

import "./upala-group.sol";

contract UpalaScoreProvider is UpalaGroup {

    uint256 defaultLimit = 1000000 * 10 ** 18;  // one million dollars [*places little finger near mouth*]

    /************
    SCORING CACHE
    /***********/
    mapping (address => uint160[]) chachedPaths;
    mapping (address => uint160) identityIDs;

    constructor (
        address upalaProtocolAddress,
        address poolFactory
    ) UpalaGroup (
        upalaProtocolAddress,
        poolFactory)
    public {
        upala = Upala(upalaProtocolAddress);
        (groupID, groupPool) = upala.newGroup(address(this), poolFactory);
    }

    /******
    SCORING
    /*****/

    function _getScoreByPath(uint160[] memory path) internal view returns (uint256) {
        // charge();
        // (address identityManager, uint256 score)
        // uint160[] memory memPath = path;
        // return upala.memberScore(memPath);
        return upala.memberScore(path);
    }

    function _getIdentityHolder(uint160 memberID) internal view returns (address) {
        return upala.getIdentityHolder(memberID);
    }

    function _getScoreByManager(address manger) internal view returns (address, uint256) {
        uint160[] memory path = new uint160[](2);
        path[0] = identityIDs[manger];
        path[1] = groupID;
        uint256 score = upala.memberScore(path);
        address holder = upala.getIdentityHolder(path[0]);
        return (holder, score);
        // charge();
        //(uint160 identityID, uint256 score)
    }

}
