pragma solidity ^0.6.0;

import "./upala-group.sol";

contract UpalaScoreProvider is UpalaGroup {

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

}
