# Lighthouse + FVM Integration for Lemo AI

Remix-ready smart contracts for decentralized receipt storage and automated feedback rewards using Lighthouse/IPFS and Filecoin FVM.

## 📋 Overview

This integration includes:
- **LighthouseReceipt.sol**: Stores purchase receipts with IPFS CIDs on-chain
- **TrustlessAgentFeedback.sol**: Manages feedback submission and automatic LEMO token rewards
- **AgentRegistry.sol**: EIP-8004 inspired agent identity and reputation registry
- **IERC20.sol**: Standard ERC20 interface for token interactions

## 🚀 Deployment Instructions (Remix)

### Step 1: Open Remix IDE
1. Navigate to [https://remix.ethereum.org](https://remix.ethereum.org)
2. Create a new workspace or use the default workspace

### Step 2: Upload Contract Files
1. In Remix's File Explorer, create the following structure:
   ```
   contracts/
   ├── LighthouseReceipt.sol
   ├── TrustlessAgentFeedback.sol
   ├── AgentRegistry.sol
   └── interfaces/
       └── IERC20.sol
   ```
2. Copy and paste each contract file from this repository

### Step 3: Compile Contracts
1. Go to the "Solidity Compiler" tab (left sidebar)
2. Select compiler version: **0.8.18** or higher
3. Enable optimization (200 runs recommended)
4. Click "Compile" for each contract

### Step 4: Configure Network

#### For Sepolia Testnet (LEMO Token Network):
- **Network Name**: Sepolia
- **RPC URL**: `https://rpc.sepolia.org`
- **Chain ID**: 11155111
- **Symbol**: ETH
- **Block Explorer**: https://sepolia.etherscan.io

#### For Filecoin Calibration Testnet:
- **Network Name**: Filecoin Calibration
- **RPC URL**: `https://api.calibration.node.glif.io/rpc/v1`
- **Chain ID**: 314159
- **Symbol**: tFIL
- **Block Explorer**: https://calibration.filfox.info

### Step 5: Deploy Contracts

#### Deploy Order:
1. **LighthouseReceipt.sol** (deploy to BOTH Sepolia and Calibration)
2. **AgentRegistry.sol** (deploy to Sepolia)
3. **TrustlessAgentFeedback.sol** (deploy to Sepolia)

#### Deployment Steps:

##### 1. Deploy LighthouseReceipt
- Go to "Deploy & Run Transactions" tab
- Select "Injected Provider - MetaMask"
- Switch MetaMask to Sepolia network
- Select contract: `LighthouseReceipt`
- Click "Deploy"
- **Save the deployed address** (you'll need it for the extension)
- Repeat for Filecoin Calibration network

##### 2. Deploy AgentRegistry
- Switch MetaMask to Sepolia
- Select contract: `AgentRegistry`
- Click "Deploy"
- **Save the deployed address**

##### 3. Deploy TrustlessAgentFeedback
- **IMPORTANT**: Before deploying, verify the LEMO token address in the contract:
  - Default: `0x14572da77700C59D2f8D61a3C4b25744D6dCde8D`
  - If different, edit line 22 in the contract before compiling
- Switch MetaMask to Sepolia
- Select contract: `TrustlessAgentFeedback`
- Click "Deploy"
- **Save the deployed address**

## 💰 Funding the Feedback Contract

The `TrustlessAgentFeedback` contract MUST be funded with LEMO tokens before users can submit feedback.

### Step 1: Approve LEMO Tokens
1. In Remix, load the LEMO token contract at: `0x14572dA77700c59D2F8D61a3c4B25744D6DcDE8D`
2. Use a standard ERC20 ABI or import IERC20.sol
3. Call `approve(feedbackContractAddress, amount)`
   - `feedbackContractAddress`: Your deployed TrustlessAgentFeedback address
   - `amount`: Total LEMO to allocate (e.g., `10000000000000000000000000` for 10M LEMO)

### Step 2: Fund the Contract
1. In the deployed `TrustlessAgentFeedback` contract
2. Call `fundContract(amount)`
   - `amount`: Same as approved amount
3. Verify funding: call `getLEMOBalance()` to check contract balance

### Reward Calculation:
- Each feedback submission rewards: **1,000,000 LEMO** (1e24 wei)
- To support 100 feedbacks: fund with 100,000,000 LEMO tokens

## 🔧 Configuration for Extension

After deployment, update the following in your Lemo extension:

### Create `Lighthouse-Integration/deployment-config.json`:
```json
{
  "networks": {
    "sepolia": {
      "chainId": 11155111,
      "rpcUrl": "https://rpc.sepolia.org",
      "contracts": {
        "LighthouseReceipt": "0x_YOUR_DEPLOYED_ADDRESS_HERE",
        "TrustlessAgentFeedback": "0x_YOUR_DEPLOYED_ADDRESS_HERE",
        "AgentRegistry": "0x_YOUR_DEPLOYED_ADDRESS_HERE",
        "LEMOToken": "0x14572da77700C59D2f8D61a3C4b25744D6dCde8D"
      }
    },
    "calibration": {
      "chainId": 314159,
      "rpcUrl": "https://api.calibration.node.glif.io/rpc/v1",
      "contracts": {
        "LighthouseReceipt": "0x_YOUR_DEPLOYED_ADDRESS_HERE"
      }
    }
  },
  "lighthouse": {
    "apiEndpoint": "https://node.lighthouse.storage/api/v0/add",
    "gatewayUrl": "https://gateway.lighthouse.storage/ipfs"
  }
}
```

### Token Addresses (Replace if needed):
- **LEMO Token** (Sepolia): `0x14572da77700C59D2f8D61a3C4b25744D6dCde8D`
- **USDC** (Sepolia): `0x_REPLACE_WITH_ACTUAL_ADDRESS`
- **tFIL** (Calibration): `0x_REPLACE_WITH_ACTUAL_ADDRESS`

## 🧪 Testing Workflow

### Test 1: Record a Receipt
1. In Remix, select `LighthouseReceipt` contract
2. Call `recordReceipt` with test data:
   ```
   buyer: 0xYourTestAddress
   productId: "PROD-12345"
   cid: "QmTest123..."  (get from Lighthouse upload)
   paymentToken: 0x0000000000000000000000000000000000000000  (for ETH)
   amountPaid: 1000000000000000000  (1 ETH in wei)
   currency: "ETH"
   ```
3. Check the emitted `ReceiptRecorded` event
4. Call `getReceipt(0)` to verify storage

### Test 2: Submit Feedback & Earn LEMO
1. Ensure feedback contract is funded (see above)
2. In Remix, select `TrustlessAgentFeedback` contract
3. Call `submitFeedback`:
   ```
   receiptId: 0
   feedbackCid: "QmFeedback123..."  (from Lighthouse upload)
   ```
4. Check your wallet - you should receive 1,000,000 LEMO tokens
5. Verify: call `getLEMOBalance()` on contract to see remaining balance

### Test 3: Query Receipt by Buyer
1. Call `getReceiptsByBuyer(yourAddress)`
2. Should return array of receipt IDs: `[0, 1, 2, ...]`

## 📦 IPFS Gateway URLs

To view uploaded CIDs:
- **Lighthouse Gateway**: `https://gateway.lighthouse.storage/ipfs/{CID}`
- **IPFS.io Gateway**: `https://ipfs.io/ipfs/{CID}`
- **Cloudflare Gateway**: `https://cloudflare-ipfs.com/ipfs/{CID}`

## 🔐 Security Considerations

1. **Reentrancy Protection**: `TrustlessAgentFeedback` includes reentrancy guard
2. **Owner Controls**: All contracts have `onlyOwner` modifiers for admin functions
3. **One Feedback Per Receipt**: Prevents reward farming
4. **CID Uniqueness**: Prevents duplicate receipt submissions

## 📝 Contract Functions Reference

### LighthouseReceipt
- `recordReceipt(...)` - Records a new receipt
- `getReceipt(receiptId)` - Retrieves receipt data
- `getReceiptsByBuyer(buyer)` - Gets all receipts for a buyer
- `isCIDRecorded(cid)` - Checks if CID exists

### TrustlessAgentFeedback
- `submitFeedback(receiptId, feedbackCid)` - Submit feedback & earn LEMO
- `getFeedback(feedbackId)` - Retrieves feedback data
- `hasFeedback(receiptId)` - Checks if receipt has feedback
- `getLEMOBalance()` - Check contract's LEMO balance
- `fundContract(amount)` - Owner funds contract with LEMO
- `withdrawLEMO()` - Owner emergency withdrawal

### AgentRegistry
- `registerAgent(name)` - Register as an agent
- `getAgent(agentAddress)` - Get agent information
- `updateReputation(agent, score)` - Update agent reputation (owner only)

## 🐛 Troubleshooting

### "Contract has insufficient LEMO tokens for reward"
- Fund the contract using `fundContract()` after approving LEMO tokens

### "CID already recorded"
- Each CID can only be recorded once - use a unique CID for each receipt

### "Feedback already submitted for this receipt"
- Only one feedback per receipt is allowed to prevent spam

### Transaction fails with "execution reverted"
- Check MetaMask is on the correct network
- Ensure you have enough ETH/tFIL for gas
- Verify contract addresses are correct

## 📚 Additional Resources

- [Lighthouse Documentation](https://docs.lighthouse.storage/)
- [Filecoin FVM Docs](https://docs.filecoin.io/smart-contracts/fundamentals/the-fvm)
- [EIP-8004 Proposal](https://eips.ethereum.org/EIPS/eip-8004)
- [Remix IDE Documentation](https://remix-ide.readthedocs.io/)

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review contract comments in the source code
3. Test on Sepolia/Calibration testnet before mainnet

---

**Built with ❤️ for decentralized e-commerce by the Lemo team**


Remix-ready smart contracts for decentralized receipt storage and automated feedback rewards using Lighthouse/IPFS and Filecoin FVM.

## 📋 Overview

This integration includes:
- **LighthouseReceipt.sol**: Stores purchase receipts with IPFS CIDs on-chain
- **TrustlessAgentFeedback.sol**: Manages feedback submission and automatic LEMO token rewards
- **AgentRegistry.sol**: EIP-8004 inspired agent identity and reputation registry
- **IERC20.sol**: Standard ERC20 interface for token interactions

## 🚀 Deployment Instructions (Remix)

### Step 1: Open Remix IDE
1. Navigate to [https://remix.ethereum.org](https://remix.ethereum.org)
2. Create a new workspace or use the default workspace

### Step 2: Upload Contract Files
1. In Remix's File Explorer, create the following structure:
   ```
   contracts/
   ├── LighthouseReceipt.sol
   ├── TrustlessAgentFeedback.sol
   ├── AgentRegistry.sol
   └── interfaces/
       └── IERC20.sol
   ```
2. Copy and paste each contract file from this repository

### Step 3: Compile Contracts
1. Go to the "Solidity Compiler" tab (left sidebar)
2. Select compiler version: **0.8.18** or higher
3. Enable optimization (200 runs recommended)
4. Click "Compile" for each contract

### Step 4: Configure Network

#### For Sepolia Testnet (LEMO Token Network):
- **Network Name**: Sepolia
- **RPC URL**: `https://rpc.sepolia.org`
- **Chain ID**: 11155111
- **Symbol**: ETH
- **Block Explorer**: https://sepolia.etherscan.io

#### For Filecoin Calibration Testnet:
- **Network Name**: Filecoin Calibration
- **RPC URL**: `https://api.calibration.node.glif.io/rpc/v1`
- **Chain ID**: 314159
- **Symbol**: tFIL
- **Block Explorer**: https://calibration.filfox.info

### Step 5: Deploy Contracts

#### Deploy Order:
1. **LighthouseReceipt.sol** (deploy to BOTH Sepolia and Calibration)
2. **AgentRegistry.sol** (deploy to Sepolia)
3. **TrustlessAgentFeedback.sol** (deploy to Sepolia)

#### Deployment Steps:

##### 1. Deploy LighthouseReceipt
- Go to "Deploy & Run Transactions" tab
- Select "Injected Provider - MetaMask"
- Switch MetaMask to Sepolia network
- Select contract: `LighthouseReceipt`
- Click "Deploy"
- **Save the deployed address** (you'll need it for the extension)
- Repeat for Filecoin Calibration network

##### 2. Deploy AgentRegistry
- Switch MetaMask to Sepolia
- Select contract: `AgentRegistry`
- Click "Deploy"
- **Save the deployed address**

##### 3. Deploy TrustlessAgentFeedback
- **IMPORTANT**: Before deploying, verify the LEMO token address in the contract:
  - Default: `0x14572da77700C59D2f8D61a3C4b25744D6dCde8D`
  - If different, edit line 22 in the contract before compiling
- Switch MetaMask to Sepolia
- Select contract: `TrustlessAgentFeedback`
- Click "Deploy"
- **Save the deployed address**

## 💰 Funding the Feedback Contract

The `TrustlessAgentFeedback` contract MUST be funded with LEMO tokens before users can submit feedback.

### Step 1: Approve LEMO Tokens
1. In Remix, load the LEMO token contract at: `0x14572dA77700c59D2F8D61a3c4B25744D6DcDE8D`
2. Use a standard ERC20 ABI or import IERC20.sol
3. Call `approve(feedbackContractAddress, amount)`
   - `feedbackContractAddress`: Your deployed TrustlessAgentFeedback address
   - `amount`: Total LEMO to allocate (e.g., `10000000000000000000000000` for 10M LEMO)

### Step 2: Fund the Contract
1. In the deployed `TrustlessAgentFeedback` contract
2. Call `fundContract(amount)`
   - `amount`: Same as approved amount
3. Verify funding: call `getLEMOBalance()` to check contract balance

### Reward Calculation:
- Each feedback submission rewards: **1,000,000 LEMO** (1e24 wei)
- To support 100 feedbacks: fund with 100,000,000 LEMO tokens

## 🔧 Configuration for Extension

After deployment, update the following in your Lemo extension:

### Create `Lighthouse-Integration/deployment-config.json`:
```json
{
  "networks": {
    "sepolia": {
      "chainId": 11155111,
      "rpcUrl": "https://rpc.sepolia.org",
      "contracts": {
        "LighthouseReceipt": "0x_YOUR_DEPLOYED_ADDRESS_HERE",
        "TrustlessAgentFeedback": "0x_YOUR_DEPLOYED_ADDRESS_HERE",
        "AgentRegistry": "0x_YOUR_DEPLOYED_ADDRESS_HERE",
        "LEMOToken": "0x14572da77700C59D2f8D61a3C4b25744D6dCde8D"
      }
    },
    "calibration": {
      "chainId": 314159,
      "rpcUrl": "https://api.calibration.node.glif.io/rpc/v1",
      "contracts": {
        "LighthouseReceipt": "0x_YOUR_DEPLOYED_ADDRESS_HERE"
      }
    }
  },
  "lighthouse": {
    "apiEndpoint": "https://node.lighthouse.storage/api/v0/add",
    "gatewayUrl": "https://gateway.lighthouse.storage/ipfs"
  }
}
```

### Token Addresses (Replace if needed):
- **LEMO Token** (Sepolia): `0x14572da77700C59D2f8D61a3C4b25744D6dCde8D`
- **USDC** (Sepolia): `0x_REPLACE_WITH_ACTUAL_ADDRESS`
- **tFIL** (Calibration): `0x_REPLACE_WITH_ACTUAL_ADDRESS`

## 🧪 Testing Workflow

### Test 1: Record a Receipt
1. In Remix, select `LighthouseReceipt` contract
2. Call `recordReceipt` with test data:
   ```
   buyer: 0xYourTestAddress
   productId: "PROD-12345"
   cid: "QmTest123..."  (get from Lighthouse upload)
   paymentToken: 0x0000000000000000000000000000000000000000  (for ETH)
   amountPaid: 1000000000000000000  (1 ETH in wei)
   currency: "ETH"
   ```
3. Check the emitted `ReceiptRecorded` event
4. Call `getReceipt(0)` to verify storage

### Test 2: Submit Feedback & Earn LEMO
1. Ensure feedback contract is funded (see above)
2. In Remix, select `TrustlessAgentFeedback` contract
3. Call `submitFeedback`:
   ```
   receiptId: 0
   feedbackCid: "QmFeedback123..."  (from Lighthouse upload)
   ```
4. Check your wallet - you should receive 1,000,000 LEMO tokens
5. Verify: call `getLEMOBalance()` on contract to see remaining balance

### Test 3: Query Receipt by Buyer
1. Call `getReceiptsByBuyer(yourAddress)`
2. Should return array of receipt IDs: `[0, 1, 2, ...]`

## 📦 IPFS Gateway URLs

To view uploaded CIDs:
- **Lighthouse Gateway**: `https://gateway.lighthouse.storage/ipfs/{CID}`
- **IPFS.io Gateway**: `https://ipfs.io/ipfs/{CID}`
- **Cloudflare Gateway**: `https://cloudflare-ipfs.com/ipfs/{CID}`

## 🔐 Security Considerations

1. **Reentrancy Protection**: `TrustlessAgentFeedback` includes reentrancy guard
2. **Owner Controls**: All contracts have `onlyOwner` modifiers for admin functions
3. **One Feedback Per Receipt**: Prevents reward farming
4. **CID Uniqueness**: Prevents duplicate receipt submissions

## 📝 Contract Functions Reference

### LighthouseReceipt
- `recordReceipt(...)` - Records a new receipt
- `getReceipt(receiptId)` - Retrieves receipt data
- `getReceiptsByBuyer(buyer)` - Gets all receipts for a buyer
- `isCIDRecorded(cid)` - Checks if CID exists

### TrustlessAgentFeedback
- `submitFeedback(receiptId, feedbackCid)` - Submit feedback & earn LEMO
- `getFeedback(feedbackId)` - Retrieves feedback data
- `hasFeedback(receiptId)` - Checks if receipt has feedback
- `getLEMOBalance()` - Check contract's LEMO balance
- `fundContract(amount)` - Owner funds contract with LEMO
- `withdrawLEMO()` - Owner emergency withdrawal

### AgentRegistry
- `registerAgent(name)` - Register as an agent
- `getAgent(agentAddress)` - Get agent information
- `updateReputation(agent, score)` - Update agent reputation (owner only)

## 🐛 Troubleshooting

### "Contract has insufficient LEMO tokens for reward"
- Fund the contract using `fundContract()` after approving LEMO tokens

### "CID already recorded"
- Each CID can only be recorded once - use a unique CID for each receipt

### "Feedback already submitted for this receipt"
- Only one feedback per receipt is allowed to prevent spam

### Transaction fails with "execution reverted"
- Check MetaMask is on the correct network
- Ensure you have enough ETH/tFIL for gas
- Verify contract addresses are correct

## 📚 Additional Resources

- [Lighthouse Documentation](https://docs.lighthouse.storage/)
- [Filecoin FVM Docs](https://docs.filecoin.io/smart-contracts/fundamentals/the-fvm)
- [EIP-8004 Proposal](https://eips.ethereum.org/EIPS/eip-8004)
- [Remix IDE Documentation](https://remix-ide.readthedocs.io/)

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review contract comments in the source code
3. Test on Sepolia/Calibration testnet before mainnet

---

**Built with ❤️ for decentralized e-commerce by the Lemo team**









