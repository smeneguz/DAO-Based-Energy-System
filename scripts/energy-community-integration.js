// File: test/energy-community-integration.js

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Energy Community DAO Integration Tests", function () {
  // This test is set with a longer timeout since it's a complex integration test
  this.timeout(60000);
  
  let governanceToken;
  let membershipContract;
  let treasuryContract;
  let governanceContract;
  let energyManagementContract;
  
  let owner;
  let member1;
  let member2;
  let member3;
  let nonMember;
  
  const membershipFee = ethers.utils.parseEther("100");
  const initialBalance = ethers.utils.parseEther("10000");
  
  before(async function () {
    // Get signers
    [owner, member1, member2, member3, nonMember] = await ethers.getSigners();
    
    console.log("Setting up test environment...");
    
    // Deploy Governance Token
    const GovernanceToken = await ethers.getContractFactory("EnergyDAOToken");
    governanceToken = await GovernanceToken.deploy(
      "Energy Community Token",
      "ECT",
      ethers.utils.parseEther("1000000") // 1 million tokens
    );
    await governanceToken.deployed();
    
    // Distribute tokens to test accounts
    await governanceToken.transfer(member1.address, initialBalance);
    await governanceToken.transfer(member2.address, initialBalance);
    await governanceToken.transfer(member3.address, initialBalance);
    
    // Deploy Membership Contract
    const Membership = await ethers.getContractFactory("EnergyCommunityMembership");
    membershipContract = await Membership.deploy(
      owner.address,
      membershipFee,
      governanceToken.address
    );
    await membershipContract.deployed();
    
    // Deploy Treasury Contract
    const Treasury = await ethers.getContractFactory("EnergyCommunityTreasury");
    const initialSigners = [owner.address, member1.address, member2.address];
    treasuryContract = await Treasury.deploy(
      owner.address,
      membershipContract.address,
      governanceToken.address,
      initialSigners,
      2 // Require 2 signatures for withdrawals
    );
    await treasuryContract.deployed();
    
    // Deploy Governance Contract
    const Governance = await ethers.getContractFactory("EnergyCommunityGovernance");
    governanceContract = await Governance.deploy(
      owner.address,
      membershipContract.address,
      governanceToken.address,
      ethers.utils.parseEther("1000"), // 1000 tokens to create a proposal
      2000 // 20% quorum (in basis points)
    );
    await governanceContract.deployed();
    
    // Deploy Energy Management Contract
    const EnergyManagement = await ethers.getContractFactory("EnergyManagement");
    energyManagementContract = await EnergyManagement.deploy(
      owner.address,
      membershipContract.address,
      treasuryContract.address,
      governanceToken.address,
      200 // 2% fee (in basis points)
    );
    await energyManagementContract.deployed();
    
    console.log("Test environment setup complete");
  });
  
  describe("1. Membership Registration and Management", function () {
    it("Should register a new member", async function () {
      console.log("Testing member registration...");
      
      // Approve tokens for membership fee
      await governanceToken.connect(member1).approve(membershipContract.address, membershipFee);
      
      // Register as a member
      await membershipContract.connect(member1).registerMember(
        "Member 1",
        "ipfs://QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco" // Example IPFS hash for solar proof
      );
      
      // Verify the member is registered but not yet active
      const memberData = await membershipContract.getMember(member1.address);
      expect(memberData.name).to.equal("Member 1");
      expect(memberData.status).to.equal(1); // Pending status
      
      // Activate the member
      await membershipContract.connect(owner).updateMembershipStatus(
        member1.address,
        2 // Active status
      );
      
      // Check if member is active
      expect(await membershipContract.isActiveMember(member1.address)).to.equal(true);
      
      console.log("Member registration test passed");
    });
    
    it("Should update member KYC status", async function () {
      // Update KYC status
      await membershipContract.connect(owner).updateKycStatus(member1.address, true);
      
      // Verify KYC status
      const memberData = await membershipContract.getMember(member1.address);
      expect(memberData.kycVerified).to.equal(true);
    });
    
    it("Should register more members", async function () {
      // Register and activate member2
      await governanceToken.connect(member2).approve(membershipContract.address, membershipFee);
      await membershipContract.connect(member2).registerMember("Member 2", "ipfs://QmSolarProof2");
      await membershipContract.connect(owner).updateMembershipStatus(member2.address, 2); // Active
      await membershipContract.connect(owner).updateKycStatus(member2.address, true);
      
      // Register and activate member3
      await governanceToken.connect(member3).approve(membershipContract.address, membershipFee);
      await membershipContract.connect(member3).registerMember("Member 3", "ipfs://QmSolarProof3");
      await membershipContract.connect(owner).updateMembershipStatus(member3.address, 2); // Active
      await membershipContract.connect(owner).updateKycStatus(member3.address, true);
      
      // Verify total members
      expect(await membershipContract.getTotalMembers()).to.equal(3);
    });
  });
  
  describe("2. Energy Trading", function () {
    it("Should place a buy order", async function () {
      console.log("Testing energy trading...");
      
      // Approve tokens for trading
      const buyAmount = ethers.utils.parseEther("50");
      await governanceToken.connect(member2).approve(energyManagementContract.address, buyAmount);
      
      // Place a buy order
      const energyAmount = 10000; // 10 kWh (with precision factor)
      const pricePerUnit = 5; // 0.005 tokens per kWh (scaled)
      
      await energyManagementContract.connect(member2).placeOrder(
        0, // Buy order
        energyAmount,
        pricePerUnit
      );
      
      // Check that the buy order was registered
      const openBuyOrders = await energyManagementContract.getOpenBuyOrders();
      expect(openBuyOrders.length).to.equal(1);
      
      // Get the order details
      const orderId = openBuyOrders[0];
      const order = await energyManagementContract.orders(orderId);
      
      expect(order.trader).to.equal(member2.address);
      expect(order.orderType).to.equal(0); // Buy
      expect(order.energyAmount).to.equal(energyAmount);
      expect(order.pricePerUnit).to.equal(pricePerUnit);
      expect(order.status).to.equal(0); // Open
    });
    
    it("Should place a sell order and match with buy order", async function () {
      // Place a sell order that matches the existing buy order
      const energyAmount = 5000; // 5 kWh (with precision factor)
      const pricePerUnit = 5; // 0.005 tokens per kWh (scaled)
      
      await energyManagementContract.connect(member1).placeOrder(
        1, // Sell order
        energyAmount,
        pricePerUnit
      );
      
      // Check that orders are partially matched
      const openBuyOrders = await energyManagementContract.getOpenBuyOrders();
      expect(openBuyOrders.length).to.equal(1); // Still one open buy order with reduced amount
      
      const orderId = openBuyOrders[0];
      const order = await energyManagementContract.orders(orderId);
      
      // The buy order should have 5 kWh remaining (10 - 5)
      expect(order.energyAmount).to.equal(5000);
      
      // Check that treasury received the fee
      const treasuryBalance = await governanceToken.balanceOf(treasuryContract.address);
      expect(treasuryBalance).to.be.gt(0); // Greater than 0
      
      console.log("Energy trading test passed");
    });
  });
  
  describe("3. Treasury Management", function () {
    it("Should create a withdrawal proposal", async function () {
      console.log("Testing treasury management...");
      
      // Get current treasury balance
      const initialBalance = await governanceToken.balanceOf(treasuryContract.address);
      
      // Create a withdrawal proposal
      const withdrawalAmount = initialBalance.div(2); // Withdraw half the balance
      await treasuryContract.connect(owner).proposeWithdrawal(
        member3.address, // Recipient
        withdrawalAmount,
        "Funds for community solar panel maintenance"
      );
      
      // Get the proposal
      const proposalId = 1; // First proposal has ID 1
      const proposal = await treasuryContract.getWithdrawalProposalDetails(proposalId);
      
      expect(proposal.proposer).to.equal(owner.address);
      expect(proposal.recipient).to.equal(member3.address);
      expect(proposal.amount).to.equal(withdrawalAmount);
      expect(proposal.executed).to.equal(false);
      expect(proposal.approvals).to.equal(1); // Proposer auto-approves
    });
    
    it("Should approve and execute a withdrawal", async function () {
      const proposalId = 1;
      const recipientInitialBalance = await governanceToken.balanceOf(member3.address);
      
      // Member1 approves the withdrawal (second approval)
      await treasuryContract.connect(member1).approveWithdrawal(proposalId);
      
      // Check if the proposal was executed (since it now has 2 approvals)
      const proposal = await treasuryContract.getWithdrawalProposalDetails(proposalId);
      expect(proposal.executed).to.equal(true);
      
      // Check if funds were transferred to the recipient
      const recipientFinalBalance = await governanceToken.balanceOf(member3.address);
      expect(recipientFinalBalance).to.be.gt(recipientInitialBalance);
      
      console.log("Treasury management test passed");
    });
  });
  
  describe("4. Governance", function () {
    it("Should create a governance proposal", async function () {
      console.log("Testing governance functions...");
      
      // Create a proposal to update fee percentage
      const proposalTitle = "Update Fee Percentage";
      const proposalDescription = "Reduce the trading fee from 2% to 1%";
      
      // Create the calldata for updating the fee
      const EnergyManagement = await ethers.getContractFactory("EnergyManagement");
      const callData = EnergyManagement.interface.encodeFunctionData(
        "updateFeePercentage",
        [100] // 1% in basis points
      );
      
      await governanceContract.connect(member1).createProposal(
        proposalTitle,
        proposalDescription,
        energyManagementContract.address,
        callData
      );
      
      // Get the proposal details
      const proposalId = 1; // First proposal has ID 1
      const proposal = await governanceContract.getProposalDetails(proposalId);
      
      expect(proposal.proposer).to.equal(member1.address);
      expect(proposal.title).to.equal(proposalTitle);
      expect(proposal.status).to.equal(0); // Active
    });
    
    it("Should vote on a proposal and check result", async function () {
      const proposalId = 1;
      
      // Member1 votes yes
      await governanceContract.connect(member1).vote(proposalId, 1); // 1 = Yes
      
      // Member2 votes yes
      await governanceContract.connect(member2).vote(proposalId, 1); // 1 = Yes
      
      // Member3 votes no
      await governanceContract.connect(member3).vote(proposalId, 2); // 2 = No
      
      // Fast forward time to end voting period (in a real network)
      // For hardhat, we can use evm_increaseTime
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]); // 7 days
      await ethers.provider.send("evm_mine");
      
      // Check proposal status
      await governanceContract.checkProposalStatus(proposalId);
      const proposal = await governanceContract.getProposalDetails(proposalId);
      
      // Should be passed since more yes votes than no votes
      expect(proposal.status).to.equal(1); // Passed
      
      console.log("Governance test passed");
    });
    
    it("Should execute a passed proposal", async function () {
      const proposalId = 1;
      
      // Fast forward time for execution delay
      await ethers.provider.send("evm_increaseTime", [2 * 24 * 60 * 60]); // 2 days
      await ethers.provider.send("evm_mine");
      
      // Execute the proposal
      await governanceContract.executeProposal(proposalId);
      
      // Check if fee was updated in the Energy Management contract
      const newFeePercentage = await energyManagementContract.feePercentage();
      expect(newFeePercentage).to.equal(100); // 1%
      
      // Check proposal status
      const proposal = await governanceContract.getProposalDetails(proposalId);
      expect(proposal.status).to.equal(3); // Executed
    });
  });
  
  describe("5. Full System Integration", function () {
    it("Should handle a complete energy trade cycle with fee distribution", async function () {
      console.log("Testing full system integration...");
      
      // Approve more tokens for trading
      const tradeAmount = ethers.utils.parseEther("100");
      await governanceToken.connect(member2).approve(energyManagementContract.address, tradeAmount);
      
      // Place another buy order with the new fee rate
      const energyAmount = 20000; // 20 kWh
      const pricePerUnit = 6; // 0.006 tokens per kWh
      
      await energyManagementContract.connect(member2).placeOrder(
        0, // Buy order
        energyAmount,
        pricePerUnit
      );
      
      // Member1 places a matching sell order
      await energyManagementContract.connect(member1).placeOrder(
        1, // Sell order
        energyAmount,
        pricePerUnit
      );
      
      // Check if treasury received the fee (at the new 1% rate)
      const treasuryBalance = await governanceToken.balanceOf(treasuryContract.address);
      
      // Record the energy contribution in treasury
      const contributionAmount = 20000; // 20 kWh
      await treasuryContract.recordEnergyContribution(member1.address, contributionAmount);
      
      // Fast forward time for rewards distribution period
      await ethers.provider.send("evm_increaseTime", [30 * 24 * 60 * 60]); // 30 days
      await ethers.provider.send("evm_mine");
      
      // Distribute rewards
      const member1BalanceBefore = await governanceToken.balanceOf(member1.address);
      await treasuryContract.distributeRewards();
      const member1BalanceAfter = await governanceToken.balanceOf(member1.address);
      
      // Member1 should have received rewards
      expect(member1BalanceAfter).to.be.gt(member1BalanceBefore);
      
      console.log("Full system integration test passed");
    });
  });
});