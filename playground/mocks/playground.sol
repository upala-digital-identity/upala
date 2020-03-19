contract test {
    
    event alert (uint);
    
    function popFromMemoryArray(uint8[] calldata _path) external returns (uint8[] memory) {
	 	//https://ethereum.stackexchange.com/questions/51891/how-to-pop-from-decrease-the-length-of-a-memory-array-in-solidity?rq=1
	 	uint8[] memory _newPath = _path;
	 	if (_newPath.length != 0) {
	 	    assembly { mstore(_newPath, sub(mload(_newPath), 1)) }
	 	}
	 	return _newPath;
	}
}
