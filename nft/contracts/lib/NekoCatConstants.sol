// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NekoCatConstants
 * @dev Constants for NekoCat NFT system
 */
library NekoCatConstants {
    // ============ Supply Constants ============
    uint256 constant MAX_SUPPLY = 20000;
    uint8 constant CHARACTER_TYPES = 4;
    uint8 constant VARIANTS_PER_TYPE = 5;
    uint8 constant MAX_LEVEL = 6;

    // Character Type Supply Distribution
    uint256 constant NINJA_SUPPLY = 8000; // 40%
    uint256 constant SUMO_SUPPLY = 5000; // 25%
    uint256 constant SAMURAI_SUPPLY = 4000; // 20%
    uint256 constant GEISHA_SUPPLY = 3000; // 15%

    // ============ Life System Constants ============
    uint8 constant MAX_LIVES = 9;
    uint256 constant DEATH_TIMER = 48 hours; // Cat dies after 48 hours without feeding

    // ============ Leveling Constants (XP Based) ============
    // Total feeds required per level (cumulative) - 1 feed = 1 XP
    uint16 constant LEVEL_1_XP = 600; // 600 feeds for level 1 (Apprentice)
    uint16 constant LEVEL_2_XP = 1300; // +700 = 1300 total feeds for level 2 (Student)
    uint16 constant LEVEL_3_XP = 2500; // +1200 = 2500 total feeds for level 3 (Warrior)
    uint16 constant LEVEL_4_XP = 6000; // +3500 = 6000 total feeds for level 4 (Master)
    uint16 constant LEVEL_5_XP = 10500; // +4500 = 10500 total feeds for level 5 (Grandmaster)
    uint16 constant LEVEL_6_XP = 20000; // +9500 = 20000 total feeds for level 6 (Legend)
    // Total: 20000 feeds for max level (very challenging progression)

    // ============ Batch Operation Limits ============
    uint256 constant MAX_BATCH_SIZE = 50;
}
