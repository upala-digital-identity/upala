
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

    function applyForMembership(address group) returns(bool res) external onlyOwner {
        IGroup(group).join;
    }

    function acceptInvitation(address superiorGroup, bool isAccepted) external onlyOwner {
        upala.acceptInvitation(superiorGroup, isAccepted);
    }
}
