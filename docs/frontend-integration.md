# Frontend Integration Guide for Energy Community DAO

This guide explains how to integrate the Energy Community DAO smart contracts with a React frontend application. We'll cover setting up the project, connecting to wallets, and creating user interfaces for the core functionality.

## Table of Contents
1. [Project Setup](#project-setup)
2. [Smart Contract Integration](#smart-contract-integration)
3. [Key Components](#key-components)
4. [Sample Transactions](#sample-transactions)
5. [Testing Your Frontend](#testing-your-frontend)

## Project Setup

### 1. Create a New React Project

```bash
npx create-react-app energy-dao-frontend
cd energy-dao-frontend
```

### 2. Install Dependencies

```bash
npm install ethers@5.7.2 web3modal@1.9.12 react-router-dom@6 @emotion/react @emotion/styled @mui/material @mui/icons-material
```

### 3. Create a Project Structure

Organize your files as follows:

```
src/
├── components/
│   ├── common/
│   │   ├── Header.jsx
│   │   ├── Footer.jsx
│   │   ├── WalletConnect.jsx
│   │   └── Loader.jsx
│   ├── membership/
│   │   ├── RegisterForm.jsx
│   │   └── MemberList.jsx
│   ├── energy/
│   │   ├── EnergyOrderForm.jsx
│   │   └── OrderBook.jsx
│   ├── governance/
│   │   ├── ProposalForm.jsx
│   │   └── ProposalList.jsx
│   └── treasury/
│       ├── WithdrawalForm.jsx
│       └── TreasuryStats.jsx
├── contexts/
│   └── Web3Context.jsx
├── utils/
│   ├── contractHelpers.js
│   └── formatters.js
├── abis/
│   ├── EnergyCommunityMembership.json
│   ├── EnergyManagement.json
│   ├── EnergyCommunityGovernance.json
│   ├── EnergyCommunityTreasury.json
│   └── EnergyDAOToken.json
└── App.jsx
```

## Smart Contract Integration

### 1. Set Up Web3 Context

Create a context to manage Web3 connections and contracts:

```jsx
// src/contexts/Web3Context.jsx
import React, { createContext, useState, useEffect, useContext } from 'react';
import { ethers } from 'ethers';
import Web3Modal from 'web3modal';

// Import ABIs
import MembershipABI from '../abis/EnergyCommunityMembership.json';
import EnergyManagementABI from '../abis/EnergyManagement.json';
import GovernanceABI from '../abis/EnergyCommunityGovernance.json';
import TreasuryABI from '../abis/EnergyCommunityTreasury.json';
import TokenABI from '../abis/EnergyDAOToken.json';

const Web3Context = createContext();

// Replace with your deployed contract addresses
const CONTRACT_ADDRESSES = {
  membership: '0x...',
  energyManagement: '0x...',
  governance: '0x...',
  treasury: '0x...',
  token: '0x...'
};

export function Web3Provider({ children }) {
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [account, setAccount] = useState(null);
  const [contracts, setContracts] = useState({});
  const [isConnecting, setIsConnecting] = useState(false);
  const [error, setError] = useState(null);
  const [chainId, setChainId] = useState(null);

  // Initialize Web3Modal
  const web3Modal = new Web3Modal({
    network: "mainnet", // Can be changed based on your network
    cacheProvider: true,
    providerOptions: {}
  });

  // Connect wallet
  const connectWallet = async () => {
    try {
      setIsConnecting(true);
      setError(null);
      
      // Connect to wallet
      const instance = await web3Modal.connect();
      const provider = new ethers.providers.Web3Provider(instance);
      const signer = provider.getSigner();
      const network = await provider.getNetwork();
      const accounts = await provider.listAccounts();
      
      setProvider(provider);
      setSigner(signer);
      setAccount(accounts[0]);
      setChainId(network.chainId);
      
      // Initialize contracts
      initializeContracts(signer);
      
      // Setup event listeners
      instance.on("accountsChanged", (accounts) => {
        setAccount(accounts[0]);
      });
      
      instance.on("chainChanged", (chainId) => {
        window.location.reload();
      });
      
    } catch (err) {
      console.error("Error connecting wallet:", err);
      setError("Failed to connect wallet. Please try again.");
    } finally {
      setIsConnecting(false);
    }
  };

  // Disconnect wallet
  const disconnectWallet = async () => {
    await web3Modal.clearCachedProvider();
    setProvider(null);
    setSigner(null);
    setAccount(null);
    setContracts({});
  };

  // Initialize contract instances
  const initializeContracts = (signer) => {
    try {
      const membershipContract = new ethers.Contract(
        CONTRACT_ADDRESSES.membership,
        MembershipABI,
        signer
      );
      
      const energyManagementContract = new ethers.Contract(
        CONTRACT_ADDRESSES.energyManagement,
        EnergyManagementABI,
        signer
      );
      
      const governanceContract = new ethers.Contract(
        CONTRACT_ADDRESSES.governance,
        GovernanceABI,
        signer
      );
      
      const treasuryContract = new ethers.Contract(
        CONTRACT_ADDRESSES.treasury,
        TreasuryABI,
        signer
      );
      
      const tokenContract = new ethers.Contract(
        CONTRACT_ADDRESSES.token,
        TokenABI,
        signer
      );
      
      setContracts({
        membership: membershipContract,
        energyManagement: energyManagementContract,
        governance: governanceContract,
        treasury: treasuryContract,
        token: tokenContract
      });
    } catch (err) {
      console.error("Error initializing contracts:", err);
      setError("Failed to initialize contracts. Please check your network.");
    }
  };

  // Auto-connect if cached provider exists
  useEffect(() => {
    if (web3Modal.cachedProvider) {
      connectWallet();
    }
  }, []);

  return (
    <Web3Context.Provider value={{
      provider,
      signer,
      account,
      contracts,
      isConnecting,
      error,
      chainId,
      connectWallet,
      disconnectWallet
    }}>
      {children}
    </Web3Context.Provider>
  );
}

// Hook to use the Web3 context
export function useWeb3() {
  const context = useContext(Web3Context);
  if (!context) {
    throw new Error("useWeb3 must be used within a Web3Provider");
  }
  return context;
}
```

### 2. Create Contract Helper Functions

```javascript
// src/utils/contractHelpers.js
import { ethers } from 'ethers';

// Format energy amount from the contract format (kWh * 1000) to user-friendly format
export function formatEnergyAmount(amount) {
  return parseFloat(amount) / 1000;
}

// Format energy amount from user input to contract format
export function parseEnergyAmount(amount) {
  return Math.floor(parseFloat(amount) * 1000);
}

// Format token amounts
export function formatTokenAmount(amount) {
  return ethers.utils.formatEther(amount);
}

// Parse token amounts for contract calls
export function parseTokenAmount(amount) {
  return ethers.utils.parseEther(amount.toString());
}

// Format timestamp to readable date
export function formatDate(timestamp) {
  return new Date(timestamp * 1000).toLocaleString();
}

// Helper to check if an address is valid
export function isValidAddress(address) {
  return ethers.utils.isAddress(address);
}

// Truncate address for display
export function truncateAddress(address) {
  if (!address) return '';
  return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
}

// Format order type to readable string
export function formatOrderType(type) {
  return type === 0 ? 'Buy' : 'Sell';
}

// Format proposal status to readable string
export function formatProposalStatus(status) {
  const statuses = ['Active', 'Passed', 'Rejected', 'Executed', 'Canceled'];
  return statuses[status] || 'Unknown';
}

// Format membership status to readable string
export function formatMembershipStatus(status) {
  const statuses = ['None', 'Pending', 'Active', 'Suspended'];
  return statuses[status] || 'Unknown';
}
```

## Key Components

### 1. Wallet Connection Component

```jsx
// src/components/common/WalletConnect.jsx
import React from 'react';
import { Button, Typography, Box } from '@mui/material';
import { AccountBalanceWallet, ExitToApp } from '@mui/icons-material';
import { useWeb3 } from '../../contexts/Web3Context';
import { truncateAddress } from '../../utils/contractHelpers';

const WalletConnect = () => {
  const { account, connectWallet, disconnectWallet, isConnecting } = useWeb3();

  return (
    <Box>
      {account ? (
        <Box sx={{ display: 'flex', alignItems: 'center' }}>
          <Typography variant="body2" sx={{ mr: 2 }}>
            {truncateAddress(account)}
          </Typography>
          <Button 
            variant="outlined" 
            color="secondary" 
            size="small" 
            onClick={disconnectWallet}
            startIcon={<ExitToApp />}
          >
            Disconnect
          </Button>
        </Box>
      ) : (
        <Button 
          variant="contained" 
          color="primary" 
          onClick={connectWallet}
          disabled={isConnecting}
          startIcon={<AccountBalanceWallet />}
        >
          {isConnecting ? 'Connecting...' : 'Connect Wallet'}
        </Button>
      )}
    </Box>
  );
};

export default WalletConnect;
```

### 2. Member Registration Form

```jsx
// src/components/membership/RegisterForm.jsx
import React, { useState } from 'react';
import { 
  TextField, 
  Button, 
  Box, 
  Typography, 
  Paper, 
  CircularProgress, 
  Alert 
} from '@mui/material';
import { useWeb3 } from '../../contexts/Web3Context';
import { parseTokenAmount } from '../../utils/contractHelpers';

const RegisterForm = () => {
  const { contracts, account } = useWeb3();
  const [name, setName] = useState('');
  const [solarProof, setSolarProof] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [membershipFee, setMembershipFee] = useState('');

  // Fetch membership fee when contracts are loaded
  React.useEffect(() => {
    if (contracts.membership) {
      fetchMembershipFee();
    }
  }, [contracts.membership]);

  const fetchMembershipFee = async () => {
    try {
      const fee = await contracts.membership.membershipFee();
      setMembershipFee(ethers.utils.formatEther(fee));
    } catch (err) {
      console.error("Error fetching membership fee:", err);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!name || !solarProof) {
      setError('Please fill in all fields');
      return;
    }

    setIsSubmitting(true);
    setError('');
    setSuccess('');

    try {
      // Approve token transfer for membership fee
      const fee = await contracts.membership.membershipFee();
      const approveTx = await contracts.token.approve(contracts.membership.address, fee);
      await approveTx.wait();

      // Register member
      const tx = await contracts.membership.registerMember(name, solarProof);
      await tx.wait();

      setSuccess('Registration successful! Your membership is pending approval.');
      setName('');
      setSolarProof('');
    } catch (err) {
      console.error("Error registering:", err);
      setError(err.message || 'Registration failed. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!account) {
    return (
      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h6">Member Registration</Typography>
        <Alert severity="info">Please connect your wallet to register</Alert>
      </Paper>
    );
  }

  return (
    <Paper sx={{ p: 3, mb: 3 }}>
      <Typography variant="h6" gutterBottom>
        Register as Community Member
      </Typography>
      <Typography variant="body2" color="textSecondary" gutterBottom>
        Membership Fee: {membershipFee} tokens
      </Typography>

      <Box component="form" onSubmit={handleSubmit} noValidate sx={{ mt: 1 }}>
        <TextField
          margin="normal"
          required
          fullWidth
          label="Name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          disabled={isSubmitting}
        />
        <TextField
          margin="normal"
          required
          fullWidth
          label="Solar Installation Proof (IPFS hash or URL)"
          value={solarProof}
          onChange={(e) => setSolarProof(e.target.value)}
          placeholder="ipfs://... or https://..."
          disabled={isSubmitting}
        />
        {error && <Alert severity="error" sx={{ mt: 2 }}>{error}</Alert>}
        {success && <Alert severity="success" sx={{ mt: 2 }}>{success}</Alert>}
        <Button
          type="submit"
          fullWidth
          variant="contained"
          sx={{ mt: 3, mb: 2 }}
          disabled={isSubmitting}
        >
          {isSubmitting ? <CircularProgress size={24} /> : 'Register'}
        </Button>
      </Box>
    </Paper>
  );
};

export default RegisterForm;
```

### 3. Energy Trading Component

```jsx
// src/components/energy/EnergyOrderForm.jsx
import React, { useState } from 'react';
import { 
  TextField, 
  Button, 
  Box, 
  Typography, 
  Paper, 
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Alert,
  CircularProgress,
  InputAdornment
} from '@mui/material';
import { useWeb3 } from '../../contexts/Web3Context';
import { parseEnergyAmount, parseTokenAmount } from '../../utils/contractHelpers';

const EnergyOrderForm = () => {
  const { contracts, account } = useWeb3();
  const [orderType, setOrderType] = useState(0); // 0 = Buy, 1 = Sell
  const [energyAmount, setEnergyAmount] = useState('');
  const [pricePerUnit, setPricePerUnit] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!energyAmount || !pricePerUnit) {
      setError('Please fill in all fields');
      return;
    }

    setIsSubmitting(true);
    setError('');
    setSuccess('');

    try {
      // Format inputs for contract call
      const energy = parseEnergyAmount(energyAmount);
      const price = parseTokenAmount(pricePerUnit);
      
      // If buy order, approve tokens first
      if (orderType === 0) {
        const totalCost = energy * price / 1000; // Convert back from precision format
        await contracts.token.approve(contracts.energyManagement.address, totalCost);
      }
      
      // Place order
      const tx = await contracts.energyManagement.placeOrder(
        orderType,
        energy,
        price
      );
      await tx.wait();
      
      setSuccess(`${orderType === 0 ? 'Buy' : 'Sell'} order placed successfully!`);
      setEnergyAmount('');
      setPricePerUnit('');
    } catch (err) {
      console.error("Error placing order:", err);
      setError(err.message || 'Failed to place order. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!account) {
    return (
      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h6">Place Energy Order</Typography>
        <Alert severity="info">Please connect your wallet to place orders</Alert>
      </Paper>
    );
  }

  return (
    <Paper sx={{ p: 3, mb: 3 }}>
      <Typography variant="h6" gutterBottom>
        Place Energy Order
      </Typography>

      <Box component="form" onSubmit={handleSubmit} noValidate sx={{ mt: 1 }}>
        <FormControl fullWidth margin="normal">
          <InputLabel>Order Type</InputLabel>
          <Select
            value={orderType}
            label="Order Type"
            onChange={(e) => setOrderType(e.target.value)}
            disabled={isSubmitting}
          >
            <MenuItem value={0}>Buy Energy</MenuItem>
            <MenuItem value={1}>Sell Energy</MenuItem>
          </Select>
        </FormControl>
        
        <TextField
          margin="normal"
          required
          fullWidth
          label="Energy Amount"
          type="number"
          value={energyAmount}
          onChange={(e) => setEnergyAmount(e.target.value)}
          disabled={isSubmitting}
          InputProps={{
            endAdornment: <InputAdornment position="end">kWh</InputAdornment>,
          }}
        />
        
        <TextField
          margin="normal"
          required
          fullWidth
          label="Price per kWh"
          type="number"
          value={pricePerUnit}
          onChange={(e) => setPricePerUnit(e.target.value)}
          disabled={isSubmitting}
          InputProps={{
            endAdornment: <InputAdornment position="end">tokens</InputAdornment>,
          }}
        />
        
        {error && <Alert severity="error" sx={{ mt: 2 }}>{error}</Alert>}
        {success && <Alert severity="success" sx={{ mt: 2 }}>{success}</Alert>}
        
        <Button
          type="submit"
          fullWidth
          variant="contained"
          sx={{ mt: 3, mb: 2 }}
          disabled={isSubmitting}
        >
          {isSubmitting ? <CircularProgress size={24} /> : 'Place Order'}
        </Button>
      </Box>
    </Paper>
  );
};

export default EnergyOrderForm;
```

### 4. Order Book Component

```jsx
// src/components/energy/OrderBook.jsx
import React, { useState, useEffect } from 'react';
import { 
  Box, 
  Typography, 
  Paper, 
  Table, 
  TableBody, 
  TableCell, 
  TableContainer, 
  TableHead, 
  TableRow,
  Button,
  Chip
} from '@mui/material';
import { useWeb3 } from '../../contexts/Web3Context';
import { 
  formatEnergyAmount, 
  formatTokenAmount, 
  formatOrderType,
  truncateAddress
} from '../../utils/contractHelpers';

const OrderBook = () => {
  const { contracts, account } = useWeb3();
  const [buyOrders, setBuyOrders] = useState([]);
  const [sellOrders, setSellOrders] = useState([]);
  const [loading, setLoading] = useState(false);

  // Load orders when contract is available
  useEffect(() => {
    if (contracts.energyManagement) {
      loadOrders();
    }
  }, [contracts.energyManagement]);

  const loadOrders = async () => {
    setLoading(true);
    try {
      // Get open buy orders
      const buyOrderIds = await contracts.energyManagement.getOpenBuyOrders();
      const buyOrderPromises = buyOrderIds.map(async (id) => {
        const order = await contracts.energyManagement.orders(id);
        return { ...order, id };
      });
      const loadedBuyOrders = await Promise.all(buyOrderPromises);
      setBuyOrders(loadedBuyOrders);
      
      // Get open sell orders
      const sellOrderIds = await contracts.energyManagement.getOpenSellOrders();
      const sellOrderPromises = sellOrderIds.map(async (id) => {
        const order = await contracts.energyManagement.orders(id);
        return { ...order, id };
      });
      const loadedSellOrders = await Promise.all(sellOrderPromises);
      setSellOrders(loadedSellOrders);
    } catch (err) {
      console.error("Error loading orders:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleCancelOrder = async (orderId) => {
    try {
      const tx = await contracts.energyManagement.cancelOrder(orderId);
      await tx.wait();
      // Reload orders after cancellation
      await loadOrders();
    } catch (err) {
      console.error("Error cancelling order:", err);
    }
  };

  return (
    <Paper sx={{ p: 3 }}>
      <Typography variant="h6" gutterBottom>
        Energy Order Book
      </Typography>
      <Box sx={{ mb: 2 }}>
        <Button variant="outlined" onClick={loadOrders} disabled={loading}>
          {loading ? 'Loading...' : 'Refresh Orders'}
        </Button>
      </Box>
      
      <Typography variant="subtitle1" gutterBottom>
        Buy Orders
      </Typography>
      <TableContainer component={Paper} sx={{ mb: 4 }}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Order ID</TableCell>
              <TableCell>Energy (kWh)</TableCell>
              <TableCell>Price (per kWh)</TableCell>
              <TableCell>Total Cost</TableCell>
              <TableCell>Trader</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {buyOrders.length > 0 ? (
              buyOrders.map((order) => (
                <TableRow key={order.id.toString()}>
                  <TableCell>{order.id.toString()}</TableCell>
                  <TableCell>{formatEnergyAmount(order.energyAmount)}</TableCell>
                  <TableCell>{formatTokenAmount(order.pricePerUnit)}</TableCell>
                  <TableCell>
                    {formatTokenAmount(
                      order.energyAmount.mul(order.pricePerUnit).div(1000)
                    )}
                  </TableCell>
                  <TableCell>{truncateAddress(order.trader)}</TableCell>
                  <TableCell>
                    {order.trader === account && (
                      <Button
                        size="small"
                        variant="outlined"
                        color="secondary"
                        onClick={() => handleCancelOrder(order.id)}
                      >
                        Cancel
                      </Button>
                    )}
                  </TableCell>
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={6} align="center">
                  No buy orders available
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>
      
      <Typography variant="subtitle1" gutterBottom>
        Sell Orders
      </Typography>
      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Order ID</TableCell>
              <TableCell>Energy (kWh)</TableCell>
              <TableCell>Price (per kWh)</TableCell>
              <TableCell>Total Value</TableCell>
              <TableCell>Trader</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {sellOrders.length > 0 ? (
              sellOrders.map((order) => (
                <TableRow key={order.id.toString()}>
                  <TableCell>{order.id.toString()}</TableCell>
                  <TableCell>{formatEnergyAmount(order.energyAmount)}</TableCell>
                  <TableCell>{formatTokenAmount(order.pricePerUnit)}</TableCell>
                  <TableCell>
                    {formatTokenAmount(
                      order.energyAmount.mul(order.pricePerUnit).div(1000)
                    )}
                  </TableCell>
                  <TableCell>{truncateAddress(order.trader)}</TableCell>
                  <TableCell>
                    {order.trader === account && (
                      <Button
                        size="small"
                        variant="outlined"
                        color="secondary"
                        onClick={() => handleCancelOrder(order.id)}
                      >
                        Cancel
                      </Button>
                    )}
                  </TableCell>
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={6} align="center">
                  No sell orders available
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </Paper>
  );
};

export default OrderBook;
```

## Sample Transactions

Here are examples of how to implement common transactions in your application:

### 1. Register a New User

```javascript
// Register a new user
async function registerUser(name, solarProof) {
  try {
    // Get membership fee
    const membershipFee = await contracts.membership.membershipFee();
    
    // Approve tokens for membership fee
    const approveTx = await contracts.token.approve(
      contracts.membership.address, 
      membershipFee
    );
    await approveTx.wait();
    
    // Register member
    const registerTx = await contracts.membership.registerMember(name, solarProof);
    const receipt = await registerTx.wait();
    
    return receipt;
  } catch (error) {
    console.error("Error registering user:", error);
    throw error;
  }
}
```

### 2. Place a Buy Order

```javascript
// Place a buy order for energy
async function placeBuyOrder(energyAmount, pricePerUnit) {
  try {
    // Convert inputs to contract format
    const energy = parseEnergyAmount(energyAmount); // kWh * 1000
    const price = parseTokenAmount(pricePerUnit);
    
    // Calculate total cost
    const totalCost = energy * price / 1000;
    
    // Approve tokens for the buy order
    const approveTx = await contracts.token.approve(
      contracts.energyManagement.address, 
      totalCost
    );
    await approveTx.wait();
    
    // Place buy order (0 = Buy)
    const orderTx = await contracts.energyManagement.placeOrder(0, energy, price);
    const receipt = await orderTx.wait();
    
    return receipt;
  } catch (error) {
    console.error("Error placing buy order:", error);
    throw error;
  }
}
```

### 3. Place a Sell Order

```javascript
// Place a sell order for energy
async function placeSellOrder(energyAmount, pricePerUnit) {
  try {
    // Convert inputs to contract format
    const energy = parseEnergyAmount(energyAmount); // kWh * 1000
    const price = parseTokenAmount(pricePerUnit);
    
    // Place sell order (1 = Sell)
    const orderTx = await contracts.energyManagement.placeOrder(1, energy, price);
    const receipt = await orderTx.wait();
    
    return receipt;
  } catch (error) {
    console.error("Error placing sell order:", error);
    throw error;
  }
}
```

### 4. Create a Governance Proposal

```javascript
// Create a governance proposal
async function createProposal(title, description, targetContract, functionData) {
  try {
    // Create proposal transaction
    const proposalTx = await contracts.governance.createProposal(
      title,
      description,
      targetContract,
      functionData
    );
    const receipt = await proposalTx.wait();
    
    return receipt;
  } catch (error) {
    console.error("Error creating proposal:", error);
    throw error;
  }
}

// Example: Create proposal to update fee percentage
async function createFeeUpdateProposal(newFeePercentage) {
  // Get the function signature and encode the parameters
  const functionInterface = new ethers.utils.Interface([
    "function updateFeePercentage(uint256 _newFeePercentage)"
  ]);
  
  const callData = functionInterface.encodeFunctionData(
    "updateFeePercentage", 
    [newFeePercentage]
  );
  
  return createProposal(
    "Update Trading Fee",
    `Change the trading fee to ${newFeePercentage/100}%`,
    contracts.energyManagement.address,
    callData
  );
}
```

### 5. Vote on a Proposal

```javascript
// Vote on a governance proposal
async function voteOnProposal(proposalId, voteType) {
  try {
    // Vote types: 1 = Yes, 2 = No, 3 = Abstain
    const voteTx = await contracts.governance.vote(proposalId, voteType);
    const receipt = await voteTx.wait();
    
    return receipt;
  } catch (error) {
    console.error("Error voting on proposal:", error);
    throw error;
  }
}
```

## Testing Your Frontend

1. **Local Testing Setup**

   ```bash
   # Start local blockchain
   npx hardhat node
   
   # Deploy contracts to local blockchain
   npx hardhat run scripts/deploy.js --network localhost
   
   # Start React app
   npm start
   ```

2. **Testing with MetaMask**

   - Add the local network to MetaMask (Network URL: http://localhost:8545, Chain ID: 1337)
   - Import a private key from the local hardhat node to MetaMask
   - Connect your application to MetaMask
   - Ensure you've updated the contract addresses in your Web3Context.jsx file

3. **User Journey Testing**

   Test all core user journeys to ensure functionality:
   
   - Member registration and approval
   - Placing energy buy and sell orders
   - Order matching and settlement
   - Creating and voting on governance proposals
   - Treasury withdrawals (for approved signers)
   - Rewards distribution to energy contributors

## Additional Components

### 1. Governance Proposal Components

```jsx
// src/components/governance/ProposalForm.jsx
import React, { useState } from 'react';
import { 
  TextField, 
  Button, 
  Box, 
  Typography, 
  Paper, 
  Alert, 
  CircularProgress 
} from '@mui/material';
import { ethers } from 'ethers';
import { useWeb3 } from '../../contexts/Web3Context';

const ProposalForm = () => {
  const { contracts, account } = useWeb3();
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [targetContract, setTargetContract] = useState('');
  const [functionSignature, setFunctionSignature] = useState('');
  const [functionParams, setFunctionParams] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!title || !description || !targetContract || !functionSignature) {
      setError('Please fill in all required fields');
      return;
    }

    setIsSubmitting(true);
    setError('');
    setSuccess('');

    try {
      // Encode function call data
      const functionInterface = new ethers.utils.Interface([functionSignature]);
      const functionName = functionSignature.split('(')[0];
      
      // Parse params - this is simplified, in a real app you'd need to parse properly
      const params = functionParams.split(',').map(param => param.trim());
      
      const callData = functionInterface.encodeFunctionData(functionName, params);
      
      // Create proposal
      const tx = await contracts.governance.createProposal(
        title,
        description,
        targetContract,
        callData
      );
      await tx.wait();
      
      setSuccess('Proposal created successfully!');
      setTitle('');
      setDescription('');
      setTargetContract('');
      setFunctionSignature('');
      setFunctionParams('');
    } catch (err) {
      console.error("Error creating proposal:", err);
      setError(err.message || 'Failed to create proposal. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!account) {
    return (
      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h6">Create Governance Proposal</Typography>
        <Alert severity="info">Please connect your wallet to create proposals</Alert>
      </Paper>
    );
  }

  return (
    <Paper sx={{ p: 3, mb: 3 }}>
      <Typography variant="h6" gutterBottom>
        Create Governance Proposal
      </Typography>

      <Box component="form" onSubmit={handleSubmit} noValidate sx={{ mt: 1 }}>
        <TextField
          margin="normal"
          required
          fullWidth
          label="Proposal Title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          disabled={isSubmitting}
        />
        
        <TextField
          margin="normal"
          required
          fullWidth
          label="Description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          multiline
          rows={4}
          disabled={isSubmitting}
        />
        
        <TextField
          margin="normal"
          required
          fullWidth
          label="Target Contract Address"
          value={targetContract}
          onChange={(e) => setTargetContract(e.target.value)}
          disabled={isSubmitting}
        />
        
        <TextField
          margin="normal"
          required
          fullWidth
          label="Function Signature (e.g., 'updateFeePercentage(uint256)')"
          value={functionSignature}
          onChange={(e) => setFunctionSignature(e.target.value)}
          disabled={isSubmitting}
          placeholder="function(type1,type2,...)"
        />
        
        <TextField
          margin="normal"
          fullWidth
          label="Function Parameters (comma separated)"
          value={functionParams}
          onChange={(e) => setFunctionParams(e.target.value)}
          disabled={isSubmitting}
          placeholder="param1,param2,..."
        />
        
        {error && <Alert severity="error" sx={{ mt: 2 }}>{error}</Alert>}
        {success && <Alert severity="success" sx={{ mt: 2 }}>{success}</Alert>}
        
        <Button
          type="submit"
          fullWidth
          variant="contained"
          sx={{ mt: 3, mb: 2 }}
          disabled={isSubmitting}
        >
          {isSubmitting ? <CircularProgress size={24} /> : 'Create Proposal'}
        </Button>
      </Box>
    </Paper>
  );
};

export default ProposalForm;
```

```jsx
// src/components/governance/ProposalList.jsx
import React, { useState, useEffect } from 'react';
import { 
  Box, 
  Typography, 
  Paper, 
  Table, 
  TableBody, 
  TableCell, 
  TableContainer, 
  TableHead, 
  TableRow,
  Button,
  Chip,
  Divider,
  CircularProgress
} from '@mui/material';
import { useWeb3 } from '../../contexts/Web3Context';
import { formatProposalStatus, formatDate, truncateAddress } from '../../utils/contractHelpers';

const ProposalList = () => {
  const { contracts, account } = useWeb3();
  const [proposals, setProposals] = useState([]);
  const [loading, setLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);

  // Load proposals when contract is available
  useEffect(() => {
    if (contracts.governance) {
      loadProposals();
    }
  }, [contracts.governance]);

  const loadProposals = async () => {
    setLoading(true);
    try {
      const proposalIds = await contracts.governance.getAllProposalIds();
      
      const proposalPromises = proposalIds.map(async (id) => {
        const proposal = await contracts.governance.getProposalDetails(id);
        return { ...proposal, id };
      });
      
      const loadedProposals = await Promise.all(proposalPromises);
      setProposals(loadedProposals);
    } catch (err) {
      console.error("Error loading proposals:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleVote = async (proposalId, voteType) => {
    setActionLoading(true);
    try {
      const tx = await contracts.governance.vote(proposalId, voteType);
      await tx.wait();
      await loadProposals(); // Reload after voting
    } catch (err) {
      console.error("Error voting:", err);
    } finally {
      setActionLoading(false);
    }
  };

  const handleExecute = async (proposalId) => {
    setActionLoading(true);
    try {
      const tx = await contracts.governance.executeProposal(proposalId);
      await tx.wait();
      await loadProposals(); // Reload after execution
    } catch (err) {
      console.error("Error executing proposal:", err);
    } finally {
      setActionLoading(false);
    }
  };

  const statusChipColor = (status) => {
    const statusMap = {
      0: 'primary', // Active
      1: 'success', // Passed
      2: 'error',   // Rejected
      3: 'default', // Executed
      4: 'warning'  // Canceled
    };
    return statusMap[status] || 'default';
  };

  return (
    <Paper sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
        <Typography variant="h6">
          Governance Proposals
        </Typography>
        <Button variant="outlined" onClick={loadProposals} disabled={loading}>
          {loading ? <CircularProgress size={24} /> : 'Refresh'}
        </Button>
      </Box>
      
      {actionLoading && (
        <Box sx={{ display: 'flex', justifyContent: 'center', my: 2 }}>
          <CircularProgress />
        </Box>
      )}
      
      {proposals.length > 0 ? (
        proposals.map((proposal) => (
          <Paper key={proposal.id.toString()} sx={{ mb: 3, p: 2 }}>
            <Typography variant="h6">
              {proposal.title}
              <Chip 
                label={formatProposalStatus(proposal.status)} 
                color={statusChipColor(proposal.status)}
                size="small"
                sx={{ ml: 2 }}
              />
            </Typography>
            
            <Typography variant="body2" color="textSecondary" gutterBottom>
              Proposed by: {truncateAddress(proposal.proposer)} on {formatDate(proposal.startTime)}
            </Typography>
            
            <Typography variant="body1" sx={{ my: 2 }}>
              {proposal.description}
            </Typography>
            
            <Divider sx={{ my: 2 }} />
            
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Box>
                <Typography variant="body2">
                  Yes: {proposal.yesVotes.toString()} | No: {proposal.noVotes.toString()} | Abstain: {proposal.abstainVotes.toString()}
                </Typography>
                <Typography variant="caption">
                  Voting ends: {formatDate(proposal.endTime)}
                </Typography>
              </Box>
              
              <Box>
                {proposal.status === 0 && ( // Active proposals can be voted on
                  <Box>
                    <Button 
                      variant="outlined" 
                      color="success" 
                      size="small" 
                      onClick={() => handleVote(proposal.id, 1)}
                      sx={{ mr: 1 }}
                      disabled={actionLoading}
                    >
                      Yes
                    </Button>
                    <Button 
                      variant="outlined" 
                      color="error" 
                      size="small" 
                      onClick={() => handleVote(proposal.id, 2)}
                      sx={{ mr: 1 }}
                      disabled={actionLoading}
                    >
                      No
                    </Button>
                    <Button 
                      variant="outlined" 
                      color="inherit" 
                      size="small" 
                      onClick={() => handleVote(proposal.id, 3)}
                      disabled={actionLoading}
                    >
                      Abstain
                    </Button>
                  </Box>
                )}
                
                {proposal.status === 1 && ( // Passed proposals can be executed
                  <Button 
                    variant="contained" 
                    color="primary" 
                    size="small" 
                    onClick={() => handleExecute(proposal.id)}
                    disabled={actionLoading}
                  >
                    Execute
                  </Button>
                )}
              </Box>
            </Box>
          </Paper>
        ))
      ) : (
        <Typography variant="body1" sx={{ textAlign: 'center', py: 4 }}>
          {loading ? 'Loading proposals...' : 'No proposals found'}
        </Typography>
      )}
    </Paper>
  );
};

export default ProposalList;
```

### 2. Treasury Management Components

```jsx
// src/components/treasury/WithdrawalForm.jsx
import React, { useState, useEffect } from 'react';
import { 
  TextField, 
  Button, 
  Box, 
  Typography, 
  Paper, 
  Alert, 
  CircularProgress,
  InputAdornment
} from '@mui/material';
import { ethers } from 'ethers';
import { useWeb3 } from '../../contexts/Web3Context';
import { isValidAddress, parseTokenAmount } from '../../utils/contractHelpers';

const WithdrawalForm = () => {
  const { contracts, account } = useWeb3();
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [isApprovedSigner, setIsApprovedSigner] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [treasuryBalance, setTreasuryBalance] = useState('0');

  // Check if the user is an approved signer and get treasury balance
  useEffect(() => {
    if (contracts.treasury && account) {
      checkSignerStatus();
      getTreasuryBalance();
    }
  }, [contracts.treasury, account]);

  const checkSignerStatus = async () => {
    try {
      // Get all signers
      const signers = await contracts.treasury.getAllSigners();
      setIsApprovedSigner(signers.includes(account));
    } catch (err) {
      console.error("Error checking signer status:", err);
    }
  };

  const getTreasuryBalance = async () => {
    try {
      const balance = await contracts.treasury.getTreasuryBalance();
      setTreasuryBalance(ethers.utils.formatEther(balance));
    } catch (err) {
      console.error("Error getting treasury balance:", err);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!recipient || !amount || !description) {
      setError('Please fill in all fields');
      return;
    }

    if (!isValidAddress(recipient)) {
      setError('Invalid recipient address');
      return;
    }

    setIsSubmitting(true);
    setError('');
    setSuccess('');

    try {
      // Format amount to wei
      const amountWei = parseTokenAmount(amount);
      
      // Create withdrawal proposal
      const tx = await contracts.treasury.proposeWithdrawal(
        recipient,
        amountWei,
        description
      );
      await tx.wait();
      
      setSuccess('Withdrawal proposal created successfully!');
      setRecipient('');
      setAmount('');
      setDescription('');
      
      // Update treasury balance
      await getTreasuryBalance();
    } catch (err) {
      console.error("Error creating withdrawal proposal:", err);
      setError(err.message || 'Failed to create withdrawal proposal. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!account) {
    return (
      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h6">Treasury Withdrawal</Typography>
        <Alert severity="info">Please connect your wallet to propose withdrawals</Alert>
      </Paper>
    );
  }

  if (!isApprovedSigner) {
    return (
      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h6">Treasury Withdrawal</Typography>
        <Alert severity="warning">
          You are not an approved signer for treasury withdrawals
        </Alert>
      </Paper>
    );
  }

  return (
    <Paper sx={{ p: 3, mb: 3 }}>
      <Typography variant="h6" gutterBottom>
        Propose Treasury Withdrawal
      </Typography>
      
      <Typography variant="body2" color="textSecondary" gutterBottom>
        Current Treasury Balance: {treasuryBalance} tokens
      </Typography>

      <Box component="form" onSubmit={handleSubmit} noValidate sx={{ mt: 1 }}>
        <TextField
          margin="normal"
          required
          fullWidth
          label="Recipient Address"
          value={recipient}
          onChange={(e) => setRecipient(e.target.value)}
          disabled={isSubmitting}
        />
        
        <TextField
          margin="normal"
          required
          fullWidth
          label="Amount"
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          disabled={isSubmitting}
          InputProps={{
            endAdornment: <InputAdornment position="end">tokens</InputAdornment>,
          }}
        />
        
        <TextField
          margin="normal"
          required
          fullWidth
          label="Description/Purpose"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          multiline
          rows={2}
          disabled={isSubmitting}
        />
        
        {error && <Alert severity="error" sx={{ mt: 2 }}>{error}</Alert>}
        {success && <Alert severity="success" sx={{ mt: 2 }}>{success}</Alert>}
        
        <Button
          type="submit"
          fullWidth
          variant="contained"
          sx={{ mt: 3, mb: 2 }}
          disabled={isSubmitting}
        >
          {isSubmitting ? <CircularProgress size={24} /> : 'Propose Withdrawal'}
        </Button>
      </Box>
    </Paper>
  );
};

export default WithdrawalForm;
```

```jsx
// src/components/treasury/TreasuryStats.jsx
import React, { useState, useEffect } from 'react';
import { 
  Box, 
  Typography, 
  Paper, 
  Grid,
  Button,
  CircularProgress,
  Divider
} from '@mui/material';
import { ethers } from 'ethers';
import { useWeb3 } from '../../contexts/Web3Context';
import { formatDate } from '../../utils/contractHelpers';

const TreasuryStats = () => {
  const { contracts } = useWeb3();
  const [treasuryBalance, setTreasuryBalance] = useState('0');
  const [lastDistribution, setLastDistribution] = useState(0);
  const [nextDistribution, setNextDistribution] = useState(0);
  const [rewardsPercentage, setRewardsPercentage] = useState(0);
  const [distributionPeriod, setDistributionPeriod] = useState(0);
  const [isDistributionDue, setIsDistributionDue] = useState(false);
  const [loading, setLoading] = useState(false);
  const [distributing, setDistributing] = useState(false);

  useEffect(() => {
    if (contracts.treasury) {
      loadTreasuryStats();
    }
  }, [contracts.treasury]);

  const loadTreasuryStats = async () => {
    setLoading(true);
    try {
      // Get treasury balance
      const balance = await contracts.treasury.getTreasuryBalance();
      setTreasuryBalance(ethers.utils.formatEther(balance));
      
      // Get last distribution time
      const lastDistributionTime = await contracts.treasury.lastRewardsDistribution();
      setLastDistribution(lastDistributionTime.toNumber());
      
      // Get distribution period
      const period = await contracts.treasury.rewardsDistributionPeriod();
      setDistributionPeriod(period.toNumber());
      
      // Calculate next distribution time
      setNextDistribution(lastDistributionTime.toNumber() + period.toNumber());
      
      // Get rewards percentage
      const percentage = await contracts.treasury.rewardsPercentage();
      setRewardsPercentage(percentage.toNumber() / 100); // Convert basis points to percentage
      
      // Check if distribution is due
      const isDue = await contracts.treasury.isRewardsDistributionDue();
      setIsDistributionDue(isDue);
    } catch (err) {
      console.error("Error loading treasury stats:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleDistributeRewards = async () => {
    setDistributing(true);
    try {
      const tx = await contracts.treasury.distributeRewards();
      await tx.wait();
      
      // Reload stats after distribution
      await loadTreasuryStats();
    } catch (err) {
      console.error("Error distributing rewards:", err);
    } finally {
      setDistributing(false);
    }
  };

  return (
    <Paper sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
        <Typography variant="h6">
          Treasury Statistics
        </Typography>
        <Button variant="outlined" onClick={loadTreasuryStats} disabled={loading}>
          {loading ? <CircularProgress size={24} /> : 'Refresh'}
        </Button>
      </Box>
      
      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', my: 4 }}>
          <CircularProgress />
        </Box>
      ) : (
        <>
          <Grid container spacing={3} sx={{ mb: 3 }}>
            <Grid item xs={12} md={6}>
              <Paper sx={{ p: 2, height: '100%' }}>
                <Typography variant="subtitle1" gutterBottom>
                  Current Balance
                </Typography>
                <Typography variant="h4">
                  {treasuryBalance} tokens
                </Typography>
              </Paper>
            </Grid>
            <Grid item xs={12} md={6}>
              <Paper sx={{ p: 2, height: '100%' }}>
                <Typography variant="subtitle1" gutterBottom>
                  Rewards Percentage
                </Typography>
                <Typography variant="h4">
                  {rewardsPercentage}%
                </Typography>
                <Typography variant="body2" color="textSecondary">
                  of treasury distributed each period
                </Typography>
              </Paper>
            </Grid>
          </Grid>
          
          <Divider sx={{ my: 3 }} />
          
          <Typography variant="subtitle1" gutterBottom>
            Rewards Distribution
          </Typography>
          <Grid container spacing={3}>
            <Grid item xs={12} md={4}>
              <Typography variant="body2" color="textSecondary">
                Last Distribution:
              </Typography>
              <Typography variant="body1">
                {lastDistribution > 0 ? formatDate(lastDistribution) : 'Never'}
              </Typography>
            </Grid>
            <Grid item xs={12} md={4}>
              <Typography variant="body2" color="textSecondary">
                Next Distribution:
              </Typography>
              <Typography variant="body1">
                {nextDistribution > 0 ? formatDate(nextDistribution) : 'N/A'}
              </Typography>
            </Grid>
            <Grid item xs={12} md={4}>
              <Typography variant="body2" color="textSecondary">
                Distribution Period:
              </Typography>
              <Typography variant="body1">
                {distributionPeriod / (24 * 60 * 60)} days
              </Typography>
            </Grid>
          </Grid>
          
          {isDistributionDue && (
            <Box sx={{ mt: 3, textAlign: 'center' }}>
              <Button 
                variant="contained" 
                color="primary" 
                onClick={handleDistributeRewards}
                disabled={distributing}
              >
                {distributing ? <CircularProgress size={24} /> : 'Distribute Rewards Now'}
              </Button>
              <Typography variant="caption" display="block" sx={{ mt: 1 }}>
                Rewards distribution is due and can be triggered by any member
              </Typography>
            </Box>
          )}
        </>
      )}
    </Paper>
  );
};

export default TreasuryStats;
```

### 3. Main Application Component

```jsx
// src/App.jsx
import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { CssBaseline, Box, Container, Typography } from '@mui/material';
import { Web3Provider } from './contexts/Web3Context';

// Layout components
import Header from './components/common/Header';
import Footer from './components/common/Footer';

// Membership components
import RegisterForm from './components/membership/RegisterForm';
import MemberList from './components/membership/MemberList';

// Energy components
import EnergyOrderForm from './components/energy/EnergyOrderForm';
import OrderBook from './components/energy/OrderBook';

// Governance components
import ProposalForm from './components/governance/ProposalForm';
import ProposalList from './components/governance/ProposalList';

// Treasury components
import WithdrawalForm from './components/treasury/WithdrawalForm';
import TreasuryStats from './components/treasury/TreasuryStats';

function App() {
  return (
    <Web3Provider>
      <Router>
        <CssBaseline />
        <Box sx={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
          <Header />
          
          <Container component="main" sx={{ flexGrow: 1, py: 4 }}>
            <Routes>
              {/* Home page */}
              <Route path="/" element={
                <Box>
                  <Typography variant="h4" gutterBottom>
                    Energy Community DAO
                  </Typography>
                  <Typography variant="body1" paragraph>
                    Welcome to the decentralized energy trading platform. Connect your wallet to get started.
                  </Typography>
                  
                  <RegisterForm />
                  <EnergyOrderForm />
                  <OrderBook />
                </Box>
              } />
              
              {/* Membership section */}
              <Route path="/membership" element={
                <Box>
                  <Typography variant="h4" gutterBottom>
                    Membership Management
                  </Typography>
                  <RegisterForm />
                  <MemberList />
                </Box>
              } />
              
              {/* Energy trading section */}
              <Route path="/trading" element={
                <Box>
                  <Typography variant="h4" gutterBottom>
                    Energy Trading
                  </Typography>
                  <EnergyOrderForm />
                  <OrderBook />
                </Box>
              } />
              
              {/* Governance section */}
              <Route path="/governance" element={
                <Box>
                  <Typography variant="h4" gutterBottom>
                    Community Governance
                  </Typography>
                  <ProposalForm />
                  <ProposalList />
                </Box>
              } />
              
              {/* Treasury section */}
              <Route path="/treasury" element={
                <Box>
                  <Typography variant="h4" gutterBottom>
                    Treasury Management
                  </Typography>
                  <WithdrawalForm />
                  <TreasuryStats />
                </Box>
              } />
            </Routes>
          </Container>
          
          <Footer />
        </Box>
      </Router>
    </Web3Provider>
  );
}

export default App;
```

## Conclusion

This guide provides a comprehensive overview of how to build a React frontend application for the Energy Community DAO smart contracts. By following these instructions, you can create a fully functional user interface that enables community members to:

1. Register and manage their membership
2. Place and manage energy buy/sell orders
3. Create and vote on governance proposals
4. Manage treasury withdrawals and reward distributions

The components provided are modular and can be extended or customized based on your specific requirements. As you develop your application, consider adding additional features such as:

- Data visualization for energy trading metrics
- Notifications for matched orders and executed proposals
- Mobile-responsive design for better accessibility
- Integration with IPFS for storing solar installation documentation

Remember to thoroughly test your application in both development and production environments before deploying to end users.