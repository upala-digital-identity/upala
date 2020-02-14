pragma solidity ^0.5.3;

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

    function isValidStamp(uint256 proposalIndex, bytes32 hash) returns(bool) internal {
        return proposalQueue[proposalIndex].approvalStamp == hash;
    }
}

// TODO Guilbank ownership

contract BladerunnerDAO is MolochWithStamps {

    // address of the Upala protocol
    Upala upala;

    // the group ID within Upala
    address bladerunnerGroupID;

    // charge DApps for providing users scores
    uint256 scoringFee;


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
    function upgradeBank(address newBank, uint256 proposalIndex) returns(bool) internal {
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

    function announceBotnetLimit(address member, uint limit, uint256 proposalIndex) external {
        uint265 currentBotnetLimit = upala.getBotnetLimit(bladerunnerGroup, member);
        bytes32 hash = keccak256(abi.encodePacked("announceBotnetLimit", member, limit));

        require (isAuthorized(proposalIndex, hash, limit < currentBotnetLimit));

        upala.announceBotnetLimit(bladerunnerGroup, member, limit);
    }

    function acceptInvitation(address superiorGroup, bool isAccepted) external {
        //...
    }


    /******
    SCORING
    /*****/

    // BladerunnerDAO earns by providing users scores to DApps. 
    function memberScore(address[] calldata path) external returns (uint256) {
        // redirect all income to Bladerunners pool
        require(
                approvedToken.transfer(address(guildBank), scoringFee),
                "Moloch::processProposal - token transfer to guild bank failed"
            );
        return upala.memberScore(path);
    }


    /*******
    RAGEQUIT
    /******/

    // IF failed ragequit due to insufficient funds. 
    function refundShares(address member, uint sharesToRefund) external {
        require (msg.sender == guildBank);
        member.shares = member.shares.add(sharesToRefund);
        totalShares = totalShares.add(sharesToRefund);
        emit FailedRageQuit(member, sharesToRefund);
    }
