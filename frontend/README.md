# Energy Community DAO Frontend

React-based frontend application for interacting with the Energy Community DAO smart contracts.

## Table of Contents

- [Overview](#overview)
- [Application Structure](#application-structure)
- [Setup and Installation](#setup-and-installation)
- [Key Components](#key-components)
- [Contract Integration](#contract-integration)
- [User Workflows](#user-workflows)
- [Configuration](#configuration)
- [Development](#development)
- [Building for Production](#building-for-production)
- [Troubleshooting](#troubleshooting)

## Overview

This frontend application provides a user interface for all major functions of the Energy Community DAO:

- Member registration and profile management
- Energy trading with buy/sell orders
- Creating and voting on governance proposals
- Treasury management and rewards distribution

## Application Structure

```
src/
├── components/             # React components organized by function
│   ├── common/             # Shared UI components
│   │   ├── Header.jsx
│   │   ├── Footer.jsx
│   │   ├── WalletConnect.jsx
│   │   └── Loader.jsx
│   ├── membership/         # Membership management components
│   │   ├── RegisterForm.jsx
│   │   └── MemberList.jsx
│   ├── energy/             # Energy trading components
│   │   ├── EnergyOrderForm.jsx
│   │   └── OrderBook.jsx
│   ├── governance/         # Governance components
│   │   ├── ProposalForm.jsx
│   │   └── ProposalList.jsx
│   └── treasury/           # Treasury management components
│       ├── WithdrawalForm.jsx
│       └── TreasuryStats.jsx
├── contexts/               # React contexts for state management
│   └── Web3Context.jsx     # Manages Web3 connections and contracts
├── utils/                  # Helper functions and utilities
│   ├── contractHelpers.js  # Contract interaction helpers
│   └── formatters.js       # Data formatting utilities
├── abis/                   # Contract ABIs (generated after compilation)
│   ├── EnergyCommunityMembership.json
│   ├── EnergyManagement.json
│   ├── EnergyCommunityGovernance.json
│   ├── EnergyCommunityTreasury.json
│   └── EnergyDAOToken.json
└── App.jsx                 # Main application component
```

## Setup and Installation

### Prerequisites

- Node.js (v14+)
- npm or yarn
- MetaMask browser extension

### Installation

1. Install dependencies:

```bash
npm install
```

2. Configure contract addresses:

Copy the deployed contract addresses from the main project deployment into `src/contexts/Web3Context.jsx` under the `CONTRACT_ADDRESSES` object.

3. Start the development server:

```bash
npm start
```

This will run the app in development mode. Open [http://localhost:3000](http://localhost:3000) to view it in your browser.

## Key Components

### Web3 Integration

The `Web3Context.jsx` handles:
- Wallet connection via Web3Modal
- Contract instantiation using ethers.js
- User authentication
- Transaction handling

### Membership Management

- `RegisterForm.jsx`: Allows new users to register as members
- `MemberList.jsx`: Displays all registered members and their status

### Energy Trading

- `EnergyOrderForm.jsx`: Interface for placing buy/sell energy orders
- `OrderBook.jsx`: Displays all open orders and allows order cancellation

### Governance

- `ProposalForm.jsx`: Interface for creating governance proposals
- `ProposalList.jsx`: Displays proposals and enables voting

### Treasury Management

- `WithdrawalForm.jsx`: Interface for creating withdrawal proposals (for signers)
- `TreasuryStats.jsx`: Displays treasury stats and enables rewards distribution

## Contract Integration

The application interacts with the smart contracts through the ethers.js library. Key interactions include:

### Membership Contract

```javascript
// Register as a member
const tx = await contracts.membership.registerMember(name, solarProof);
await tx.wait();

// Check if address is an active member
const isActive = await contracts.membership.isActiveMember(address);
```

### Energy Management Contract

```javascript
// Place an energy order
const tx = await contracts.energyManagement.placeOrder(orderType, energyAmount, pricePerUnit);
await tx.wait();

// Get open buy orders
const orderIds = await contracts.energyManagement.getOpenBuyOrders();
```

### Governance Contract

```javascript
// Create a proposal
const tx = await contracts.governance.createProposal(title, description, targetContract, callData);
await tx.wait();

// Vote on a proposal
await contracts.governance.vote(proposalId, voteType);
```

### Treasury Contract

```javascript
// Create a withdrawal proposal
const tx = await contracts.treasury.proposeWithdrawal(recipient, amount, description);
await tx.wait();

// Distribute rewards
await contracts.treasury.distributeRewards();
```

## User Workflows

### Member Registration

1. Connect wallet using the "Connect Wallet" button
2. Navigate to Membership section
3. Fill out the registration form with name and solar proof
4. Submit the form to register (requires membership fee approval)
5. Wait for admin approval of membership

### Energy Trading

1. Navigate to Energy Trading section
2. Use the order form to place a buy or sell order
   - For buy orders, tokens equal to the order value will be locked
3. View all open orders in the Order Book
4. Cancel your own orders if needed

### Governance Participation

1. Navigate to Governance section
2. Create a proposal or view existing proposals
3. Vote on active proposals (Yes, No, or Abstain)
4. Execute passed proposals after the execution delay

### Treasury Management

1. Navigate to Treasury section
2. Approved signers can create withdrawal proposals
3. Other signers can approve withdrawals
4. Anyone can trigger rewards distribution when the period has ended

## Configuration

### Environment Variables

The application can be configured through environment variables in a `.env` file:

```
REACT_APP_DEFAULT_NETWORK=1337
REACT_APP_IPFS_PROJECT_ID=your-ipfs-project-id
REACT_APP_IPFS_PROJECT_SECRET=your-ipfs-project-secret
```

### Contract Addresses

Update the contract addresses in `src/contexts/Web3Context.jsx`:

```javascript
const CONTRACT_ADDRESSES = {
  membership: '0x...',
  energyManagement: '0x...',
  governance: '0x...',
  treasury: '0x...',
  token: '0x...'
};
```

## Development

### Running Tests

```bash
npm test
```

### Linting

```bash
npm run lint
```

### Code Formatting

```bash
npm run format
```

## Building for Production

```bash
npm run build
```

This creates an optimized production build in the `build` folder.

## Troubleshooting

### Common Issues

1. **Wallet Connection Issues**
   - Ensure MetaMask is installed and unlocked
   - Make sure you're connected to the correct network

2. **Transaction Failures**
   - Check console for error messages
   - Verify you have sufficient funds for gas
   - Ensure contract approvals are in place for token operations

3. **Contract Interaction Errors**
   - Verify contract addresses are correct
   - Check that ABIs match the deployed contracts
   - Ensure you have the required permissions for restricted operations

### Debug Mode

Enable debug logging by setting:

```javascript
// In your browser console
localStorage.setItem('debug', 'energy-dao:*');
```

This will provide additional logging information for troubleshooting.