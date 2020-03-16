
import "../oz/ownership/Ownable.sol";
import "../../IUpala.sol";
import "../../IGroup";

// keeps track of wallet owners.
// serves as a DB temporary substitution
contract WalletRegistry {
    // binds walet owners and Upala identity ids

    mapping (address => uint160) ids;

    function createUpalaId() external {
        uint160 newId = upala.newIdentity(msg.sender);
        ids[msg.sender] = newId;
    }

    function whatIsMyId() external view returns(uint160) {
        return ids[msg.sender];
    }
}

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

    function getMyScoreInSpecificGroup (address groupManager, uint160[] calldata path) external view onlyOwner {
        return ScoreProvider(groupManager).getMyScore(path);
    }

}
