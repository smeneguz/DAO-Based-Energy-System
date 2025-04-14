# Energy Community DAO - Quick Start Guide

This document provides the essential information needed to quickly set up and test the Energy Community DAO prototype.

## Prerequisites

- Node.js (v14+)
- npm or yarn
- MetaMask or another Web3 wallet
- Git

## System Requirements

- Minimum 4GB RAM
- At least 1GB free disk space
- Modern web browser (Chrome, Firefox, Edge)

## Project Setup in 5 Steps

### 1. Clone and Install

```bash
# Clone the repository
git clone https://github.com/yourusername/energy-community-dao.git
cd energy-community-dao

# Install dependencies
npm install

# Install frontend dependencies
cd frontend
npm install
cd ..
```

### 2. Compile Contracts

```bash
npx hardhat compile
```

### 3. Start Local Blockchain and Deploy

```bash
# In terminal 1: Start local Hardhat node
npx hardhat node

# In terminal 2: Deploy contracts
npx hardhat run scripts/deploy.js --network localhost
```

Note the addresses of the deployed contracts - you'll need them for the frontend.

### 4. Configure Frontend

Edit `frontend/src/contexts/Web3Context.jsx` to update the contract addresses:

```javascript
const CONTRACT_ADDRESSES = {
  membership: '0x...',  // Replace with deployed address
  energyManagement: '0x...',  // Replace with deployed address
  governance: '0x...',  // Replace with deployed address
  treasury: '0x...',  // Replace with deployed address
  token: '0x...'  // Replace with deployed address
};
```

### 5. Start Frontend

```bash
cd frontend
npm start
```

The application will open in your browser at http://localhost:3000.

## Testing the System

### 1. Connect Your Wallet

- In your browser, connect MetaMask to the local network:
  - Network Name: Localhost
  - RPC URL: http://localhost:8545
  - Chain ID: 1337
  - Currency Symbol: ETH

- Import a test account from Hardhat using the private key (displayed when you ran `npx hardhat node`)

### 2. Run Through Key User Flows

#### Community Setup (Admin)
1. Register as the first member
2. As the admin (deployer), approve your own membership
3. Add yourself as a treasury signer if not done in deployment

#### Member Registration
1. Register as a member by providing a name and solar proof
2. Approve the token transaction for membership fee
3. Wait for admin approval (or approve yourself if testing as admin)

#### Energy Trading
1. Place a sell order for energy
2. Using another account, place a matching buy order
3. Verify the orders are matched and settled

#### Governance
1. Create a proposal (e.g., to change a parameter)
2. Vote on the proposal
3. After the voting period, check the proposal status
4. Execute the proposal if passed

#### Treasury Management
1. Propose a withdrawal from the treasury
2. Approve the withdrawal (requires multiple signers in production)
3. Verify the withdrawal execution

## Key Files to Review

### Smart Contracts
- `contracts/EnergyCommunityMembership.sol`
- `contracts/EnergyManagement.sol`
- `contracts/EnergyCommunityGovernance.sol`
- `contracts/EnergyCommunityTreasury.sol`

### Test Scripts
- `test/energy-community-integration.js`

### Frontend Components
- `frontend/src/contexts/Web3Context.jsx`
- `frontend/src/components/membership/RegisterForm.jsx`
- `frontend/src/components/energy/EnergyOrderForm.jsx`
- `frontend/src/components/governance/ProposalForm.jsx`
- `frontend/src/components/treasury/WithdrawalForm.jsx`

## Troubleshooting

### Common Issues

1. **MetaMask Connection Issues**
   - Ensure you're connected to the correct network (localhost:8545)
   - Reset your account in MetaMask if you encounter nonce issues

2. **Contract Deployment Failures**
   - Make sure Hardhat node is running
   - Check that you have sufficient test ETH

3. **Frontend Connection Issues**
   - Verify contract addresses are correctly updated in Web3Context.jsx
   - Check browser console for specific errors

### Getting Help

If you encounter issues not covered in this guide:

1. Check the detailed documentation in the `docs/` folder
2. Review the contract code comments for function explanations
3. Examine the test scripts to understand expected behavior