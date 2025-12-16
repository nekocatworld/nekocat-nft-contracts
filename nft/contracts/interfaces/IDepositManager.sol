// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDepositManager
 * @dev Interface for payment deposit and distribution system
 * @notice Handles all payment logic for minting, feeding, and revivals
 */
interface IDepositManager {
    /**
     * @dev Process mint payment
     * @param user Address making the payment
     * @param amount Payment amount
     */
    function processMintPayment(address user, uint256 amount) external payable;

    /**
     * @dev Process feeding payment
     * @param user Address making the payment
     * @param tokenIds Array of token IDs being fed
     * @param amount Payment amount
     */
    function processFeedingPayment(
        address user,
        uint256[] calldata tokenIds,
        uint256 amount
    ) external payable;

    /**
     * @dev Process revival payment
     * @param user Address making the payment
     * @param tokenId Token ID being revived
     * @param reviveCount Number of times cat has been revived
     * @param amount Payment amount
     */
    function processRevivalPayment(
        address user,
        uint256 tokenId,
        uint8 reviveCount,
        uint256 amount
    ) external payable;

    /**
     * @dev Process food NFT payment
     * @param user Address making the payment
     * @param amount Payment amount
     */
    function processFoodPayment(address user, uint256 amount) external payable;

    /**
     * @dev Get mint price in ETH
     * @return uint256 Price in ETH
     */
    function getMintPrice() external view returns (uint256);

    /**
     * @dev Get mint cost in native token (ETH)
     * @return uint256 Cost in native token
     */
    function getMintCost() external view returns (uint256);

    /**
     * @dev Get feeding cost per NFT in ETH
     * @return uint256 Cost in ETH
     */
    function getFeedingCost() external view returns (uint256);

    /**
     * @dev Calculate revival cost based on number of revivals
     * @param reviveCount Number of times cat has been revived
     * @return uint256 Cost in ETH
     */
    function getRevivalCost(uint8 reviveCount) external view returns (uint256);

    /**
     * @dev Get current pricing configuration
     * @return mintPriceETH Current mint price in ETH
     * @return baseRevivalCostETH Current revival cost in ETH
     * @return revivalMultiplier Current revival multiplier
     */
    function getPricingConfig()
        external
        view
        returns (
            uint256 mintPriceETH,
            uint256 baseRevivalCostETH,
            uint256 revivalMultiplier
        );

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
        );

    /**
     * @dev Update base revival cost in ETH (18 decimals)
     * @param newCostETH New base cost in ETH
     */
    function updateBaseRevivalCost(uint256 newCostETH) external;

    /**
     * @dev Update revival multiplier (percentage with 2 decimals)
     * @param newMultiplier New multiplier (e.g., 150 = 1.5x, 200 = 2x, 120 = 1.2x)
     */
    function updateRevivalMultiplier(uint256 newMultiplier) external;

    /**
     * @dev Get contract addresses
     * @return treasury Current treasury address
     * @return nft Current NFT contract address
     * @return food Current food contract address
     */
    function getContractAddresses()
        external
        view
        returns (address treasury, address nft, address food);
}
