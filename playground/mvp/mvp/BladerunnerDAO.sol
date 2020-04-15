pragma solidity ^0.6.0;

import "../libraries/Moloch.sol";

contract MolochWithStamps is Moloch {

    struct Proposal {
        address proposer; // the member who submitted the proposal
        address applicant; // the applicant who wishes to become a member - this key will be used for withdrawals
        uint256 sharesRequested; // the # of shares the applicant is requesting
        uint256 startingPeriod; // the period in which voting can start for this proposal
        uint256 yesVotes; // the total number of YES votes for this proposal
        uint256 noVotes; // the total number of NO votes for this proposal
        bool processed; // true only if the proposal has been processed
        bool didPass; // true only if the proposal passed
        bool aborted; // true only if applicant calls "abort" fn before end of voting period
        uint256 tokenTribute; // amount of tokens offered as tribute
        string details; // proposal details - could be IPFS hash, plaintext, or JSON

        // changed in Moloch
        bytes32 approvalStamp;  // approves execution of additional functions

        uint256 maxTotalSharesAtYesVote; // the maximum # of total shares encountered at a yes vote on this proposal
        mapping (address => Vote) votesByMember; // the votes on this proposal by each member
    }

    
    function submitProposal(
        address applicant,
        uint256 tokenTribute,
        uint256 sharesRequested,
        string memory details,

        // changed in Moloch
        bytes32 approvalStamp
    )
        public
        onlyDelegate
    {
        require(applicant != address(0), "Moloch::submitProposal - applicant cannot be 0");

        // Make sure we won't run into overflows when doing calculations with shares.
        // Note that totalShares + totalSharesRequested + sharesRequested is an upper bound
        // on the number of shares that can exist until this proposal has been processed.
        require(totalShares.add(totalSharesRequested).add(sharesRequested) <= MAX_NUMBER_OF_SHARES, "Moloch::submitProposal - too many shares requested");

        totalSharesRequested = totalSharesRequested.add(sharesRequested);

        address memberAddress = memberAddressByDelegateKey[msg.sender];

        // collect proposal deposit from proposer and store it in the Moloch until the proposal is processed
        require(approvedToken.transferFrom(msg.sender, address(this), proposalDeposit), "Moloch::submitProposal - proposal deposit token transfer failed");

        // collect tribute from applicant and store it in the Moloch until the proposal is processed
        require(approvedToken.transferFrom(applicant, address(this), tokenTribute), "Moloch::submitProposal - tribute token transfer failed");

        // compute startingPeriod for proposal
        uint256 startingPeriod = max(
            getCurrentPeriod(),
            proposalQueue.length == 0 ? 0 : proposalQueue[proposalQueue.length.sub(1)].startingPeriod
        ).add(1);

        // create proposal ...
        Proposal memory proposal = Proposal({
            proposer: memberAddress,
            applicant: applicant,
            sharesRequested: sharesRequested,
            startingPeriod: startingPeriod,
            yesVotes: 0,
            noVotes: 0,
            processed: false,
            didPass: false,
            aborted: false,
            tokenTribute: tokenTribute,
            details: details,

            // changed in Moloch
            approvalStamp: approvalStamp,
            
            maxTotalSharesAtYesVote: 0
        });

        // ... and append it to the queue
        proposalQueue.push(proposal);

        uint256 proposalIndex = proposalQueue.length.sub(1);
        emit SubmitProposal(proposalIndex, msg.sender, memberAddress, applicant, tokenTribute, sharesRequested);
    }

    function isValidStamp(uint256 proposalIndex, bytes32 hash) internal returns(bool) {
        return proposalQueue[proposalIndex].approvalStamp == hash;
    }
}








