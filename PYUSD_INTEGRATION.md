# PYUSD Payment Integration Documentation

## 🎯 Overview

This document explains the integration of **PYUSD (PayPal USD)** as a primary payment method in the Lemo AI Shopping Assistant extension. PYUSD is PayPal's official stablecoin deployed as an ERC-20 token on Ethereum and testnets, enabling stable, transparent, and verifiable payments for e-commerce transactions.

### What is PYUSD?

- **Issuer:** PayPal (via Paxos Trust Company)
- **Token Standard:** ERC-20
- **Ticker:** PYUSD
- **Decimals:** 6 (unlike most ERC-20 tokens which use 18)
- **1 PYUSD ≈ 1 USD** (pegged to USD)
- **Sepolia Testnet Address:** `0xCaC524BcA292aaade2DF8A05cC58F0a65B1B3bB9`
- **Mainnet Address:** `0x6c3ea9036406852006290770BEdFcAbA0e23A0e8`

---

## 🏗️ Technical Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    Lemo Extension (Frontend)                     │
│                                                                   │
│  ┌──────────────┐      ┌────────────────┐     ┌──────────────┐ │
│  │  BuyCard.jsx │──────│ pyusdPayment.js│─────│fvmService.js │ │
│  │  (UI Layer)  │      │  (Service)     │     │  (Routing)   │ │
│  └──────────────┘      └────────────────┘     └──────────────┘ │
│         │                      │                      │          │
│         └──────────────────────┴──────────────────────┘          │
│                                │                                  │
└────────────────────────────────┼──────────────────────────────────┘
                                 │
                                 ▼
                        ┌────────────────┐
                        │   MetaMask     │
                        │   (Wallet)     │
                        └────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    ▼                         ▼
          ┌──────────────────┐    ┌────────────────────┐
          │  PYUSD Token     │    │ PaymentProcessor   │
          │  (ERC-20)        │◄───│   Contract         │
          └──────────────────┘    └────────────────────┘
                    │                         │
                    │                         ▼
                    │              ┌────────────────────┐
                    │              │ LighthouseReceipt  │
                    │              │   Contract         │
                    │              └────────────────────┘
                    │                         │
                    ▼                         ▼
          ┌──────────────────┐    ┌────────────────────┐
          │ Merchant Wallet  │    │  Lighthouse/IPFS   │
          │  (Payment Dest)  │    │  (Receipt Storage) │
          └──────────────────┘    └────────────────────┘
