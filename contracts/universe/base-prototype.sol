pragma solidity ^0.6.0;

// Shared features for all prototype groups
contract BasePrototype {

    /*******
    SETTINGS
    /******/

    /* {"name": "ProtoGroup",
    "version": "0.1",
    "description": "Autoassigns FakeDAI score to anyone who joins",
    "join-terms": "No deposit required (ignore the ammount you see and join)",
    "leave-terms": "No deposit - no refund"} */
    string public details;  // json with ^details^
    uint256 public depositAmount; // = 2 * 10 ** 18;  // just for display (deposit is not implemented)
    uint256 public scoringFee; // charge DApps for providing users scores

    constructor (string memory _details, uint256 _depositAmount, uint256 _scoringFee) public {
        details = _details;
        depositAmount = _depositAmount;
        scoringFee = _scoringFee;
    }

    function getGroupDetails() external view returns (string memory){
        return details;
    }

    function getGroupDepositAmount() external view returns (uint256) {
        return depositAmount;
    }
}