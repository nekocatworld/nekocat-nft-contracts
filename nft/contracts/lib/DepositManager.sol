// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IDepositManager.sol";
import "./DepositConstants.sol";
import "./DepositErrors.sol";
import "../interfaces/INekoTreasury.sol";

/**
 * @title DepositManager
 * @dev Manages all payment deposits and distributions for NekoCat NFT system
 * @notice Separates payment logic from NFT logic for better modularity
 */
contract DepositManager is IDepositManager, Ownable, ReentrancyGuard {
    // ============ State Variables ============

    address public treasuryContract; // Treasury contract for fund management
    address public nftContract;
    address public foodContract;

    // Price configuration
    uint256 public constant MINT_PRICE_ETH = DepositConstants.MINT_PRICE_ETH;
    uint256 public feedingCostETH = 0.0000025 ether; // 0.0000025 ETH per feed
    uint256 public baseRevivalCostETH =
        DepositConstants.DEFAULT_BASE_REVIVAL_COST_ETH;
    uint256 public revivalMultiplier =
        DepositConstants.DEFAULT_REVIVAL_MULTIPLIER;

    // Statistics
    uint256 public totalMintRevenue;
    uint256 public totalFeedingRevenue;
    uint256 public totalRevivalRevenue;
    uint256 public totalFoodRevenue;

    // ============ Events ============
    event TreasuryContractUpdated(
        address indexed oldTreasury,
        address indexed newTreasury
    );
    event RevivalCostUpdated(uint256 newCostETH);
    event RevivalMultiplierUpdated(uint256 newMultiplier);
    event FeedingCostUpdated(uint256 newCostETH);
    event MintPaymentProcessed(address indexed user, uint256 amount);
    event FeedingPaymentProcessed(
        address indexed user,
        uint256[] tokenIds,
        uint256 amount
    );
    event RevivalPaymentProcessed(
        address indexed user,
        uint256 tokenId,
        uint256 amount
    );
    event FoodPaymentProcessed(address indexed user, uint256 amount);

    // ============ Constructor ============

    constructor(address _treasuryContract) Ownable(msg.sender) {
        if (_treasuryContract == address(0))
            revert DepositErrors.InvalidAddress();
        treasuryContract = _treasuryContract;
    }

    // ============ Payment Processing Functions ============

    /**
     * @dev Process mint payment
     */
    function processMintPayment(
        address user,
        uint256 amount
    ) external payable override nonReentrant {
        require(msg.sender == nftContract, "Only NFT contract");
        require(amount >= getMintPrice(), "Amount too low");

        totalMintRevenue += amount;

        // Forward payment to treasury
        if (amount > 0) {
            (bool success, ) = treasuryContract.call{value: amount}("");
            require(success, "Treasury transfer failed");
        }

        emit MintPaymentProcessed(user, amount);
    }

    /**
     * @dev Process feeding payment (now free - food only)
     */
    function processFeedingPayment(
        address user,
        uint256[] calldata tokenIds,
        uint256 amount
    ) external payable override nonReentrant {
        require(msg.sender == nftContract, "Only NFT contract");
        uint256 requiredAmount = getFeedingCost() * tokenIds.length;
        require(amount >= requiredAmount, "Amount too low");

        totalFeedingRevenue += amount;

        // Forward payment to treasury (if any)
        if (amount > 0) {
            (bool success, ) = treasuryContract.call{value: amount}("");
            require(success, "Treasury transfer failed");
        }

        emit FeedingPaymentProcessed(user, tokenIds, amount);
    }

    /**
     * @dev Process revival payment
     */
    function processRevivalPayment(
        address user,
        uint256 tokenId,
        uint8 reviveCount,
        uint256 amount
    ) external payable override nonReentrant {
        require(msg.sender == nftContract, "Only NFT contract");
        uint256 requiredCost = getRevivalCost(reviveCount);
        require(amount >= requiredCost, "Amount too low");

        totalRevivalRevenue += amount;

        // Forward payment to treasury
        if (amount > 0) {
            (bool success, ) = treasuryContract.call{value: amount}("");
            require(success, "Treasury transfer failed");
        }

        emit RevivalPaymentProcessed(user, tokenId, amount);
    }

    /**
     * @dev Process food payment
     */
    function processFoodPayment(
        address user,
        uint256 amount
    ) external payable override nonReentrant {
        require(msg.sender == foodContract, "Only food contract");

        totalFoodRevenue += amount;

        // Forward payment to treasury
        if (amount > 0) {
            (bool success, ) = treasuryContract.call{value: amount}("");
            require(success, "Treasury transfer failed");
        }

        emit FoodPaymentProcessed(user, amount);
    }

    // ============ Price Calculation Functions ============

    /**
     * @dev Get mint price in ETH
     * @return uint256 Price in ETH
     */
    function getMintPrice() public view override returns (uint256) {
        return MINT_PRICE_ETH;
    }

    /**
     * @dev Get mint cost in native token (ETH)
     * @return uint256 Cost in native token
     */
    function getMintCost() public view override returns (uint256) {
        return getMintPrice();
    }

    /**
     * @dev Get feeding cost per NFT in ETH
     * @return uint256 Cost in ETH (0.0000025 ETH)
     */
    function getFeedingCost() public view override returns (uint256) {
        return feedingCostETH;
    }

    /**
     * @dev Calculate revival cost based on number of revivals
     */
    function getRevivalCost(
        uint8 reviveCount
    ) public view override returns (uint256) {
        uint256 costETH = baseRevivalCostETH;

        // Apply multiplier for each revival (e.g., 1.5x each time)
        for (uint8 i = 0; i < reviveCount; i++) {
            costETH = (costETH * revivalMultiplier) / 100;
        }

        return costETH;
    }

    // ============ Admin Functions ============

    /**
     * @dev Set NFT contract address (one-time setup)
     */
    function setNFTContract(address _nftContract) external onlyOwner {
        if (_nftContract == address(0)) revert DepositErrors.InvalidAddress();
        require(nftContract == address(0), "Already set");
        nftContract = _nftContract;
    }

    /**
     * @dev Set the food contract address (can only be set once)
     */
    function setFoodContract(address _foodContract) external onlyOwner {
        if (_foodContract == address(0)) revert DepositErrors.InvalidAddress();
        require(foodContract == address(0), "Already set");
        foodContract = _foodContract;
    }

    /**
     * @dev Update treasury contract address
     */
    function updateTreasuryContract(
        address newTreasuryContract
    ) external onlyOwner {
        if (newTreasuryContract == address(0))
            revert DepositErrors.InvalidAddress();
        address oldTreasuryContract = treasuryContract;
        treasuryContract = newTreasuryContract;
        emit TreasuryContractUpdated(oldTreasuryContract, newTreasuryContract);
    }

    /**
     * @dev Update base revival cost in ETH (18 decimals)
     * @param newCostETH New base cost in ETH (e.g., 0.00075e18 for 0.00075 ETH)
     */
    function updateBaseRevivalCost(uint256 newCostETH) external onlyOwner {
        require(newCostETH > 0, "Revival cost must be > 0");
        baseRevivalCostETH = newCostETH;
        emit RevivalCostUpdated(newCostETH);
    }

    /**
     * @dev Update revival multiplier (percentage with 2 decimals)
     * @param newMultiplier New multiplier (e.g., 150 = 1.5x, 200 = 2x, 120 = 1.2x)
     */
    function updateRevivalMultiplier(uint256 newMultiplier) external onlyOwner {
        require(newMultiplier >= 100, "Multiplier must be >= 100 (1.0x)");
        require(newMultiplier <= 300, "Multiplier must be <= 300 (3.0x)");
        revivalMultiplier = newMultiplier;
        emit RevivalMultiplierUpdated(newMultiplier);
    }

    /**
     * @dev Update feeding cost (admin only)
     * @param newCostETH New feeding cost in ETH
     */
    function updateFeedingCost(uint256 newCostETH) external onlyOwner {
        require(newCostETH >= 0, "Feeding cost must be >= 0");
        feedingCostETH = newCostETH;
        emit FeedingCostUpdated(newCostETH);
    }

    /**
     * @dev Emergency withdraw (only if funds stuck)
     */
    function emergencyWithdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdraw failed");
    }

    // ============ View Functions ============

    /**
     * @dev Get current pricing configuration
     * @return mintPriceETH Current mint price in ETH
     * @return baseRevivalCostETH_ Current revival cost in ETH
     * @return revivalMultiplier_ Current revival multiplier
     */
    function getPricingConfig()
        external
        view
        returns (
            uint256 mintPriceETH,
            uint256 baseRevivalCostETH_,
            uint256 revivalMultiplier_
        )
    {
        return (MINT_PRICE_ETH, baseRevivalCostETH, revivalMultiplier);
    }

    /**
     * @dev Get revenue statistics
     * @return mintRevenue Total mint revenue
     * @return feedingRevenue Total feeding revenue
     * @return revivalRevenue Total revival revenue
     * @return foodRevenue Total food revenue
     */
    function getRevenueStats()
        external
        view
        returns (
            uint256 mintRevenue,
            uint256 feedingRevenue,
            uint256 revivalRevenue,
            uint256 foodRevenue
        )
    {
        return (
            totalMintRevenue,
            totalFeedingRevenue,
            totalRevivalRevenue,
            totalFoodRevenue
        );
    }

    /**
     * @dev Get contract addresses
     * @return treasury Current treasury address
     * @return nft Current NFT contract address
     * @return food Current food contract address
     */
    function getContractAddresses()
        external
        view
        returns (address treasury, address nft, address food)
    {
        return (treasuryContract, nftContract, foodContract);
    }

    // ============ Receive Function ============

    receive() external payable {
        // Allow direct ETH deposits to treasury
        if (msg.value > 0) {
            (bool success, ) = treasuryContract.call{value: msg.value}("");
            require(success, "Treasury transfer failed");
        }
    }
}