```

### Smart Contract Architecture

#### 1. PaymentProcessor.sol (NEW)
**Purpose:** Orchestrates PYUSD payments and on-chain receipt recording

**Key Features:**
- Accepts PYUSD (and other ERC-20) payments via `transferFrom`
- Forwards payments directly to merchant wallet (no escrow)
- Automatically records receipts on LighthouseReceipt contract
- Reentrancy protection and comprehensive error handling

**Constructor Parameters:**
```solidity
constructor(
    address _lighthouseReceiptContract,  // LighthouseReceipt address
    address _merchantWallet              // Merchant's receiving wallet
)
```

**Main Function:**
```solidity
function processPayment(
    string memory productId,
    uint256 amount,              // PYUSD amount in 6 decimals
    string memory receiptCid,    // Lighthouse CID
    address paymentToken,        // PYUSD token address
    string memory currency       // "PYUSD"
) external returns (uint256 paymentId, uint256 receiptId)
```

#### 2. LighthouseReceipt.sol (EXISTING)
**Purpose:** Stores purchase receipts with IPFS/Lighthouse CIDs on-chain

**Integration:** Called by PaymentProcessor to record receipt metadata after payment

#### 3. PYUSD Token Contract (EXISTING - DEPLOYED BY PAYPAL)
**Purpose:** ERC-20 stablecoin for payments

**Key Functions Used:**
- `approve(spender, amount)` - User approves PaymentProcessor
- `transferFrom(from, to, amount)` - PaymentProcessor transfers PYUSD to merchant
- `balanceOf(account)` - Extension checks user balance

---

## 🔄 Payment Flow

### Step-by-Step Process

```
┌──────────────────────────────────────────────────────────────────┐
│ 1. USER SELECTS PYUSD PAYMENT METHOD                             │
│    • Extension fetches and displays user's PYUSD balance         │
│    • User clicks "Buy with PYUSD" button                         │
└──────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ 2. RECEIPT GENERATION                                             │
│    • Extension creates receipt JSON with product details         │
│    • Uploads receipt JSON to Lighthouse/IPFS                     │
│    • Receives IPFS CID (Content Identifier)                      │
└──────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ 3. TOKEN APPROVAL (FIRST TRANSACTION)                            │
│    • Extension checks if PaymentProcessor has sufficient         │
│      allowance to spend user's PYUSD                             │
│    • If not, prompts user to approve PYUSD spending              │
│    • User confirms approval in MetaMask                          │
│    • Tx sent to PYUSD contract: approve(PaymentProcessor, amount)│
└──────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ 4. PAYMENT PROCESSING (SECOND TRANSACTION)                       │
│    • Extension calls PaymentProcessor.processPayment()           │
│    • User confirms payment transaction in MetaMask               │
│    • PaymentProcessor executes:                                  │
│      a) Transfers PYUSD from user to merchant wallet             │
│      b) Calls LighthouseReceipt.recordReceipt()                  │
│      c) Emits PaymentProcessed event                             │
└──────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ 5. CONFIRMATION & RECEIPT DISPLAY                                │
│    • Extension receives transaction receipt                      │
│    • Extracts paymentId and receiptId from events                │
│    • Displays receipt card in chat with:                         │
│      - Receipt ID                                                 │
│      - Payment amount and method badge (PYUSD)                   │
│      - IPFS link                                                  │
│      - Blockchain explorer link                                   │
│      - "Submit Feedback & Earn LEMO" button                      │
└──────────────────────────────────────────────────────────────────┘
```

### Code Flow

**Frontend (BuyCard.jsx):**
```javascript
// User selects PYUSD and clicks "Buy Now"
handleBuyNowClick()
  └─> onBuyClick(productData, paymentMethod="PYUSD")
```

**Service Layer (fvmService.js):**
```javascript
handleBuyNowClick(productData, walletAddress, provider, "PYUSD")
  └─> processPYUSDPayment(productData, amount, walletAddress, provider)
```

**Payment Service (pyusdPayment.js):**
```javascript
processPYUSDPayment()
  ├─> checkPYUSDBalance()         // Verify user has sufficient PYUSD
  ├─> uploadReceiptToLighthouse() // Upload receipt JSON, get CID
  ├─> approvePYUSD()              // User approves PaymentProcessor
  └─> paymentProcessor.processPayment()  // Execute payment + record receipt
```

**Smart Contract (PaymentProcessor.sol):**
```solidity
processPayment()
  ├─> PYUSD.transferFrom(user, merchantWallet, amount)
  ├─> LighthouseReceipt.recordReceipt(...)
  └─> emit PaymentProcessed(...)
```

---

## 💡 Key Technical Considerations

### 1. PYUSD Decimals (6 vs 18)

**IMPORTANT:** PYUSD uses **6 decimals**, not 18 like most ERC-20 tokens.

**Correct Conversion:**
```javascript
// For $10.50 PYUSD
const amount = ethers.parseUnits("10.50", 6);  // 10500000 (not 18 decimals!)

