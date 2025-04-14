// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Interface for the Membership contract
interface IMembershipForGovernance {
    function isActiveMember(address _address) external view returns (bool);
}

/**
 * @title EnergyCommunityGovernance
 * @dev Handles community governance including proposals and voting
 */
contract EnergyCommunityGovernance is Ownable, ReentrancyGuard {
    // Proposal status options
    enum ProposalStatus { Active, Passed, Rejected, Executed, Canceled }
    
    // Voting options
    enum VoteType { NoVote, Yes, No, Abstain }
    
    // Structure for governance proposals
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 abstainVotes;
        bytes callData;          // Function call data to execute if proposal passes
        address targetContract;  // Contract to call if proposal passes
        ProposalStatus status;
        mapping(address => VoteType) votes;
    }
    
    // Reference to the membership contract
    IMembershipForGovernance public membershipContract;
    // Token used for governance (can be the same as trading token)
    IERC20 public governanceToken;
    
    // Governance parameters
    uint256 public votingPeriod = 7 days;
    uint256 public proposalThreshold;    // Minimum tokens to submit a proposal
    uint256 public quorum;               // Minimum participation required (in basis points, 100 = 1%)
    uint256 public executionDelay = 2 days; // Delay before execution after passing
    
    // Counter for proposal IDs
    uint256 private nextProposalId = 1;
    
    // Mapping proposal ID to proposal data
    mapping(uint256 => Proposal) public proposals;
    // Array of all proposal IDs
    uint256[] public allProposalIds;
    
    // Events
    event ProposalCreated(
        uint256 indexed proposalId, 
        address indexed proposer, 
        string title, 
        uint256 startTime, 
        uint256 endTime
    );
    event Voted(
        uint256 indexed proposalId, 
        address indexed voter, 
        VoteType vote, 
        uint256 weight
    );
    event ProposalStatusChanged(uint256 indexed proposalId, ProposalStatus status);
    event ProposalExecuted(uint256 indexed proposalId);
    event GovernanceParameterUpdated(string paramName, uint256 newValue);
    
    /**
     * @dev Constructor for the Governance contract
     * @param _initialOwner Address that will own the contract
     * @param _membershipContract Address of the Membership contract
     * @param _governanceToken Address of the governance token
     * @param _proposalThreshold Minimum tokens required to submit a proposal
     * @param _quorum Minimum participation required as a percentage in basis points (100 = 1%)
     */
    constructor(
        address _initialOwner,
        address _membershipContract,
        address _governanceToken,
        uint256 _proposalThreshold,
        uint256 _quorum
    ) Ownable(_initialOwner) {
        membershipContract = IMembershipForGovernance(_membershipContract);
        governanceToken = IERC20(_governanceToken);
        proposalThreshold = _proposalThreshold;
        quorum = _quorum;
    }
    
    /**
     * @dev Create a new governance proposal
     * @param _title Short title of the proposal
     * @param _description Detailed description of the proposal
     * @param _targetContract Address of contract to call if proposal passes
     * @param _callData Function call data to execute if proposal passes
     */
    function createProposal(
        string memory _title,
        string memory _description,
        address _targetContract,
        bytes memory _callData
    ) 
        external 
        nonReentrant 
    {
        require(membershipContract.isActiveMember(msg.sender), "Not active member");
        
        // Check if proposer has enough tokens
        require(
            governanceToken.balanceOf(msg.sender) >= proposalThreshold,
            "Insufficient tokens to propose"
        );
        
        uint256 proposalId = nextProposalId++;
        Proposal storage newProposal = proposals[proposalId];
        
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + votingPeriod;
        newProposal.targetContract = _targetContract;
        newProposal.callData = _callData;
        newProposal.status = ProposalStatus.Active;
        
        allProposalIds.push(proposalId);
        
        emit ProposalCreated(
            proposalId, 
            msg.sender, 
            _title, 
            newProposal.startTime, 
            newProposal.endTime
        );
    }
    
    /**
     * @dev Vote on an active proposal
     * @param _proposalId ID of the proposal
     * @param _vote Type of vote (Yes, No, or Abstain)
     */
    function vote(uint256 _proposalId, VoteType _vote) 
        external 
        nonReentrant 
    {
        require(_vote != VoteType.NoVote, "Invalid vote type");
        require(membershipContract.isActiveMember(msg.sender), "Not active member");
        
        Proposal storage proposal = proposals[_proposalId];
        
        require(proposal.status == ProposalStatus.Active, "Proposal not active");
        require(block.timestamp <= proposal.endTime, "Voting period ended");
        require(proposal.votes[msg.sender] == VoteType.NoVote, "Already voted");
        
        // Get voter's voting power
        uint256 votingPower = governanceToken.balanceOf(msg.sender);
        require(votingPower > 0, "No voting power");
        
        // Record the vote
        proposal.votes[msg.sender] = _vote;
        
        // Update vote counts
        if (_vote == VoteType.Yes) {
            proposal.yesVotes += votingPower;
        } else if (_vote == VoteType.No) {
            proposal.noVotes += votingPower;
        } else if (_vote == VoteType.Abstain) {
            proposal.abstainVotes += votingPower;
        }
        
        emit Voted(_proposalId, msg.sender, _vote, votingPower);
    }
    
    /**
     * @dev Check if a proposal can be finalized (has reached end time)
     * @param _proposalId ID of the proposal
     */
    function checkProposalStatus(uint256 _proposalId) 
        external 
    {
        Proposal storage proposal = proposals[_proposalId];
        
        require(proposal.status == ProposalStatus.Active, "Not an active proposal");
        require(block.timestamp > proposal.endTime, "Voting period not ended");
        
        uint256 totalVotes = proposal.yesVotes + proposal.noVotes + proposal.abstainVotes;
        uint256 totalSupply = governanceToken.totalSupply();
        
        // Check if quorum is reached (participation threshold)
        if ((totalVotes * 10000) / totalSupply >= quorum) {
            // Check if yes votes are greater than no votes
            if (proposal.yesVotes > proposal.noVotes) {
                proposal.status = ProposalStatus.Passed;
            } else {
                proposal.status = ProposalStatus.Rejected;
            }
        } else {
            // If quorum is not reached, the proposal is rejected
            proposal.status = ProposalStatus.Rejected;
        }
        
        emit ProposalStatusChanged(_proposalId, proposal.status);
    }
    
    /**
     * @dev Execute a passed proposal after the execution delay
     * @param _proposalId ID of the proposal
     */
    function executeProposal(uint256 _proposalId) 
        external 
        nonReentrant 
    {
        Proposal storage proposal = proposals[_proposalId];
        
        require(proposal.status == ProposalStatus.Passed, "Proposal not passed");
        require(
            block.timestamp > proposal.endTime + executionDelay,
            "Execution delay not passed"
        );
        
        // Update status to prevent re-execution
        proposal.status = ProposalStatus.Executed;
        
        // Execute the proposal (call the target contract with the call data)
        (bool success, ) = proposal.targetContract.call(proposal.callData);
        require(success, "Proposal execution failed");
        
        emit ProposalExecuted(_proposalId);
    }
    
    /**
     * @dev Cancel a proposal (only the proposer or admin can cancel)
     * @param _proposalId ID of the proposal
     */
    function cancelProposal(uint256 _proposalId) 
        external 
    {
        Proposal storage proposal = proposals[_proposalId];
        
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Not authorized to cancel"
        );
        require(proposal.status == ProposalStatus.Active, "Not an active proposal");
        
        proposal.status = ProposalStatus.Canceled;
        
        emit ProposalStatusChanged(_proposalId, ProposalStatus.Canceled);
    }
    
    /**
     * @dev Update voting period (admin only)
     * @param _newVotingPeriod New voting period in seconds
     */
    function updateVotingPeriod(uint256 _newVotingPeriod) 
        external 
        onlyOwner 
    {
        require(_newVotingPeriod > 0, "Invalid voting period");
        votingPeriod = _newVotingPeriod;
        emit GovernanceParameterUpdated("votingPeriod", _newVotingPeriod);
    }
    
    /**
     * @dev Update proposal threshold (admin only)
     * @param _newProposalThreshold New proposal threshold
     */
    function updateProposalThreshold(uint256 _newProposalThreshold) 
        external 
        onlyOwner 
    {
        proposalThreshold = _newProposalThreshold;
        emit GovernanceParameterUpdated("proposalThreshold", _newProposalThreshold);
    }
    
    /**
     * @dev Update quorum requirement (admin only)
     * @param _newQuorum New quorum requirement in basis points (100 = 1%)
     */
    function updateQuorum(uint256 _newQuorum) 
        external 
        onlyOwner 
    {
        require(_newQuorum <= 10000, "Invalid quorum value");
        quorum = _newQuorum;
        emit GovernanceParameterUpdated("quorum", _newQuorum);
    }
    
    /**
     * @dev Update execution delay (admin only)
     * @param _newExecutionDelay New execution delay in seconds
     */
    function updateExecutionDelay(uint256 _newExecutionDelay) 
        external 
        onlyOwner 
    {
        executionDelay = _newExecutionDelay;
        emit GovernanceParameterUpdated("executionDelay", _newExecutionDelay);
    }
    
    /**
     * @dev Update contract references (admin only)
     * @param _membershipContract New membership contract address
     * @param _governanceToken New governance token address
     */
    function updateContractReferences(
        address _membershipContract,
        address _governanceToken
    ) 
        external 
        onlyOwner 
    {
        membershipContract = IMembershipForGovernance(_membershipContract);
        governanceToken = IERC20(_governanceToken);
    }
    
    /**
     * @dev Get proposal details
     * @param _proposalId ID of the proposal
     * @return Basic proposal details
     */
    function getProposalDetails(uint256 _proposalId) 
        external 
        view 
        returns (
            uint256 id,
            address proposer,
            string memory title,
            string memory description,
            uint256 startTime,
            uint256 endTime,
            uint256 yesVotes,
            uint256 noVotes,
            uint256 abstainVotes,
            ProposalStatus status
        ) 
    {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.abstainVotes,
            proposal.status
        );
    }
    
    /**
     * @dev Check how an address voted on a proposal
     * @param _proposalId ID of the proposal
     * @param _voter Address of the voter
     * @return Vote type
     */
    function getVote(uint256 _proposalId, address _voter) 
        external 
        view 
        returns (VoteType) 
    {
        return proposals[_proposalId].votes[_voter];
    }
    
    /**
     * @dev Get all proposal IDs
     * @return Array of proposal IDs
     */
    function getAllProposalIds() 
        external 
        view 
        returns (uint256[] memory) 
    {
        return allProposalIds;
    }
    
    /**
     * @dev Get active proposal IDs
     * @return Array of active proposal IDs
     */
    function getActiveProposals() 
        external 
        view 
        returns (uint256[] memory) 
    {
        // Count active proposals
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allProposalIds.length; i++) {
            if (proposals[allProposalIds[i]].status == ProposalStatus.Active) {
                activeCount++;
            }
        }
        
        // Create array of active proposal IDs
        uint256[] memory activeProposals = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allProposalIds.length; i++) {
            if (proposals[allProposalIds[i]].status == ProposalStatus.Active) {
                activeProposals[index] = allProposalIds[i];
                index++;
            }
        }
        
        return activeProposals;
    }
}