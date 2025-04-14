# Energy Community DAO - Paper Restricted Version (extrapolate for simulation)

A blockchain-based prototype for a decentralized energy community where households with solar panels can sell excess energy to other members.

## Table of Contents

- [Overview](#overview)
- [Repository Structure](#repository-structure)
- [System Components](#system-components)
- [Getting Started](#getting-started)
- [Smart Contracts](#smart-contracts)
- [Frontend Application](#frontend-application)
- [Testing](#testing)
- [Deployment](#deployment)
- [Security Considerations](#security-considerations)
- [Future Enhancements](#future-enhancements)

## Overview

This prototype enables the creation of a DAO-based energy community with the following features:

- **Member registration and verification** of solar installations
- **Energy trading** with buy/sell orders and automatic matching
- **Community governance** through proposals and voting
- **Treasury management** with multisig control and automatic rewards

## Repository Structure

```
energy-community-dao/
├── contracts/                 # Solidity smart contracts
│   ├── EnergyCommunityMembership.sol
│   ├── EnergyManagement.sol
│   ├── EnergyCommunityGovernance.sol
│   ├── EnergyCommunityTreasury.sol
│   └── EnergyDAOToken.sol
├── scripts/                   # Deployment and utility scripts
│   ├── deploy.js
│   └── utils/
├── test/                      # Test scripts
│   ├── energy-community-integration.js
│   └── unit/
├── frontend/                  # React frontend application
│   ├── public/
│   ├── src/
│   │   ├── components/        # UI components
│   │   │   ├── common/
│   │   │   ├── membership/
│   │   │   ├── energy/
│   │   │   ├── governance/
│   │   │   └── treasury/
│   │   ├── contexts/          # React contexts for state management
│   │   ├── utils/             # Helper functions
│   │   ├── abis/              # Contract ABIs
│   │   └── App.jsx
│   ├── package.json
│   └── README.md              # Frontend-specific instructions
├── docs/                      # Documentation
│   ├── deployment-guide.md    # Detailed deployment instructions
│   ├── frontend-integration.md # Frontend integration guide
│   └── project-summary.md     # Overall project summary
├── .env.example               # Example environment variables
├── hardhat.config.js          # Hardhat configuration
├── package.json
└── README.md                  # This file
```

## System Components

### Smart Contracts

1. **Membership Contract** (`contracts/EnergyCommunityMembership.sol`)
   - Manages member registration and verification
   - Tracks solar installation proof

2. **Energy Management Contract** (`contracts/EnergyManagement.sol`)
   - Handles buy/sell orders for energy
   - Implements order matching and settlement

3. **Governance Contract** (`contracts/EnergyCommunityGovernance.sol`)
   - Enables proposal creation and voting
   - Automatically executes approved proposals

4. **Treasury Contract** (`contracts/EnergyCommunityTreasury.sol`)
   - Controls DAO funds with multisig security
   - Distributes rewards to energy producers

### Frontend Application

The React frontend (`frontend/`) provides user interfaces for:
- Member registration and profile management
- Placing and viewing energy orders
- Creating and voting on governance proposals
- Managing treasury operations (for authorized users)

## Getting Started

### Prerequisites

- Node.js (v14+)
- npm or yarn
- MetaMask or similar Web3 wallet
- Git

### Installation

1. **Clone the repository**

```bash
git clone https://github.com/yourusername/energy-community-dao.git
cd energy-community-dao
```

2. **Install dependencies**

```bash
# Install root project dependencies
npm install

# Install frontend dependencies
cd frontend
npm install
cd ..
```

3. **Configure environment**

```bash
# Copy and modify the example environment file
cp .env.example .env
```

Edit the `.env` file to add your configuration settings.

### Compilation

```bash
# Compile smart contracts
npx hardhat compile
```

## Smart Contracts

For detailed information about the smart contracts, see the individual source files. Each contract includes comprehensive documentation in the form of NatSpec comments explaining functionality, parameters, and security considerations.

Key contracts:

- `EnergyCommunityMembership.sol`: Handles member registration and management
- `EnergyManagement.sol`: Manages energy trading with buy/sell orders
- `EnergyCommunityGovernance.sol`: Provides community decision-making capabilities
- `EnergyCommunityTreasury.sol`: Controls DAO funds and reward distribution

## Frontend Application

The frontend application is built with React and uses ethers.js for blockchain interaction. To start the frontend in development mode:

```bash
cd frontend
npm start
```

This will start the development server and open the application in your default browser at `http://localhost:3000`.

For detailed frontend documentation, see `frontend/README.md`.

## Testing

Comprehensive tests are provided in the `test/` directory:

### Integration Tests

```bash
# Run the integrated tests
npx hardhat test test/energy-community-integration.js
```

This will test the complete workflow from member registration to energy trading, governance, and treasury operations.

### Unit Tests

```bash
# Run all unit tests
npx hardhat test test/unit/

# Run specific test
npx hardhat test test/unit/Membership.test.js
```

## Deployment

### Local Development

```bash
# Start local Hardhat node
npx hardhat node

# Deploy to local network
npx hardhat run scripts/deploy.js --network localhost
```

### Private PoA Chain

```bash
# Deploy to your PoA network (configured in hardhat.config.js)
npx hardhat run scripts/deploy.js --network privatepoa
```

For detailed deployment instructions, see `docs/deployment-guide.md`.

## Security Considerations

This prototype implements several security features:

- **Re-entrancy Protection** using OpenZeppelin's ReentrancyGuard
- **Access Control** with Ownable pattern and custom permissioning
- **Integer Overflow Protection** via Solidity 0.8.x's built-in checks
- **Multi-signature Requirements** for treasury operations

Before production deployment, consider:
- Professional security audit
- Further testing in realistic conditions
- Gradual rollout with value limits

## Future Enhancements

Potential improvements for future versions:

1. **Advanced Energy Pricing**
   - Dynamic pricing based on supply/demand
   - Time-of-day based pricing tiers

2. **Enhanced Governance**
   - Delegation of voting power
   - Specialized committees

3. **Technical Integrations**
   - IoT integration with smart meters
   - Weather prediction for energy forecasting

4. **Scalability Solutions**
   - Layer-2 integration for lower costs
   - Cross-chain interoperability

## License

[MIT](LICENSE)