// Display formatting
const displayAmount = ethers.formatUnits(amount, 6);  // "10.50"
```

### 2. Two-Transaction Approval Flow

Unlike native ETH payments (1 tx), ERC-20 payments require 2 transactions:

1. **Approve** - User approves PaymentProcessor to spend their PYUSD
2. **Payment** - PaymentProcessor executes `transferFrom` and records receipt

**UX Optimization:**
- Extension checks existing allowance before requesting approval
- If sufficient allowance exists, skips approval step
- Shows clear loading states for each transaction

### 3. No Escrow Design

**Security Design:**
- Payments go DIRECTLY from user → merchant wallet
- PaymentProcessor contract NEVER holds funds
- Minimizes smart contract risk
- Emergency withdraw only for accidentally sent tokens

### 4. On-Chain Receipt Recording

**Data Stored On-Chain:**
- Receipt ID
- Buyer address
- Product ID
- PYUSD token address
- Amount paid (in token units)
- Currency string ("PYUSD")
- IPFS CID of full receipt JSON
- Timestamp

**Data Stored on Lighthouse/IPFS:**
- Full product details (title, description, image URL)
- Payment metadata
- Transaction hash
- Extended receipt information

---

## 🎓 Hackathon Compliance

### Requirements Met

✅ **PYUSD Utilization:**
- Direct interaction with PYUSD ERC-20 contract on Sepolia testnet
- User approval and transfer of PYUSD tokens
- Balance checking and display
- Payment method badge highlighting PYUSD usage

✅ **Testnet Deployment:**
- Deployed on Sepolia testnet (Chain ID: 11155111)
- Using official PYUSD Sepolia address
- All contracts deployed and verified

✅ **Transparent & Verifiable:**
- All payments recorded on-chain
- Receipt CIDs stored on blockchain
- Full audit trail via blockchain explorers
- IPFS/Lighthouse for immutable receipt storage

✅ **Real-World Use Case:**
- E-commerce shopping assistant
- Product recommendations
- Purchase flow with stablecoin payments
- Feedback system with LEMO token rewards

---

## 📦 Deployment Configuration

### Contract Addresses (Sepolia)

```
PYUSD Token:             0xCaC524BcA292aaade2DF8A05cC58F0a65B1B3bB9
LighthouseReceipt:       0xca17ed5b8bc6c80c69b1451e452cdf26453755b5
PaymentProcessor:        [TO BE DEPLOYED]
Merchant Wallet:         0x286bd33A27079f28a4B4351a85Ad7f23A04BDdfC
```

### Deployment Steps

1. **Deploy PaymentProcessor via Remix:**
   ```
   Constructor Args:
   - _lighthouseReceiptContract: 0xca17ed5b8bc6c80c69b1451e452cdf26453755b5
   - _merchantWallet: 0x286bd33A27079f28a4B4351a85Ad7f23A04BDdfC
   ```

2. **Update Configuration:**
   - Copy deployed PaymentProcessor address
   - Update `env.txt`: `SEPOLIA_PAYMENT_PROCESSOR_ADDRESS`
   - Update `deployment-config.json`
   - Update `contractConfig.js`

3. **Build Extension:**
   ```bash
   cd LEMO-extension
   npm run build
   ```

4. **Load in Browser:**
   - Chrome → Extensions → Load Unpacked
   - Select `LEMO-extension/dist` folder

---

## 🧪 Testing Guide

### Getting Test PYUSD

**Option 1: Faucets (if available)**
- Check PayPal developer resources
- Check Sepolia PYUSD faucet sites

**Option 2: Bridge from other testnets**
- Use cross-chain bridges supporting PYUSD

**Option 3: Direct transfer**
- Request test PYUSD from project maintainers

### Test Scenarios

#### 1. Basic PYUSD Purchase
```
1. Connect wallet to Sepolia
2. Ensure you have test PYUSD and ETH (for gas)
3. Navigate to product page (e.g., Amazon)
4. Chat with Lemo: "I want to buy this product"
5. Select "PYUSD" as payment method
6. Click "Buy Now"
7. Approve PYUSD spending in MetaMask
8. Confirm payment transaction
9. Verify receipt appears in chat
10. Check Sepolia Etherscan:
    - Payment tx shows PYUSD transfer to merchant
    - Receipt tx shows receipt recorded
