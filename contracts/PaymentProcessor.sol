// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title PaymentProcessor
 * @notice Processes PYUSD (and other ERC-20) payments and automatically records receipts on LighthouseReceipt
 * @dev This contract facilitates payments to a merchant wallet and integrates with the LighthouseReceipt contract.
 *      IMPORTANT: Users must approve this contract to spend their PYUSD before calling processPayment.
 *      
 *      Payment Flow:
 *      1. Extension uploads receipt JSON to Lighthouse/IPFS (gets CID)
 *      2. User approves PaymentProcessor to spend PYUSD tokens
 *      3. User calls processPayment() which:
 *         - Transfers PYUSD from user to merchant wallet
 *         - Records receipt on LighthouseReceipt contract
 *         - Emits PaymentProcessed event
 *      
 *      Security: All payments go directly to merchant wallet (no escrow in contract).
 */

// Inline IERC20 interface for PYUSD and other ERC-20 tokens
interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

// Inline LighthouseReceipt interface
interface ILighthouseReceipt {
    function recordReceipt(
        address buyer,
        string memory productId,
        string memory cid,
        address paymentToken,
        uint256 amountPaid,
        string memory currency
    ) external returns (uint256);
}

contract PaymentProcessor {
    
    // Struct to store payment details
    struct Payment {
        uint256 paymentId;
        address buyer;
        string productId;
        uint256 amount;
        address paymentToken;
        string currency;
        uint256 receiptId;      // Receipt ID from LighthouseReceipt contract
        string receiptCid;      // IPFS/Lighthouse CID
        uint256 timestamp;
        bool completed;
    }
    
    // State variables
    address public owner;
    address public merchantWallet;
    address public lighthouseReceiptContract;
    uint256 public paymentCount;
    
    // Reentrancy guard
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;
    
    // Mappings
    mapping(uint256 => Payment) public payments;
    mapping(address => uint256[]) private buyerPayments;
    
    // Events
    event PaymentProcessed(
        uint256 indexed paymentId,
        address indexed buyer,
        string productId,
        uint256 amount,
        address paymentToken,
        uint256 receiptId,
        string receiptCid,
        uint256 timestamp
    );
    
    event MerchantWalletUpdated(address indexed previousWallet, address indexed newWallet);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
    
    /**
     * @notice Constructor
     * @param _lighthouseReceiptContract Address of the deployed LighthouseReceipt contract
     * @param _merchantWallet Address that will receive all payments
     */
    constructor(address _lighthouseReceiptContract, address _merchantWallet) {
        require(_lighthouseReceiptContract != address(0), "Invalid LighthouseReceipt address");
        require(_merchantWallet != address(0), "Invalid merchant wallet address");
        
        owner = msg.sender;
        lighthouseReceiptContract = _lighthouseReceiptContract;
        merchantWallet = _merchantWallet;
        paymentCount = 0;
        _status = NOT_ENTERED;
    }
    
    /**
     * @notice Processes a payment and records the receipt on-chain
     * @dev IMPORTANT: Buyer must approve this contract to spend paymentToken before calling this function
     *      
     *      Steps:
     *      1. Validates input parameters
     *      2. Checks buyer has approved sufficient tokens
     *      3. Transfers tokens from buyer to merchant wallet
     *      4. Records receipt on LighthouseReceipt contract
     *      5. Stores payment details and emits event
     *      
     * @param productId Identifier for the product (URL, SKU, or unique ID)
     * @param amount Amount to pay in token's smallest unit (e.g., 6 decimals for PYUSD)
     * @param receiptCid IPFS/Lighthouse CID of the receipt JSON (must be uploaded before calling)
     * @param paymentToken Address of the ERC-20 token (e.g., PYUSD address)
     * @param currency Human-readable currency string ("PYUSD", "USDC", etc.)
     * @return paymentId The unique ID of this payment
     * @return receiptId The receipt ID from LighthouseReceipt contract
     */
    function processPayment(
        string memory productId,
        uint256 amount,
        string memory receiptCid,
        address paymentToken,
        string memory currency
    ) external nonReentrant returns (uint256 paymentId, uint256 receiptId) {
        // Input validation
        require(bytes(productId).length > 0, "Product ID cannot be empty");
        require(amount > 0, "Amount must be greater than 0");
        require(bytes(receiptCid).length > 0, "Receipt CID cannot be empty");
        require(paymentToken != address(0), "Invalid payment token address");
        require(bytes(currency).length > 0, "Currency cannot be empty");
        
        // Check token approval
        IERC20 token = IERC20(paymentToken);
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= amount, "Insufficient token allowance. Please approve tokens first.");
        
        // Check buyer has sufficient balance
        uint256 buyerBalance = token.balanceOf(msg.sender);
        require(buyerBalance >= amount, "Insufficient token balance");
        
        // Transfer tokens from buyer to merchant wallet
        bool transferSuccess = token.transferFrom(msg.sender, merchantWallet, amount);
        require(transferSuccess, "Token transfer failed");
        
        // Record receipt on LighthouseReceipt contract
        receiptId = ILighthouseReceipt(lighthouseReceiptContract).recordReceipt(
            msg.sender,
            productId,
            receiptCid,
            paymentToken,
            amount,
            currency
        );
        
        // Store payment details
        paymentId = paymentCount;
        paymentCount++;
        
        Payment storage newPayment = payments[paymentId];
        newPayment.paymentId = paymentId;
        newPayment.buyer = msg.sender;
        newPayment.productId = productId;
        newPayment.amount = amount;
        newPayment.paymentToken = paymentToken;
        newPayment.currency = currency;
        newPayment.receiptId = receiptId;
        newPayment.receiptCid = receiptCid;
        newPayment.timestamp = block.timestamp;
        newPayment.completed = true;
        
        buyerPayments[msg.sender].push(paymentId);
        
        // Emit event
        emit PaymentProcessed(
            paymentId,
            msg.sender,
            productId,
            amount,
            paymentToken,
            receiptId,
            receiptCid,
            block.timestamp
        );
        
        return (paymentId, receiptId);
    }
    
    /**
     * @notice Retrieves payment details by payment ID
     * @param _paymentId The ID of the payment to retrieve
     * @return Payment struct containing all payment data
     */
    function getPaymentDetails(uint256 _paymentId) external view returns (Payment memory) {
        require(_paymentId < paymentCount, "Payment does not exist");
        return payments[_paymentId];
    }
    
    /**
     * @notice Gets all payment IDs for a specific buyer
     * @param buyer Address of the buyer
     * @return Array of payment IDs
     */
    function getPaymentsByBuyer(address buyer) external view returns (uint256[] memory) {
        return buyerPayments[buyer];
    }
    
    /**
     * @notice Updates the merchant wallet address
     * @dev Only owner can call this function
     * @param newMerchant Address of the new merchant wallet
     */
    function updateMerchantWallet(address newMerchant) external onlyOwner {
        require(newMerchant != address(0), "Invalid merchant wallet address");
        address previousWallet = merchantWallet;
        merchantWallet = newMerchant;
        emit MerchantWalletUpdated(previousWallet, newMerchant);
    }
    
    /**
     * @notice Emergency withdrawal of accidentally sent tokens
     * @dev Only owner can call this function. Use only for tokens accidentally sent to contract.
     *      Normal payment flow sends tokens directly to merchant wallet.
     * @param token Address of the token to withdraw (address(0) for native ETH)
     */
    function emergencyWithdraw(address token) external onlyOwner nonReentrant {
        if (token == address(0)) {
            // Withdraw native ETH
            uint256 balance = address(this).balance;
            require(balance > 0, "No ETH to withdraw");
            (bool success, ) = owner.call{value: balance}("");
            require(success, "ETH transfer failed");
            emit EmergencyWithdrawal(address(0), owner, balance);
        } else {
            // Withdraw ERC-20 tokens
            IERC20 tokenContract = IERC20(token);
            uint256 balance = tokenContract.balanceOf(address(this));
            require(balance > 0, "No tokens to withdraw");
            bool success = tokenContract.transferFrom(address(this), owner, balance);
            require(success, "Token transfer failed");
            emit EmergencyWithdrawal(token, owner, balance);
        }
    }
    
    /**
     * @notice Transfers ownership of the contract
     * @param newOwner Address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
    
    /**
     * @notice Fallback function to reject direct ETH transfers
     * @dev Payments should go through processPayment function
     */
    receive() external payable {
        revert("Direct ETH transfers not accepted. Use processPayment function.");
    }
}

