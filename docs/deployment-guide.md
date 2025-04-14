# Energy Community DAO - Deployment and Setup Guide

This guide provides instructions for setting up, deploying, and interacting with the Energy Community DAO smart contracts. It includes both local development environment setup and deployment to a private Proof of Authority (PoA) chain.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Local Development Setup](#local-development-setup)
3. [Testing the Contracts](#testing-the-contracts)
4. [Deployment to a Private PoA Chain](#deployment-to-a-private-poa-chain)
5. [Contract Verification](#contract-verification)
6. [Contract Upgradeability](#contract-upgradeability)
7. [Best Practices](#best-practices)
8. [Frontend Integration](#frontend-integration)

## Prerequisites

- Node.js (v14+)
- npm or yarn
- Git
- MetaMask or similar Ethereum wallet
- Basic knowledge of Ethereum and smart contracts

## Local Development Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/energy-community-dao.git
   cd energy-community-dao
   ```

2. **Install dependencies**

   ```bash
   npm install
   # or
   yarn install
   ```

3. **Create configuration files**

   Create a `hardhat.config.js` file:

   ```javascript
   require("@nomiclabs/hardhat-waffle");
   require("@nomiclabs/hardhat-ethers");
   require("@openzeppelin/hardhat-upgrades");
   require("dotenv").config();

   const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000000";

   module.exports = {
     solidity: {
       version: "0.8.17",
       settings: {
         optimizer: {
           enabled: true,
           runs: 200
         }
       }
     },
     networks: {
       hardhat: {
         chainId: 1337,
         allowUnlimitedContractSize: true
       },
       localhost: {
         url: "http://127.0.0.1:8545",
         chainId: 1337
       },
       privatepoa: {
         url: process.env.POA_RPC_URL || "http://localhost:8545",
         accounts: [PRIVATE_KEY],
         chainId: process.env.POA_CHAIN_ID ? parseInt(process.env.POA_CHAIN_ID) : 1337
       }
     },
     paths: {
       artifacts: "./artifacts",
       cache: "./cache",
       sources: "./contracts",
       tests: "./test"
     }
   };
   ```

4. **Set up environment variables**

   Create a `.env` file:

   ```
   PRIVATE_KEY=your-private-key-here
   POA_RPC_URL=your-poa-chain-rpc-url
   POA_CHAIN_ID=your-poa-chain-id
   ```

5. **Start a local blockchain**

   ```bash
   npx hardhat node
   ```

## Testing the Contracts

1. **Run the tests**

   ```bash
   npx hardhat test
   ```

2. **Run specific tests**

   ```bash
   npx hardhat test test/energy-community-integration.js
   ```

3. **Get test coverage**

   First, add the coverage plugin:

   ```bash
   npm install --save-dev solidity-coverage
   ```

   Add to hardhat.config.js:

   ```javascript
   require("solidity-coverage");
   ```

   Run coverage:

   ```bash
   npx hardhat coverage
   ```

## Deployment to a Private PoA Chain

1. **Set up a private PoA blockchain (if not already available)**

   You can use tools like Hyperledger Besu, GoQuorum, or Polygon Edge:

   For Besu (example setup):
   ```bash
   # Create a genesis file with PoA consensus
   besu operator generate-blockchain-config --config-file=config.json --to=networkFiles --private-key-file-name=key

   # Start the first node
   besu --data-path=data --genesis-file=networkFiles/genesis.json --rpc-http-enabled --rpc-http-api=ETH,NET,WEB3,ADMIN
   ```

2. **Deploy the contracts**

   Use the deployment script we've created:

   ```bash
   # Deploy to local development network
   npx hardhat run scripts/deploy.js --network localhost

   # Or deploy to the private PoA network
   npx hardhat run scripts/deploy.js --network privatepoa
   ```

3. **Record the contract addresses**

   After deployment, the script will output the addresses of all deployed contracts. Save these addresses for future reference:

   ```bash
   echo "GOVERNANCE_TOKEN=0x..." > .contract-addresses
   echo "MEMBERSHIP_CONTRACT=0x..." >> .contract-addresses
   echo "TREASURY_CONTRACT=0x..." >> .contract-addresses
   echo "GOVERNANCE_CONTRACT=0x..." >> .contract-addresses
   echo "ENERGY_MANAGEMENT_CONTRACT=0x..." >> .contract-addresses
   ```

## Contract Verification

If your private PoA chain has a block explorer like BlockScout:

1. **Install the verification plugin**

   ```bash
   npm install --save-dev @nomiclabs/hardhat-etherscan
   ```

2. **Add to hardhat.config.js**

   ```javascript
   require("@nomiclabs/hardhat-etherscan");
   
   module.exports = {
     // existing config...
     etherscan: {
       apiKey: {
         privatepoa: "no-api-key-required" // For BlockScout or similar
       },
       customChains: [
         {
           network: "privatepoa",
           chainId: parseInt(process.env.POA_CHAIN_ID),
           urls: {
             apiURL: "https://your-blockscout-instance/api",
             browserURL: "https://your-blockscout-instance"
           }
         }
       ]
     }
   };
   ```

3. **Verify each contract**

   ```bash
   # Example for the Membership contract
   npx hardhat verify --network privatepoa <MEMBERSHIP_ADDRESS> <CONSTRUCTOR_ARGS>
   ```

## Contract Upgradeability

For future upgrades, consider implementing the following pattern:

1. **Use OpenZeppelin's upgradeable contracts**

   ```bash
   npm install @openzeppelin/contracts-upgradeable
   ```

2. **Convert contracts to use initializers instead of constructors**

   For example, modify the Membership contract:

   ```solidity
   // SPDX-License-Identifier: MIT
   pragma solidity ^0.8.17;

   import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
   import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
   import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

   contract EnergyCommunityMembershipUpgradeable is OwnableUpgradeable, ReentrancyGuardUpgradeable {
       // State variables remain the same
       
       // Replace constructor with initializer
       function initialize(
           address _initialOwner,
           uint256 _membershipFee,
           address _membershipToken
       ) public initializer {
           __Ownable_init(_initialOwner);
           __ReentrancyGuard_init();
           membershipFee = _membershipFee;
           membershipToken = IERC20(_membershipToken);
       }
       
       // Rest of the contract remains the same
   }
   ```

3. **Deploy using the proxy pattern**

   ```javascript
   const { ethers, upgrades } = require("hardhat");

   async function main() {
     // Deploy the upgradeable version
     const MembershipFactory = await ethers.getContractFactory("EnergyCommunityMembershipUpgradeable");
     const membership = await upgrades.deployProxy(MembershipFactory, [
       deployer.address,
       ethers.utils.parseEther("100"),
       governanceToken.address
     ]);
     await membership.deployed();
     console.log("Upgradeable Membership deployed to:", membership.address);
   }
   ```

## Best Practices

1. **Security Considerations**

   - **Re-entrancy Protection**: All our contracts use ReentrancyGuard to prevent re-entrancy attacks
   - **Access Control**: Use of Ownable pattern and role-based permissions
   - **Integer Overflow/Underflow**: Solidity 0.8.x includes built-in overflow checks
   - **Checks-Effects-Interactions Pattern**: Implement this pattern to prevent re-entrancy
   - **Input Validation**: All functions validate inputs before processing

2. **Gas Optimization**

   - Use efficient data structures (e.g., mappings instead of arrays for lookups)
   - Minimize storage operations by using memory variables when possible
   - Batch operations to save gas
   - Use events for off-chain tracking rather than storing excessive data on-chain

3. **Regular Security Audits**

   Before deploying to production:
   - Use automated tools like Mythril, Slither, or MythX
   - Consider a professional audit by a security firm
   - Perform thorough testing on testnets
   - Consider implementing formal verification for critical functions

## Frontend Integration

A basic approach to integrate with a React frontend:

1. **Set up a React project**

   ```bash
   npx create-react-app energy-dao-frontend
   cd energy-dao-frontend
   npm install ethers
   ```

2. **Create utility functions for contract interaction**

   Create a file `src/utils/contracts.js`:

   ```javascript
   import { ethers } from 'ethers';
   import MembershipABI from '../abis/EnergyCommunityMembership.json';
   import EnergyManagementABI from '../abis/EnergyManagement.json';
   import GovernanceABI from '../abis/EnergyCommunityGovernance.json';
   import TreasuryABI from '../abis/EnergyCommunityTreasury.json';
   import TokenABI from '../abis/ERC20.json';

   const CONTRACT_ADDRESSES = {
     membership: '0x...',
     energyManagement: '0x...',
     governance: '0x...',
     treasury: '0x...',
     token: '0x...'
   };

   export async function connectWallet() {
     if (window.ethereum) {
       try {
         const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
         const provider = new ethers.providers.Web3Provider(window.ethereum);
         const signer = provider.getSigner();
         return { address: accounts[0], provider, signer };
       } catch (error) {
         console.error("User rejected connection request");
         return null;
       }
     } else {
       console.error("Ethereum wallet not found");
       return null;
     }
   }

   export function getContracts(signer) {
     return {
       membership: new ethers.Contract(CONTRACT_ADDRESSES.membership, MembershipABI, signer),
       energyManagement: new ethers.Contract(CONTRACT_ADDRESSES.energyManagement, EnergyManagementABI, signer),
       governance: new ethers.Contract(CONTRACT_ADDRESSES.governance, GovernanceABI, signer),
       treasury: new ethers.Contract(CONTRACT_ADDRESSES.treasury, TreasuryABI, signer),
       token: new ethers.Contract(CONTRACT_ADDRESSES.token, TokenABI, signer)
     };
   }
   ```

3. **Example component for member registration**

   ```jsx
   import React, { useState, useEffect } from 'react';
   import { connectWallet, getContracts } from '../utils/contracts';
   import { ethers } from 'ethers';

   function MemberRegistration() {
     const [account, setAccount] = useState(null);
     const [contracts, setContracts] = useState(null);
     const [name, setName] = useState('');
     const [solarProof, setSolarProof] = useState('');
     const [isLoading, setIsLoading] = useState(false);
     const [message, setMessage] = useState('');
     
     useEffect(() => {
       async function init() {
         const walletData = await connectWallet();
         if (walletData) {
           setAccount(walletData.address);
           setContracts(getContracts(walletData.signer));
         }
       }
       init();
     }, []);
     
     async function handleRegister(e) {
       e.preventDefault();
       if (!contracts || !name || !solarProof) return;
       
       try {
         setIsLoading(true);
         setMessage('');
         
         // Approve token transfer for membership fee
         const membershipFee = await contracts.membership.membershipFee();
         await contracts.token.approve(contracts.membership.address, membershipFee);
         
         // Register as member
         const tx = await contracts.membership.registerMember(name, solarProof);
         await tx.wait();
         
         setMessage('Registration successful! Waiting for admin approval.');
         setName('');
         setSolarProof('');
       } catch (error) {
         console.error(error);
         setMessage(`Error: ${error.message}`);
       } finally {
         setIsLoading(false);
       }
     }
     
     if (!account) return <p>Please connect your wallet to continue.</p>;
     
     return (
       <div>
         <h2>Register as Community Member</h2>
         <form onSubmit={handleRegister}>
           <div>
             <label>
               Name:
               <input 
                 type="text" 
                 value={name} 
                 onChange={(e) => setName(e.target.value)} 
                 required 
               />
             </label>
           </div>
           <div>
             <label>
               Solar Installation Proof (IPFS hash):
               <input 
                 type="text" 
                 value={solarProof} 
                 onChange={(e) => setSolarProof(e.target.value)} 
                 required 
                 placeholder="ipfs://..." 
               />
             </label>
           </div>
           <button type="submit" disabled={isLoading}>
             {isLoading ? 'Processing...' : 'Register'}
           </button>
         </form>
         {message && <p>{message}</p>}
       </div>
     );
   }

   export default MemberRegistration;
   ```

4. **Example component for placing energy orders**

   ```jsx
   import React, { useState, useEffect } from 'react';
   import { connectWallet, getContracts } from '../utils/contracts';
   import { ethers } from 'ethers';

   function EnergyTrading() {
     const [account, setAccount] = useState(null);
     const [contracts, setContracts] = useState(null);
     const [orderType, setOrderType] = useState(0); // 0 = Buy, 1 = Sell
     const [energyAmount, setEnergyAmount] = useState('');
     const [pricePerUnit, setPricePerUnit] = useState('');
     const [isLoading, setIsLoading] = useState(false);
     const [message, setMessage] = useState('');
     const [openOrders, setOpenOrders] = useState([]);
     
     useEffect(() => {
       async function init() {
         const walletData = await connectWallet();
         if (walletData) {
           setAccount(walletData.address);
           setContracts(getContracts(walletData.signer));
         }
       }
       init();
     }, []);
     
     useEffect(() => {
       if (contracts) {
         loadOpenOrders();
       }
     }, [contracts]);
     
     async function loadOpenOrders() {
       try {
         const buyOrderIds = await contracts.energyManagement.getOpenBuyOrders();
         const sellOrderIds = await contracts.energyManagement.getOpenSellOrders();
         
         const buyOrders = await Promise.all(
           buyOrderIds.map(async (id) => {
             const order = await contracts.energyManagement.orders(id);
             return { ...order, id };
           })
         );
         
         const sellOrders = await Promise.all(
           sellOrderIds.map(async (id) => {
             const order = await contracts.energyManagement.orders(id);
             return { ...order, id };
           })
         );
         
         setOpenOrders([...buyOrders, ...sellOrders]);
       } catch (error) {
         console.error('Error loading orders:', error);
       }
     }
     
     async function handlePlaceOrder(e) {
       e.preventDefault();
       if (!contracts || !energyAmount || !pricePerUnit) return;
       
       try {
         setIsLoading(true);
         setMessage('');
         
         // Convert inputs to the correct format
         const energyAmountFormatted = parseInt(parseFloat(energyAmount) * 1000); // Convert to kWh * 1000
         const pricePerUnitFormatted = ethers.utils.parseUnits(pricePerUnit, 'ether');
         
         // If buy order, approve tokens first
         if (orderType === 0) {
           const totalCost = (energyAmountFormatted * pricePerUnitFormatted) / 1000;
           await contracts.token.approve(contracts.energyManagement.address, totalCost);
         }
         
         // Place the order
         const tx = await contracts.energyManagement.placeOrder(
           orderType,
           energyAmountFormatted,
           pricePerUnitFormatted
         );
         await tx.wait();
         
         setMessage('Order placed successfully!');
         setEnergyAmount('');
         setPricePerUnit('');
         
         // Reload open orders
         await loadOpenOrders();
       } catch (error) {
         console.error(error);
         setMessage(`Error: ${error.message}`);
       } finally {
         setIsLoading(false);
       }
     }
     
     if (!account) return <p>Please connect your wallet to continue.</p>;
     
     return (
       <div>
         <h2>Energy Trading</h2>
         <form onSubmit={handlePlaceOrder}>
           <div>
             <label>
               Order Type:
               <select 
                 value={orderType} 
                 onChange={(e) => setOrderType(parseInt(e.target.value))}
               >
                 <option value={0}>Buy Energy</option>
                 <option value={1}>Sell Energy</option>
               </select>
             </label>
           </div>
           <div>
             <label>
               Energy Amount (kWh):
               <input 
                 type="number" 
                 value={energyAmount} 
                 onChange={(e) => setEnergyAmount(e.target.value)} 
                 min="0.001" 
                 step="0.001" 
                 required 
               />
             </label>
           </div>
           <div>
             <label>
               Price per kWh (tokens):
               <input 
                 type="number" 
                 value={pricePerUnit} 
                 onChange={(e) => setPricePerUnit(e.target.value)} 
                 min="0.00001" 
                 step="0.00001" 
                 required 
               />
             </label>
           </div>
           <button type="submit" disabled={isLoading}>
             {isLoading ? 'Processing...' : 'Place Order'}
           </button>
         </form>
         {message && <p>{message}</p>}
         
         <h3>Open Orders</h3>
         <table>
           <thead>
             <tr>
               <th>ID</th>
               <th>Type</th>
               <th>Energy (kWh)</th>
               <th>Price per kWh</th>
               <th>Total Price</th>
               <th>Trader</th>
             </tr>
           </thead>
           <tbody>
             {openOrders.map((order) => (
               <tr key={order.id.toString()}>
                 <td>{order.id.toString()}</td>
                 <td>{order.orderType === 0 ? 'Buy' : 'Sell'}</td>
                 <td>{(order.energyAmount / 1000).toFixed(3)}</td>
                 <td>{ethers.utils.formatEther(order.pricePerUnit)}</td>
                 <td>
                   {ethers.utils.formatEther(
                     order.energyAmount * order.pricePerUnit / 1000
                   )}
                 </td>
                 <td>{order.trader}</td>
               </tr>
             ))}
           </tbody>
         </table>
       </div>
     );
   }

   export default EnergyTrading;
   ```

This guide provides a comprehensive overview of setting up, deploying, and interacting with the Energy Community DAO smart contracts. Follow these instructions to get your decentralized energy trading platform up and running.