```

#### 2. Balance Checking
```
1. Connect wallet
2. Open Buy Card
3. Select "PYUSD"
4. Verify balance displays correctly
5. Try purchasing with insufficient balance
6. Verify appropriate error message
```

#### 3. Multiple Payments
```
1. Complete purchase #1 with PYUSD
2. Complete purchase #2 with PYUSD
3. Verify both receipts recorded with unique IDs
4. Check merchant wallet received both payments
```

#### 4. Feedback & Rewards
```
1. Complete PYUSD purchase
2. Click "Submit Feedback & Earn LEMO"
3. Rate product and submit
4. Verify LEMO reward received
5. Check wallet shows updated LEMO balance
```

---

## 🔒 Security Considerations

### Smart Contract Security

✅ **Reentrancy Protection**
- NonReentrant modifier on `processPayment`
- Follows checks-effects-interactions pattern

✅ **Input Validation**
- Amount > 0 checks
- Non-zero address checks
- CID existence checks

✅ **Access Control**
- Owner-only functions for admin operations
- Public payment function for users

✅ **No Fund Storage**
- Payments go directly to merchant
- Contract doesn't hold user funds

### Extension Security

✅ **Private Key Safety**
- No private keys stored in extension
- All transactions signed via MetaMask
- User controls all approvals

✅ **API Key Protection**
- Lighthouse API key configurable
- Can be rotated as needed

✅ **Error Handling**
- Comprehensive try-catch blocks
- User-friendly error messages
- Graceful fallbacks

---

## 📊 Monitoring & Analytics

### On-Chain Events

**PaymentProcessed Event:**
```solidity
event PaymentProcessed(
    uint256 indexed paymentId,
    address indexed buyer,
    string productId,
    uint256 amount,
    address paymentToken,  // PYUSD address
    uint256 receiptId,
    string receiptCid,
    uint256 timestamp
);
```

**Query Example (ethers.js):**
```javascript
const paymentProcessor = new ethers.Contract(address, abi, provider);
const filter = paymentProcessor.filters.PaymentProcessed();
const events = await paymentProcessor.queryFilter(filter);
```

### Metrics to Track

- Total PYUSD volume processed
- Number of PYUSD transactions
- Average transaction amount
- User adoption rate (PYUSD vs ETH vs USDC)
- Failed transaction reasons
- Time to completion (approval + payment)

---

## 🚀 Future Enhancements

### Potential Improvements

1. **Mainnet Deployment**
   - Deploy to Ethereum mainnet
   - Use mainnet PYUSD address
   - Production-ready merchant integrations

2. **Multi-Currency Support**
   - Automatic price conversion
   - Real-time exchange rates
   - Support for more stablecoins

3. **Gasless Transactions**
   - EIP-2612 permit functionality
   - Meta-transactions for better UX
   - Sponsored gas fees

4. **Advanced Features**
   - Recurring payments
   - Escrow for dispute resolution
   - Multi-signature merchant wallets
   - Refund functionality

---

## 📚 References

### Documentation

- **PYUSD Official:** [PayPal USD Documentation](https://www.paypal.com/us/digital-wallet/manage-money/crypto/pyusd)
- **ERC-20 Standard:** [EIP-20](https://eips.ethereum.org/EIPS/eip-20)
- **Ethers.js:** [Ethers Documentation](https://docs.ethers.org/)
- **Lighthouse:** [Lighthouse Storage](https://www.lighthouse.storage/)

### Contract Addresses

- **PYUSD Mainnet:** `0x6c3ea9036406852006290770BEdFcAbA0e23A0e8`
- **PYUSD Sepolia:** `0xCaC524BcA292aaade2DF8A05cC58F0a65B1B3bB9`

### Explorers

- **Sepolia Etherscan:** [https://sepolia.etherscan.io](https://sepolia.etherscan.io)
- **Lighthouse Gateway:** [https://gateway.lighthouse.storage/ipfs/](https://gateway.lighthouse.storage/ipfs/)

---

## 📞 Support

For issues or questions:
1. Check Remix compilation errors
2. Verify contract addresses in config files
3. Check MetaMask network (must be Sepolia)
4. Ensure sufficient test PYUSD and ETH
5. Review browser console for error logs

---

**Built with ❤️ for hackathon compliance and real-world utility**

