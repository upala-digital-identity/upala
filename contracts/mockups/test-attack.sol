pragma solidity ^0.5.0;

import "../incentives/group-example.sol";

contract testAttack is UpalaGroup {
    function joinGroup () external payable {
        if (msg.value >= 50000000000000000) { // 0.05 eth
            membersScores[msg.sender] = 100;
        }
    }
}

/*
contract Group is UpalaGroup, Ownable {
       
       // Group and members types
       byte8 groupType = "HashOfRegisteredGroupType"; // 0 - members are users
-       byte8[] allowedMemberTypes;  // list of allowed types hashes (not applicable for lowest level groups)
-       
-    // owner is either a trusted user or a voting contract
-       // sets entering condition including income pool (income) management, types of groups to be invited
-
-       
-       // Apps
-       function calculateUserScore(address candidate, address[] _path) {  //payable optionally
-
-       }
-
-       function updateMemberScore(address member, uint8 newScore) onlyAdmin {
-               // todo check member type
-               require (newScore >= 0 && newScore <= 100);
-               membersScores[member] = newScore;
-       }
-
-       // Pool
-       function encreasePool() external payable {  //onlyAdmin? //or anyone?
-               pool+= msg.value;
-       }
-}
-*/
