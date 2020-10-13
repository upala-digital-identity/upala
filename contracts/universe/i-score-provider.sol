pragma solidity 0.6;

// Minimal interface for all score providers (not used in prototype)
interface IScoreProvider {
	function groupID() external returns(uint160);
    function getScoreByPath(uint160[] calldata) external returns (uint256);
}