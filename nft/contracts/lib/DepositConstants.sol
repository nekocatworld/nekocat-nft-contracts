// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DepositConstants
 * @dev Shared constants for DepositManager pricing configuration
 */
library DepositConstants {
    // ============ Price Configuration ============

    // Fixed mint price in ETH (18 decimals)
    uint256 constant MINT_PRICE_ETH = 0.0075e18; // 0.0075 ETH

    // Default revival base cost in ETH (18 decimals) - admin can change
    uint256 constant DEFAULT_BASE_REVIVAL_COST_ETH = 0.00075e18; // 0.00075 ETH

    // Default revival multiplier (percentage, 100 = 1.0x) - admin can change
    uint256 constant DEFAULT_REVIVAL_MULTIPLIER = 150; // 1.5x

    // Revival multiplier constraints
    uint256 constant MIN_REVIVAL_MULTIPLIER = 100; // 1.0x (no increase)
    uint256 constant MAX_REVIVAL_MULTIPLIER = 300; // 3.0x (triple each time)

    // ============ Revenue Split ============

    // Treasury takes 90% of all payments
    uint256 constant TREASURY_PERCENTAGE = 90;

    // Reward pool takes 10% of feeding payments only
    uint256 constant REWARD_POOL_PERCENTAGE = 10;

    // Denominator for percentage calculations
    uint256 constant PERCENTAGE_DENOMINATOR = 100;
}
