pragma solidity ^0.6.0;

// mocking Moloch and Metacartel
contract Moloch {

    struct Member {
        address delegateKey; // the key responsible for submitting proposals and voting - defaults to member address unless updated
        uint256 shares; // the # of shares assigned to this member
        bool exists; // always true once a member has been created
    }

    mapping (address => Member) public members;
    mapping (address => address) public memberAddressByDelegateKey;

    mapping (address => bool) public testmapping;

    /********
    MODIFIERS - for reference
    ********/
    modifier onlyMember {
        require(members[msg.sender].shares > 0, "Moloch::onlyMember - not a member");
        _;
    }

    modifier onlyDelegate {
        require(members[memberAddressByDelegateKey[msg.sender]].shares > 0, "Moloch::onlyDelegate - not a delegate");
        _;
    }

    // members[memberAddressByDelegateKey[proposal.applicant]].exists - checking membership

    /***********
    JOIN MOCKING
    ***********/    

    // If we can build the UX
    function join() public {
        members[msg.sender].delegateKey = msg.sender;
        members[msg.sender].shares = 100;
        members[msg.sender].exists = true;
    }

    // ... and if we have no time
    // send eth to join - UX-free workaround. Fakes Moloch membership.
    // wow, how long this receive function was around in solidity?
    receive() external payable {
        require(msg.value > 0, "Send any ammount of ETH to join the DAO");
        join();
    }

}