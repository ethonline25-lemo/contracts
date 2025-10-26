// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title LighthouseReceipt
 * @notice Stores purchase receipts with IPFS/Lighthouse CIDs on-chain
 * @dev This contract records receipt metadata and CIDs. The actual receipt data is stored on IPFS/Lighthouse.
 *      On-chain storage cannot verify IPFS content - verification must be done off-chain by the extension.
 */
contract LighthouseReceipt {
    
    struct Receipt {
        address buyer;
        string productId;
        string cid;              // IPFS/Lighthouse CID
        address paymentToken;    // Address(0) for ETH, token address for ERC20
        uint256 amountPaid;
        string currency;         // "ETH", "USDC", "TFIL", etc.
        uint256 timestamp;
    }
    
    // State variables
    address public owner;
    uint256 public receiptCount;
    
    // Mappings
    mapping(uint256 => Receipt) public receipts;
    mapping(string => bool) public cidExists;
    mapping(address => uint256[]) private buyerReceipts;
    
    // Events
    event ReceiptRecorded(
        uint256 indexed receiptId,
        address indexed buyer,
        string productId,
        string cid,
        address paymentToken,
        uint256 amountPaid,
        string currency,
        uint256 timestamp
    );
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        receiptCount = 0;
    }
    
    /**
     * @notice Records a new purchase receipt on-chain
     * @dev The CID must be uploaded to Lighthouse/IPFS before calling this function
     * @param buyer Address of the buyer
     * @param productId Product identifier (can be URL, SKU, or any unique ID)
     * @param cid IPFS/Lighthouse CID of the receipt JSON
     * @param paymentToken Token address (address(0) for native ETH)
     * @param amountPaid Amount paid in smallest unit (wei for ETH, token decimals for ERC20)
     * @param currency Human-readable currency string ("ETH", "USDC", etc.)
     * @return receiptId The unique ID of the recorded receipt
     */
    function recordReceipt(
        address buyer,
        string memory productId,
        string memory cid,
        address paymentToken,
        uint256 amountPaid,
        string memory currency
    ) external returns (uint256 receiptId) {
        require(buyer != address(0), "Invalid buyer address");
        require(bytes(productId).length > 0, "Product ID cannot be empty");
        require(bytes(cid).length > 0, "CID cannot be empty");
        require(!cidExists[cid], "CID already recorded");
        require(amountPaid > 0, "Amount must be greater than 0");
        
        receiptId = receiptCount;
        receiptCount++;
        
        receipts[receiptId] = Receipt({
            buyer: buyer,
            productId: productId,
            cid: cid,
            paymentToken: paymentToken,
            amountPaid: amountPaid,
            currency: currency,
            timestamp: block.timestamp
        });
        
        cidExists[cid] = true;
        buyerReceipts[buyer].push(receiptId);
        
        emit ReceiptRecorded(
            receiptId,
            buyer,
            productId,
            cid,
            paymentToken,
            amountPaid,
            currency,
            block.timestamp
        );
        
        return receiptId;
    }
    
    /**
     * @notice Retrieves a receipt by ID
     * @param receiptId The ID of the receipt to retrieve
     * @return Receipt struct containing all receipt data
     */
    function getReceipt(uint256 receiptId) external view returns (Receipt memory) {
        require(receiptId < receiptCount, "Receipt does not exist");
        return receipts[receiptId];
    }
    
    /**
     * @notice Gets all receipt IDs for a specific buyer
     * @param buyer Address of the buyer
     * @return Array of receipt IDs
     */
    function getReceiptsByBuyer(address buyer) external view returns (uint256[] memory) {
        return buyerReceipts[buyer];
    }
    
    /**
     * @notice Checks if a CID has been recorded
     * @param cid The CID to check
     * @return bool indicating if the CID exists
     */
    function isCIDRecorded(string memory cid) external view returns (bool) {
        return cidExists[cid];
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
}