// TODO Guilbank ownership
// TODO proposalDeposit 
contract BladerunnerDAO is MolochWithStamps {

    /********
    CONSTANTS
    /********/
    // address of the Upala protocol
    // now it works as a guildBank
    Upala upala;

    // the group ID within Upala
    uint160 bladerunnerGroupID;

    /******
    SCORING
    /*****/
    mapping (address => uint160[]) chachedPaths;
    

    // charge DApps for providing users scores
    uint256 scoringFee;

    /*******
    RAGEQUIT
    /*******/
    // Snapshot of shares for refund if insuffiicient funds on ragequit
    struct RagequitRequest {
        uint256 shares;
        uint256 totalShares;
        address receiver;
    }
    mapping (uint256 => RagequitRequest) ragequitRequests;

    
    constructor (address upalaProtocolAddress) {
        upala = Upala(upalaProtocolAddress);
    }

    /******
    SCORING
    /*****/
    function getMyScore(uint160[] calldata path) external returns (address, uint256) {
    }

    function getScoreByPath(uint160[] calldata path) external returns (address, uint256) {
        // charge();
        // (address identityManager, uint256 score)
        uint256 score = upala.memberScore(path);
        address holder = upala.getIdentityHolder(path[0]);
        return (holder, score);
    }

    function getScoreByManager(address manager) external returns (uint160, uint256) {
        // charge();
        //(uint160 identityID, uint256 score)
    }

    // BladerunnerDAO can earn by providing users scores to DApps.
    //redirects all income to Bladerunners pool
    function charge() private {
        require(
                approvedToken.transfer(address(guildBank), scoringFee),
                "Moloch::processProposal - token transfer to guild bank failed"
            );
    }

    /*********************************
    MANAGE THE BLADERUNNERS DAO ITSELF
    /********************************/

    // emergency managers are allowed to lower bot reward and botnet limit
    function manageManagers(address manager, bool isActive, uint256 proposalIndex) external {
        emergencyManagers[manager] = isActive;
    }
    
    // set the fee
    function newScoringFee(uint256 newFee, uint256 proposalIndex) external {
        bytes32 hash = keccak256(abi.encodePacked("newScoringFee", newFee));
        require(isValidStamp(proposalIndex, hash));
        scoringFee = newFee;
    }

    // Upgrade this group
    function upgrade(address newDAO, uint256 proposalIndex) external {
        bytes32 hash = keccak256(abi.encodePacked("upgrade", newDAO));
        require(isValidStamp(proposalIndex, hash));
        upala.upgradeGroup(bladerunnerGroup, newDAO);
        /// ....
    } 

    // New guildbank
    // Is neccessary at initialization
    function upgradeBank(address newBank, uint256 proposalIndex) internal returns(bool) {
        bytes32 hash = keccak256(abi.encodePacked("upgradeBank", newBank));
        require(isValidStamp(proposalIndex, hash));
        guildbank = Guilbank(newBank);
        upala.announceAttachPool(bladerunnerGroupID, guildbank);
        /// .....
    }


    /*****************************
    MANAGE BLADERUNNER UPALA GROUP
    /****************************/

    // managers can only perform allowed direction of changes in parameters
    // i.e. managers can only decrease bot rewards.
    // in order to increase the DAO must vote
    function isAuthorized(uint256 proposalIndex, bytes32 hash, bool isManagerAllowed) internal returns (bool) {
       if (isManagerAllowed == true) {
            require (emergencyManagers[msg.sender] == true || isValidStamp(proposalIndex, hash));
        } else {
            require(isValidStamp(proposalIndex, hash));
        }
    }

    // Encrease bot reward through a proposal.
    // Emergency manager can decrease bot reward at any time (announce the decrease)
    function announceBotReward(uint botReward, uint256 proposalIndex) external {
        uint265 currentBotReward = upala.getBotReward(bladerunnerGroup);
        bytes32 hash = keccak256(abi.encodePacked("announceBotReward", botReward));

        require (isAuthorized(proposalIndex, hash, botReward < currentBotReward));

        upala.announceBotReward(bladerunnerGroup, botReward);
    }

    function announceBotnetLimit(uint160 member, uint limit, uint256 proposalIndex) external {
        uint265 currentBotnetLimit = upala.getBotnetLimit(bladerunnerGroup, member);
        bytes32 hash = keccak256(abi.encodePacked("announceBotnetLimit", member, limit));

        require (isAuthorized(proposalIndex, hash, limit < currentBotnetLimit));

        upala.announceBotnetLimit(bladerunnerGroup, member, limit);
    }

    function acceptInvitation(uint160 superiorGroup, bool isAccepted) external {
        //...
    }




    /*******
    RAGEQUIT
    /******/

    function ragequit(uint256 sharesToBurn) public onlyMember {
        uint256 initialTotalShares = totalShares;

        Member storage member = members[msg.sender];

        require(member.shares >= sharesToBurn, "Moloch::ragequit - insufficient shares");

        require(canRagequit(member.highestIndexYesVote), "Moloch::ragequit - cant ragequit until highest index proposal member voted YES on is processed");

        // burn shares
        member.shares = member.shares.sub(sharesToBurn);
        totalShares = totalShares.sub(sharesToBurn);

        // instruct guildBank to transfer fair share of tokens to the ragequitter
        // modified. guildBank is now under Upala protocol control
        require(
            _withdraw(msg.sender, sharesToBurn, initialTotalShares),
            "Moloch::ragequit - withdrawal of tokens from guildBank failed"
        );

        emit Ragequit(msg.sender, sharesToBurn);
    }

    // modified original guildbank withdrawal
    // shareholders will have to announce (request) withdrawals first
    function _withdraw(address receiver, uint256 shares, uint256 totalShares) private returns (bool) {
        uint256 amount = approvedToken.balanceOf(address(this)).mul(shares).div(totalShares);
        bytes32 nonce = upala.announceWithdrawal(group, receiver, amount);

        // snapshot state for further refunds (if needed)
        ragequitRequests[nonce].receiver = receiver;
        ragequitRequests[nonce].balance = approvedToken.balanceOf(address(this));
        ragequitRequests[nonce].totalShares = totalShares;

        return true;  // TODO remove?
    }

    // IF failed ragequit due to insufficient funds, refund shares.
    function refundShares(uint nonce) external {

        uint256 unpaidAmount = guildBank.getUnpaidAmount(nonce);

        uint256 totalSharesSnapshot = ragequitRequests[nonce].totalShares;
        uint256 balanceSnapshot = ragequitRequests[nonce].balance;

        uint256 sharesToRefund = totalSharesSnapshot.mul(unpaidAmount).div(balanceSnapshot);

        Member storage member = ragequitRequests[nonce].receiver;

        member.shares = member.shares.add(sharesToRefund);
        totalShares = totalShares.add(sharesToRefund);

        delete ragequitRequests[nonce];

        emit FailedRageQuit(member, sharesToRefund);
    }
}
