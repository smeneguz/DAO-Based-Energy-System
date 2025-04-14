// Hardhat deployment script for Energy Community DAO
// File: scripts/deploy.js

const { ethers, upgrades } = require("hardhat");

async function main() {
  console.log("Deploying Energy Community DAO contracts...");

  const [deployer, signer1, signer2, signer3] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // 1. Deploy Governance Token (for demonstration purposes)
  console.log("Deploying Governance Token...");
  const GovernanceToken = await ethers.getContractFactory("EnergyDAOToken");
  const governanceToken = await GovernanceToken.deploy(
    "Energy Community Token",
    "ECT",
    ethers.utils.parseEther("1000000") // 1 million tokens
  );
  await governanceToken.deployed();
  console.log("Governance Token deployed to:", governanceToken.address);

  // Distribute tokens to test accounts (for testing)
  const initialBalance = ethers.utils.parseEther("10000");
  await governanceToken.transfer(signer1.address, initialBalance);
  await governanceToken.transfer(signer2.address, initialBalance);
  await governanceToken.transfer(signer3.address, initialBalance);
  console.log("Initial token distribution complete");

  // 2. Deploy Membership Contract
  console.log("Deploying Membership Contract...");
  const Membership = await ethers.getContractFactory("EnergyCommunityMembership");
  const membership = await Membership.deploy(
    deployer.address,
    ethers.utils.parseEther("100"), // 100 token membership fee
    governanceToken.address
  );
  await membership.deployed();
  console.log("Membership Contract deployed to:", membership.address);

  // 3. Deploy Treasury Contract
  console.log("Deploying Treasury Contract...");
  const Treasury = await ethers.getContractFactory("EnergyCommunityTreasury");
  const initialSigners = [deployer.address, signer1.address, signer2.address];
  const treasury = await Treasury.deploy(
    deployer.address,
    membership.address,
    governanceToken.address,
    initialSigners,
    2 // Require 2 signatures for withdrawals
  );
  await treasury.deployed();
  console.log("Treasury Contract deployed to:", treasury.address);

  // 4. Deploy Governance Contract
  console.log("Deploying Governance Contract...");
  const Governance = await ethers.getContractFactory("EnergyCommunityGovernance");
  const governance = await Governance.deploy(
    deployer.address,
    membership.address,
    governanceToken.address,
    ethers.utils.parseEther("1000"), // 1000 tokens to create a proposal
    2000 // 20% quorum (in basis points)
  );
  await governance.deployed();
  console.log("Governance Contract deployed to:", governance.address);

  // 5. Deploy Energy Management Contract
  console.log("Deploying Energy Management Contract...");
  const EnergyManagement = await ethers.getContractFactory("EnergyManagement");
  const energyManagement = await EnergyManagement.deploy(
    deployer.address,
    membership.address,
    treasury.address,
    governanceToken.address,
    200 // 2% fee (in basis points)
  );
  await energyManagement.deployed();
  console.log("Energy Management Contract deployed to:", energyManagement.address);

  // Verify the deployment
  console.log("\nAll contracts deployed successfully!");
  console.log("Contract Addresses:");
  console.log("- Governance Token:", governanceToken.address);
  console.log("- Membership:", membership.address);
  console.log("- Treasury:", treasury.address);
  console.log("- Governance:", governance.address);
  console.log("- Energy Management:", energyManagement.address);
  
  // Additional setup if needed
  console.log("\nPerforming additional setup...");
  
  // Grant roles or permissions if needed
  // For example, if the Energy Management contract needs special permission to call the Treasury:
  // await treasury.grantRole(ENERGY_MANAGER_ROLE, energyManagement.address);
  
  console.log("Deployment and setup complete!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });