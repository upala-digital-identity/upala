
import "../oz/ownership/Ownable.sol";
import "IUpala.sol";

contract MinimalWallet is Ownable {

    Upala upala;
    
    constructor (address _upala) {
        upala = Upala(_upala);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(upala.transferUserOwnership(newOwner));
        _transferOwnership(newOwner);
    }

    function explode(address[] calldata atackPath) public onlyOwner {
        upala.attack(atackPath);
    }

    function acceptInvitation(address superiorGroup, bool isAccepted) external onlyOwner {
        upala.acceptInvitation(superiorGroup, isAccepted);
    }
}
