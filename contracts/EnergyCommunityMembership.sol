// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title EnergyCommunityMembership
 * @dev Manages membership for the energy community DAO
 */
contract EnergyCommunityMembership is Ownable, ReentrancyGuard {
    // Membership status options
    enum MembershipStatus { None, Pending, Active, Suspended }
    
    // Structure to store member information
    struct Member {
        string name;
        string solarInstallationProof; // IPFS hash or other proof reference
        MembershipStatus status;
        address walletAddress;
        uint256 joinDate;
        bool kycVerified;
        uint256 energyContribution; // Total energy contributed to the network
    }
    
    // Mapping of addresses to member data
    mapping(address => Member) public members;
    // Array to keep track of all member addresses
    address[] public memberAddresses;
    // Membership fee (if applicable)
    uint256 public membershipFee;
    // Token used for membership fee (if applicable)
    IERC20 public membershipToken;
    
    // Events
    event MemberRegistered(address indexed memberAddress, string name, uint256 timestamp);
    event MembershipStatusChanged(address indexed memberAddress, MembershipStatus status);
    event SolarInstallationProofUpdated(address indexed memberAddress, string proofReference);
    event KycVerified(address indexed memberAddress, bool status);
    event MembershipFeeUpdated(uint256 newFee);
    
    /**
     * @dev Constructor for the Membership contract
     * @param _initialOwner Address that will own the contract
     * @param _membershipFee Initial membership fee (0 if no fee)
     * @param _membershipToken Address of ERC20 token used for fees (address(0) if ETH)
     */
    constructor(
        address _initialOwner,
        uint256 _membershipFee,
        address _membershipToken
    ) Ownable(_initialOwner) {
        membershipFee = _membershipFee;
        membershipToken = IERC20(_membershipToken);
    }
    
    /**
     * @dev Register a new member
     * @param _name Name or ID of the member
     * @param _solarProof Reference to proof of solar installation (IPFS hash or similar)
     */
    function registerMember(string memory _name, string memory _solarProof) external nonReentrant {
        require(members[msg.sender].status == MembershipStatus.None, "Already registered");
        
        // Handle membership fee if applicable
        if (membershipFee > 0) {
            if (address(membershipToken) != address(0)) {
                // ERC20 token payment
                require(
                    membershipToken.transferFrom(msg.sender, address(this), membershipFee),
                    "Fee payment failed"
                );
            } else {
                // ETH payment
                require(msg.value >= membershipFee, "Insufficient fee");
            }
        }
        
        // Create new member with pending status
        members[msg.sender] = Member({
            name: _name,
            solarInstallationProof: _solarProof,
            status: MembershipStatus.Pending, // Needs approval
            walletAddress: msg.sender,
            joinDate: block.timestamp,
            kycVerified: false,
            energyContribution: 0
        });
        
        memberAddresses.push(msg.sender);
        
        emit MemberRegistered(msg.sender, _name, block.timestamp);
    }
    
    /**
     * @dev Update membership status (admin only)
     * @param _memberAddress Address of the member
     * @param _status New membership status
     */
    function updateMembershipStatus(address _memberAddress, MembershipStatus _status) 
        external 
        onlyOwner 
    {
        require(members[_memberAddress].status != MembershipStatus.None, "Member does not exist");
        members[_memberAddress].status = _status;
        emit MembershipStatusChanged(_memberAddress, _status);
    }
    
    /**
     * @dev Update solar installation proof
     * @param _newProof New reference to proof of solar installation
     */
    function updateSolarProof(string memory _newProof) external {
        require(members[msg.sender].status != MembershipStatus.None, "Not a member");
        members[msg.sender].solarInstallationProof = _newProof;
        emit SolarInstallationProofUpdated(msg.sender, _newProof);
    }
    
    /**
     * @dev Update KYC verification status (admin only)
     * @param _memberAddress Address of the member
     * @param _verified New verification status
     */
    function updateKycStatus(address _memberAddress, bool _verified) 
        external 
        onlyOwner 
    {
        require(members[_memberAddress].status != MembershipStatus.None, "Member does not exist");
        members[_memberAddress].kycVerified = _verified;
        emit KycVerified(_memberAddress, _verified);
    }
    
    /**
     * @dev Update membership fee (admin only)
     * @param _newFee New membership fee
     */
    function updateMembershipFee(uint256 _newFee) 
        external 
        onlyOwner 
    {
        membershipFee = _newFee;
        emit MembershipFeeUpdated(_newFee);
    }
    
    /**
     * @dev Get member details
     * @param _memberAddress Address of the member
     * @return Member information
     */
    function getMember(address _memberAddress) 
        external 
        view 
        returns (Member memory) 
    {
        return members[_memberAddress];
    }
    
    /**
     * @dev Check if an address is an active member
     * @param _address Address to check
     * @return True if the address is an active member
     */
    function isActiveMember(address _address) 
        external 
        view 
        returns (bool) 
    {
        return members[_address].status == MembershipStatus.Active;
    }
    
    /**
     * @dev Get total number of members
     * @return Number of registered members
     */
    function getTotalMembers() 
        external 
        view 
        returns (uint256) 
    {
        return memberAddresses.length;
    }
    
    /**
     * @dev Update member's energy contribution (called by EnergyManagement contract)
     * @param _memberAddress Address of the member
     * @param _amount Amount of energy to add to contribution
     */
    function updateEnergyContribution(address _memberAddress, uint256 _amount) 
        external
        // In production, restrict this to energy management contract only
    {
        require(members[_memberAddress].status == MembershipStatus.Active, "Not active member");
        members[_memberAddress].energyContribution += _amount;
    }
    
    /**
     * @dev Withdraw fees collected (admin only)
     * @param _to Address to send the funds
     */
    function withdrawFees(address _to) 
        external 
        onlyOwner 
        nonReentrant 
    {
        if (address(membershipToken) != address(0)) {
            uint256 balance = membershipToken.balanceOf(address(this));
            require(membershipToken.transfer(_to, balance), "Transfer failed");
        } else {
            (bool success, ) = payable(_to).call{value: address(this).balance}("");
            require(success, "Transfer failed");
        }
    }
    
    // Allow receiving ETH for membership fees
    receive() external payable {}
}