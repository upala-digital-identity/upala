
import "../oz/ownership/Ownable.sol";
import "../../IUpala.sol";
import "../../IGroup";

contract MinimalWallet is Ownable {

    Upala upala;
    
    constructor (address _upala) {
        upala = Upala(_upala);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(upala.transferUserOwnership(newOwner));
        _transferOwnership(newOwner);
    }

    function explode(address[] calldata atackPath) external onlyOwner {
        upala.attack(atackPath);
    }

    function acceptInvitation(address superiorGroup, bool isAccepted) external onlyOwner {
        upala.acceptInvitation(superiorGroup, isAccepted);
        if (isAccepted == true) {
            IGroup(superiorGroup).join;  // notify the group
        } else {
            IGroup(superiorGroup).leave;  // notify the group
        }
    }
}
