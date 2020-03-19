// pragma solidity ^0.6.0;

// import "../incentives/group-example.sol";
// import "../mockups/moloch-mock.sol";

// // Upala Group that gathers all MolochDAO (the deployed one) members
// contract MolochWrap is UpalaGroup {
    
//     Moloch moloch;
//     uint256 commonLimit = -1;
    
//     constructor (address _moloch) {
//         moloch = Moloch(_moloch);
//     }

//     modifier onlyDelegate() {
//         require(moloch.members[memberAddressByDelegateKey[msg.sender]].shares > 0, "Moloch::onlyDelegate - not a delegate");
//         _;
//     }
    
//     // a delegate attaches their Upala User ID to this group 
//     // make sure that User ID owner (wallet) is under control
//     function attachMyUpalaUserID(address userID) external onlyDelegate {
//         require(isMolochMember(msg.sender));
//         upala.announceBotnetLimit(userID, commonLimit);
//     }
// }

    // function isMolochMember(applicant) returns (bool) {
    //     return moloch.members[applicant].shares > 0
    // }
