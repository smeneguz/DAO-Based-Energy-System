// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interface for the Membership contract
interface IMembershipForTreasury {
    function isActiveMember(address _address) external view returns (bool);
    function updateEnergyContribution(address _memberAddress, uint256 _amount) external;
}

/**
 * @title EnergyCommunityTreasury
 * @dev Manages the community treasury including fees, rewards, and multisig withdrawals
 */
contract EnergyCommunityTreasury is Ownable, ReentrancyGuard {
    // Structure for withdrawal proposals
    struct WithdrawalProposal {
        uint256 id;
        address proposer;
        address recipient;
        uint256 amount;
        string description;
        uint256 creationTime;
        uint256 expirationTime;
        uint256 approvals;
        bool executed;
        mapping(address => bool) hasApproved;
    }
    
    // Reference to the membership contract
    IMembershipForTreasury public membershipContract;
    // Token used for treasury (same as trading token)
    IERC20 public treasuryToken;
    
    // Treasury parameters
    uint256 public requiredApprovals;      // Number of approvals needed for withdrawal
    uint256 public proposalExpiryTime = 7 days;
    uint256 public lastRewardsDistribution;
    uint256 public rewardsDistributionPeriod = 30 days;
    uint256 public rewardsPercentage = 5000;  // 50% of treasury paid as rewards (in basis points)
    
    // Approved signers for multisig operations
    mapping(address => bool) public approvedSigners;
    address[] public signersList;
    
    // Counter for withdrawal proposal IDs
    uint256 private nextProposalId = 1;
    
    // Mapping proposal ID to proposal data
    mapping(uint256 => WithdrawalProposal) public withdrawalProposals;
    // Array of all proposal IDs
    uint256[] public allWithdrawalProposalIds;
    
    // Mapping to track energy contributions for reward calculations
    mapping(address => uint256) public lastPeriodEnergyContributions;
    // Total energy contributed in the last period
    uint256 public totalLastPeriodEnergyContribution;
    
    // Events
    event FeeCollected(uint256 amount);
    event WithdrawalProposalCreated(
        uint256 indexed proposalId, 
        address indexed proposer, 
        address recipient, 
        uint256 amount, 
        string description
    );
    event WithdrawalApproved(uint256 indexed proposalId, address indexed approver);
    event WithdrawalExecuted(uint256 indexed proposalId, address recipient, uint256 amount);
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event RewardsDistributed(uint256 totalAmount, uint256 totalContributors);
    event TreasuryParameterUpdated(string paramName, uint256 newValue);
    
    /**
     * @dev Constructor for the Treasury contract
     * @param _initialOwner Address that will own the contract
     * @param _membershipContract Address of the Membership contract
     * @param _treasuryToken Address of the treasury token
     * @param _initialSigners Array of initial approved signers
     * @param _requiredApprovals Number of approvals required for withdrawals
     */
    constructor(
        address _initialOwner,
        address _membershipContract,
        address _treasuryToken,
        address[] memory _initialSigners,
        uint256 _requiredApprovals
    ) Ownable(_initialOwner) {
        membershipContract = IMembershipForTreasury(_membershipContract);
        treasuryToken = IERC20(_treasuryToken);
        
        require(_requiredApprovals > 0, "Approvals must be positive");
        require(_requiredApprovals <= _initialSigners.length, "Not enough signers");
        
        requiredApprovals = _requiredApprovals;
        
        // Add initial signers
        for (uint256 i = 0; i < _initialSigners.length; i++) {
            approvedSigners[_initialSigners[i]] = true;
            signersList.push(_initialSigners[i]);
        }
        
        lastRewardsDistribution = block.timestamp;
    }
    
    /**
     * @dev Collect fee from energy trades (called by Energy Management contract)
     * @param _amount Amount of fee to collect
     */
    function collectFee(uint256 _amount) 
        external 
    {
        // In production, this should be restricted to the energy management contract
        require(_amount > 0, "Fee must be positive");
        
        // Transfer tokens from the caller to treasury
        require(
            treasuryToken.transferFrom(msg.sender, address(this), _amount),
            "Fee transfer failed"
        );
        
        emit FeeCollected(_amount);
    }
    
    /**
     * @dev Create a withdrawal proposal
     * @param _recipient Address to receive the withdrawn funds
     * @param _amount Amount of tokens to withdraw
     * @param _description Purpose of the withdrawal
     */
    function proposeWithdrawal(
        address _recipient,
        uint256 _amount,
        string memory _description
    ) 
        external 
        nonReentrant 
    {
        require(approvedSigners[msg.sender], "Not an approved signer");
        require(_recipient != address(0), "Invalid recipient");
        require(_amount > 0, "Amount must be positive");
        require(_amount <= treasuryToken.balanceOf(address(this)), "Insufficient treasury balance");
        
        uint256 proposalId = nextProposalId++;
        WithdrawalProposal storage newProposal = withdrawalProposals[proposalId];
        
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.recipient = _recipient;
        newProposal.amount = _amount;
        newProposal.description = _description;
        newProposal.creationTime = block.timestamp;
        newProposal.expirationTime = block.timestamp + proposalExpiryTime;
        
        // Auto-approve by the proposer
        newProposal.hasApproved[msg.sender] = true;
        newProposal.approvals = 1;
        
        allWithdrawalProposalIds.push(proposalId);
        
        emit WithdrawalProposalCreated(
            proposalId, 
            msg.sender, 
            _recipient, 
            _amount, 
            _description
        );
        
        // Execute immediately if only one approval is required
        if (requiredApprovals == 1) {
            executeWithdrawal(proposalId);
        }
    }
    
    /**
     * @dev Approve a withdrawal proposal
     * @param _proposalId ID of the proposal to approve
     */
    function approveWithdrawal(uint256 _proposalId) 
        external 
        nonReentrant 
    {
        require(approvedSigners[msg.sender], "Not an approved signer");
        
        WithdrawalProposal storage proposal = withdrawalProposals[_proposalId];
        
        require(!proposal.executed, "Already executed");
        require(block.timestamp <= proposal.expirationTime, "Proposal expired");
        require(!proposal.hasApproved[msg.sender], "Already approved");
        
        proposal.hasApproved[msg.sender] = true;
        proposal.approvals += 1;
        
        emit WithdrawalApproved(_proposalId, msg.sender);
        
        // Execute if enough approvals have been collected
        if (proposal.approvals >= requiredApprovals) {
            executeWithdrawal(_proposalId);
        }
    }
    
    /**
     * @dev Execute a withdrawal proposal that has enough approvals
     * @param _proposalId ID of the proposal to execute
     */
    function executeWithdrawal(uint256 _proposalId) 
        internal 
    {
        WithdrawalProposal storage proposal = withdrawalProposals[_proposalId];
        
        require(!proposal.executed, "Already executed");
        require(block.timestamp <= proposal.expirationTime, "Proposal expired");
        require(proposal.approvals >= requiredApprovals, "Not enough approvals");
        
        proposal.executed = true;
        
        // Transfer tokens to the recipient
        require(
            treasuryToken.transfer(proposal.recipient, proposal.amount),
            "Transfer failed"
        );
        
        emit WithdrawalExecuted(_proposalId, proposal.recipient, proposal.amount);
    }
    
    /**
     * @dev Distribute rewards to prosumers based on their energy contribution
     * Can be called by anyone after the distribution period has passed
     */
    function distributeRewards() 
        external 
        nonReentrant 
    {
        require(
            block.timestamp >= lastRewardsDistribution + rewardsDistributionPeriod,
            "Distribution period not reached"
        );
        
        uint256 treasuryBalance = treasuryToken.balanceOf(address(this));
        uint256 rewardsAmount = (treasuryBalance * rewardsPercentage) / 10000;
        
        require(rewardsAmount > 0, "Insufficient rewards amount");
        
        // Reset counters for the new period
        lastRewardsDistribution = block.timestamp;
        
        // Get total energy contribution for this period from all members
        uint256 totalContribution = totalLastPeriodEnergyContribution;
        
        // Don't distribute if no energy was contributed
        if (totalContribution == 0) {
            return;
        }
        
        uint256 totalDistributed = 0;
        uint256 contributorCount = 0;
        
        // Distribute to each contributing member
        for (uint256 i = 0; i < signersList.length; i++) {
            address memberAddress = signersList[i];
            uint256 contribution = lastPeriodEnergyContributions[memberAddress];
            
            if (contribution > 0) {
                uint256 memberReward = (rewardsAmount * contribution) / totalContribution;
                
                if (memberReward > 0) {
                    require(
                        treasuryToken.transfer(memberAddress, memberReward),
                        "Reward transfer failed"
                    );
                    
                    totalDistributed += memberReward;
                    contributorCount++;
                }
                
                // Reset contribution for next period
                lastPeriodEnergyContributions[memberAddress] = 0;
            }
        }
        
        // Reset total contribution for next period
        totalLastPeriodEnergyContribution = 0;
        
        emit RewardsDistributed(totalDistributed, contributorCount);
    }
    
    /**
     * @dev Record energy contribution for rewards calculation
     * @param _contributor Address of the contributor
     * @param _amount Amount of energy contributed
     */
    function recordEnergyContribution(address _contributor, uint256 _amount) 
        external 
    {
        // In production, this should be restricted to the energy management contract
        require(membershipContract.isActiveMember(_contributor), "Not active member");
        
        lastPeriodEnergyContributions[_contributor] += _amount;
        totalLastPeriodEnergyContribution += _amount;
    }
    
    /**
     * @dev Add a new approved signer (admin only)
     * @param _signer Address of the new signer
     */
    function addSigner(address _signer) 
        external 
        onlyOwner 
    {
        require(_signer != address(0), "Invalid signer address");
        require(!approvedSigners[_signer], "Already a signer");
        
        approvedSigners[_signer] = true;
        signersList.push(_signer);
        
        emit SignerAdded(_signer);
    }
    
    /**
     * @dev Remove an approved signer (admin only)
     * @param _signer Address of the signer to remove
     */
    function removeSigner(address _signer) 
        external 
        onlyOwner 
    {
        require(approvedSigners[_signer], "Not a signer");
        require(signersList.length > requiredApprovals, "Cannot remove: minimum signers needed");
        
        approvedSigners[_signer] = false;
        
        // Remove from signers list
        for (uint256 i = 0; i < signersList.length; i++) {
            if (signersList[i] == _signer) {
                signersList[i] = signersList[signersList.length - 1];
                signersList.pop();
                break;
            }
        }
        
        emit SignerRemoved(_signer);
    }
    
    /**
     * @dev Update required approvals (admin only)
     * @param _newRequiredApprovals New number of required approvals
     */
    function updateRequiredApprovals(uint256 _newRequiredApprovals) 
        external 
        onlyOwner 
    {
        require(_newRequiredApprovals > 0, "Approvals must be positive");
        require(_newRequiredApprovals <= signersList.length, "Not enough signers");
        
        requiredApprovals = _newRequiredApprovals;
        emit TreasuryParameterUpdated("requiredApprovals", _newRequiredApprovals);
    }
    
    /**
     * @dev Update proposal expiry time (admin only)
     * @param _newExpiryTime New expiry time in seconds
     */
    function updateProposalExpiryTime(uint256 _newExpiryTime) 
        external 
        onlyOwner 
    {
        proposalExpiryTime = _newExpiryTime;
        emit TreasuryParameterUpdated("proposalExpiryTime", _newExpiryTime);
    }
    
    /**
     * @dev Update rewards distribution period (admin only)
     * @param _newPeriod New period in seconds
     */
    function updateRewardsDistributionPeriod(uint256 _newPeriod) 
        external 
        onlyOwner 
    {
        require(_newPeriod > 0, "Period must be positive");
        rewardsDistributionPeriod = _newPeriod;
        emit TreasuryParameterUpdated("rewardsDistributionPeriod", _newPeriod);
    }
    
    /**
     * @dev Update rewards percentage (admin only)
     * @param _newPercentage New percentage in basis points (e.g., 5000 = 50%)
     */
    function updateRewardsPercentage(uint256 _newPercentage) 
        external 
        onlyOwner 
    {
        require(_newPercentage <= 10000, "Percentage cannot exceed 100%");
        rewardsPercentage = _newPercentage;
        emit TreasuryParameterUpdated("rewardsPercentage", _newPercentage);
    }
    
    /**
     * @dev Update contract references (admin only)
     * @param _membershipContract New membership contract address
     * @param _treasuryToken New treasury token address
     */
    function updateContractReferences(
        address _membershipContract,
        address _treasuryToken
    ) 
        external 
        onlyOwner 
    {
        membershipContract = IMembershipForTreasury(_membershipContract);
        treasuryToken = IERC20(_treasuryToken);
    }
    
    /**
     * @dev Get withdrawal proposal details
     * @param _proposalId ID of the proposal
     * @return Basic proposal details
     */
    function getWithdrawalProposalDetails(uint256 _proposalId) 
        external 
        view 
        returns (
            uint256 id,
            address proposer,
            address recipient,
            uint256 amount,
            string memory description,
            uint256 creationTime,
            uint256 expirationTime,
            uint256 approvals,
            bool executed
        ) 
    {
        WithdrawalProposal storage proposal = withdrawalProposals[_proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.recipient,
            proposal.amount,
            proposal.description,
            proposal.creationTime,
            proposal.expirationTime,
            proposal.approvals,
            proposal.executed
        );
    }
    
    /**
     * @dev Check if an address has approved a withdrawal proposal
     * @param _proposalId ID of the proposal
     * @param _signer Address of the signer
     * @return True if the signer has approved the proposal
     */
    function hasApprovedWithdrawal(uint256 _proposalId, address _signer) 
        external 
        view 
        returns (bool) 
    {
        return withdrawalProposals[_proposalId].hasApproved[_signer];
    }
    
    /**
     * @dev Get all withdrawal proposal IDs
     * @return Array of withdrawal proposal IDs
     */
    function getAllWithdrawalProposalIds() 
        external 
        view 
        returns (uint256[] memory) 
    {
        return allWithdrawalProposalIds;
    }
    
    /**
     * @dev Get all active (non-executed, non-expired) withdrawal proposals
     * @return Array of active proposal IDs
     */
    function getActiveWithdrawalProposals() 
        external 
        view 
        returns (uint256[] memory) 
    {
        // Count active proposals
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allWithdrawalProposalIds.length; i++) {
            uint256 proposalId = allWithdrawalProposalIds[i];
            WithdrawalProposal storage proposal = withdrawalProposals[proposalId];
            
            if (!proposal.executed && block.timestamp <= proposal.expirationTime) {
                activeCount++;
            }
        }
        
        // Create array of active proposal IDs
        uint256[] memory activeProposals = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allWithdrawalProposalIds.length; i++) {
            uint256 proposalId = allWithdrawalProposalIds[i];
            WithdrawalProposal storage proposal = withdrawalProposals[proposalId];
            
            if (!proposal.executed && block.timestamp <= proposal.expirationTime) {
                activeProposals[index] = proposalId;
                index++;
            }
        }
        
        return activeProposals;
    }
    
    /**
     * @dev Get list of all approved signers
     * @return Array of signer addresses
     */
    function getAllSigners() 
        external 
        view 
        returns (address[] memory) 
    {
        return signersList;
    }
    
    /**
     * @dev Get treasury balance
     * @return Current balance of the treasury token
     */
    function getTreasuryBalance() 
        external 
        view 
        returns (uint256) 
    {
        return treasuryToken.balanceOf(address(this));
    }
    
    /**
     * @dev Check if rewards distribution is due
     * @return True if the distribution period has passed
     */
    function isRewardsDistributionDue() 
        external 
        view 
        returns (bool) 
    {
        return block.timestamp >= lastRewardsDistribution + rewardsDistributionPeriod;
    }
    
    /**
     * @dev Get member's energy contribution for the current period
     * @param _member Address of the member
     * @return Current period energy contribution
     */
    function getMemberEnergyContribution(address _member) 
        external 
        view 
        returns (uint256) 
    {
        return lastPeriodEnergyContributions[_member];
    }
}