pragma solidity 0.6;

import "../libraries/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../protocol/i-upala.sol";


// Gnosis-like recoverable wallet.
// Use simple external addresses for the ptototype and mvp
contract MinimalWallet is Ownable {

    Upala upala;
    ScoreProvider scoreProvider;

    constructor (address _upala) {
        upala = Upala(_upala);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(upala.transferUserOwnership(newOwner));
        _transferOwnership(newOwner);
    }

    // function explode(address[] calldata atackPath) external onlyOwner {
    //     upala.attack(atackPath);
    // }

    // function acceptInvitation(address superiorGroup, bool isAccepted) external onlyOwner {
    //     upala.acceptInvitation(superiorGroup, isAccepted);
    //     if (isAccepted == true) {
    //         IGroup(superiorGroup).join;  // notify the group
    //     } else {
    //         IGroup(superiorGroup).leave;  // notify the group
    //     }
    // }

    // // function addScoreProvider() {
    // // }

    // function getMyScoreInSpecificGroup (address groupManager, uint160[] calldata path) external view onlyOwner {
    //     return ScoreProvider(groupManager).getMyScore(path);
    // }

}
