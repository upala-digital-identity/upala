contract BladerunnerDAO is UpalaGroup {


// MOLOCH 2

// address applicant; // the applicant who wishes to become a member - this key will be used for withdrawals (doubles as guild kick target for gkick proposals)
// new group to be accepted 

// address proposer; // the account that submitted the proposal (can be non-member)
// address sponsor; // the member that sponsored the proposal (moving it into the queue)

// uint256 sharesRequested; // the # of shares the applicant is requesting
// uint256 lootRequested; // the amount of loot the applicant is requesting
// uint256 tributeOffered; // amount of tokens offered as tribute
// IERC20 tributeToken; // tribute token contract reference
// uint256 paymentRequested; // amount of tokens requested as payment
// IERC20 paymentToken; // payment token contract reference

// uint256 startingPeriod; // the period in which voting can start for this proposal
// uint256 yesVotes; // the total number of YES votes for this proposal
// uint256 noVotes; // the total number of NO votes for this proposal
// bool[6] flags; // [sponsored, processed, didPass, cancelled, whitelist, guildkick]

// string details; // proposal details - could be IPFS hash, plaintext, or JSON



// ORIGINAL MOLOCH

// address proposer; // the member who submitted the proposal
// address applicant; // the applicant who wishes to become a member - this key will be used for withdrawals
// douples as existing member (subgroup in Upala)

// uint256 sharesRequested; // the # of shares the applicant is requesting

// uint256 tokenTribute; // amount of tokens offered as tribute
// string details; // proposal details - could be IPFS hash, plaintext, or JSON

// uint256 maxTotalSharesAtYesVote; // the maximum # of total shares encountered at a yes vote on this proposal
// mapping (address => Vote) votesByMember; // the votes on this proposal by each member




// additional approvalStamp - execute additional functions. 


     // DAO administrative

    function upgrade(address newDAO, bytes32 approvalStamp) external {} // Upgrade this group. 

    function manageManagers(address manager, bool active, bytes32 approvalStamp) {}

    function upgradeBank (address newGuildbank, bytes32 approvalStamp) returns(bool res) internal {
        
    }
    


    // Upala Governed by the DAO:

    function announceBotReward(uint botReward, bytes32 approvalStamp) external onlyGroups {}

    function announceBotnetLimit(address member, uint limit) external onlyGroups {}

    function acceptInvitation(address superiorGroup, bool isAccepted) external onlyGroups {}

    // Finance

    approvedToken.transfer(address(guildBank), proposal.tokenTribute),
                "Moloch::processProposal - token transfer to guild bank failed"

    guildBank.withdraw(msg.sender, sharesToBurn, initialTotalShares),
            "Moloch::ragequit - withdrawal of tokens from guildBank failed"

    function addFunds(uint amount) external onlyGroups {}

    function announceWithdrawFromPool(uint amount) external onlyGroups {}


    // Earn 

    function memberScore(address[] calldata path) payable {
        msg.value to guidbank;
        // redirect all income to Upala
    }

    


    // move funds to Upala
    // withdraw from Upala  


// Upala is guild bank 