// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./NekoCatConstants.sol";
import "../interfaces/INekoCatNFT.sol";

/**
 * @title NekoCatHelpers
 * @dev Helper functions for NekoCat NFT operations
 * @notice Contains only the utility functions actually used in the contract
 */
library NekoCatHelpers {
    // =============================================================================
    // LEVEL CALCULATION FUNCTIONS
    // =============================================================================

    /**
     * @dev Calculate level based on total feeds (XP)
     * @param totalFeeds Total number of feeds (XP points)
     * @return level Current level (0-6)
     */
    function calculateLevel(
        uint16 totalFeeds
    ) internal pure returns (uint8 level) {
        if (totalFeeds >= NekoCatConstants.LEVEL_6_XP) return 6;
        if (totalFeeds >= NekoCatConstants.LEVEL_5_XP) return 5;
        if (totalFeeds >= NekoCatConstants.LEVEL_4_XP) return 4;
        if (totalFeeds >= NekoCatConstants.LEVEL_3_XP) return 3;
        if (totalFeeds >= NekoCatConstants.LEVEL_2_XP) return 2;
        if (totalFeeds >= NekoCatConstants.LEVEL_1_XP) return 1;
        return 0;
    }

    // =============================================================================
    // TIME CALCULATION FUNCTIONS
    // =============================================================================

    /**
     * @dev Calculate time until death
     * @param lastFedTimestamp Last feeding timestamp
     * @return timeUntilDeath Time in seconds until death (0 if already dead)
     */
    function calculateTimeUntilDeath(
        uint256 lastFedTimestamp
    ) internal view returns (uint256 timeUntilDeath) {
        uint256 timeSinceLastFeed = block.timestamp - lastFedTimestamp;

        if (timeSinceLastFeed >= NekoCatConstants.DEATH_TIMER) {
            return 0; // Already dead
        }

        return NekoCatConstants.DEATH_TIMER - timeSinceLastFeed;
    }

    /**
     * @dev Check if cat is dead based on feeding time
     * @param lastFedTimestamp Last feeding timestamp
     * @return isDead True if cat is dead
     */
    function isCatDead(
        uint256 lastFedTimestamp
    ) internal view returns (bool isDead) {
        uint256 timeSinceLastFeed = block.timestamp - lastFedTimestamp;
        return timeSinceLastFeed >= NekoCatConstants.DEATH_TIMER;
    }

    // =============================================================================
    // CREDIT SCORE CALCULATION FUNCTIONS
    // =============================================================================

    /**
     * @dev Calculate cat credit score
     * @param level Cat level
     * @param totalFeeds Total feeds
     * @param reviveCount Number of revives
     * @param isImmortal Whether cat is immortal
     * @return score Credit score
     */
    function calculateCreditScore(
        uint8 level,
        uint256 totalFeeds,
        uint256 reviveCount,
        bool isImmortal
    ) internal pure returns (uint256 score) {
        // Base score from level
        score += level * 100;

        // Bonus for total feeds
        score += totalFeeds * 10;

        // Bonus for revive count (resilience)
        score += reviveCount * 50;

        // Immortality bonus
        if (isImmortal) {
            score += 1000;
        }

        return score;
    }

    // =============================================================================
    // RANDOM GENERATION FUNCTIONS
    // =============================================================================

    /**
     * @dev Generate character type from random seed
     * @param randomSeed Random seed
     * @param nonce Additional nonce for randomness
     * @return characterType Generated character type (0-3)
     */
    function generateCharacterType(
        bytes32 randomSeed,
        uint256 nonce
    ) internal pure returns (uint8 characterType) {
        return
            uint8(
                uint256(
                    keccak256(abi.encodePacked(randomSeed, nonce, "character"))
                ) % NekoCatConstants.CHARACTER_TYPES
            );
    }

    /**
     * @dev Generate variant from random seed
     * @param randomSeed Random seed
     * @param nonce Additional nonce for randomness
     * @return variant Generated variant (1-5)
     */
    function generateVariant(
        bytes32 randomSeed,
        uint256 nonce
    ) internal pure returns (uint8 variant) {
        return
            uint8(
                uint256(
                    keccak256(abi.encodePacked(randomSeed, nonce, "variant"))
                ) % NekoCatConstants.VARIANTS_PER_TYPE
            ) + 1;
    }

    // =============================================================================
    // RARITY CALCULATION FUNCTIONS
    // =============================================================================

    /**
     * @dev Calculate rarity score for a cat
     * @param metadata Cat metadata
     * @param state Cat state
     * @param variantSupplyCount Current supply of this variant for this character type
     * @param characterTypeSupply Total supply of this character type
     */
    function calculateRarityScore(
        INekoCatNFT.CatMetadata memory metadata,
        INekoCatNFT.CatState memory state,
        uint256 variantSupplyCount,
        uint256 characterTypeSupply
    ) internal pure returns (uint256 rarity) {
        // Character type rarity (Geisha > Samurai > Sumo > Ninja)
        if (metadata.characterType == INekoCatNFT.CharacterType.Geisha)
            rarity += 100;
        else if (metadata.characterType == INekoCatNFT.CharacterType.Samurai)
            rarity += 75;
        else if (metadata.characterType == INekoCatNFT.CharacterType.Sumo)
            rarity += 50;
        else rarity += 25;

        // Variant rarity based on supply (lower supply = higher rarity)
        // Use inverse supply ratio: rarity = baseScore * (totalSupply / variantSupply)
        // Minimum variant supply is 1 to avoid division by zero
        if (variantSupplyCount == 0) variantSupplyCount = 1;
        if (characterTypeSupply == 0) characterTypeSupply = 1;
        
        // Base variant score (1-5 → 10-50)
        uint256 baseVariantScore = metadata.variant * 10;
        
        // Supply-based multiplier: (characterTypeSupply / variantSupplyCount)
        // More rare variants get higher multiplier
        // Use simpler calculation to save gas
        uint256 supplyMultiplier;
        if (variantSupplyCount == 0) {
            supplyMultiplier = 10; // Max multiplier if no supply yet
        } else {
            supplyMultiplier = characterTypeSupply / variantSupplyCount;
            // Cap multiplier to prevent extreme values (max 10x)
            if (supplyMultiplier > 10) supplyMultiplier = 10;
            if (supplyMultiplier == 0) supplyMultiplier = 1; // Minimum 1x
        }
        
        // Calculate variant rarity: base score * supply multiplier
        uint256 variantRarity = (baseVariantScore * supplyMultiplier) / 10; // Divide by 10 to normalize
        rarity += variantRarity;

        // Level bonus
        rarity += metadata.level * 20;

        // Immortality bonus
        if (state.isImmortal) rarity += 200;

        return rarity;
    }

    // =============================================================================
    // STRING CONVERSION FUNCTIONS
    // =============================================================================

    /**
     * @dev Get character type as string
     */
    function getCharacterTypeString(
        INekoCatNFT.CharacterType characterType
    ) internal pure returns (string memory) {
        if (characterType == INekoCatNFT.CharacterType.Ninja) return "Ninja";
        else if (characterType == INekoCatNFT.CharacterType.Sumo) return "Sumo";
        else if (characterType == INekoCatNFT.CharacterType.Samurai)
            return "Samurai";
        else if (characterType == INekoCatNFT.CharacterType.Geisha)
            return "Geisha";
        else return "Unknown";
    }

    /**
     * @dev Get level as string
     */
    function getLevelString(uint8 level) internal pure returns (string memory) {
        if (level == 0) return "Kitten";
        else if (level == 1) return "Young";
        else if (level == 2) return "Adult";
        else if (level == 3) return "Mature";
        else if (level == 4) return "Elder";
        else if (level == 5) return "Master";
        else if (level == 6) return "Legend";
        else return "Unknown";
    }

    // =============================================================================
    // XP CALCULATION FUNCTIONS
    // =============================================================================

    /**
     * @dev Get XP required for next level
     * @param currentLevel Current level of the cat
     * @return requiredXP XP required for next level (0 if max level)
     */
    function getXPRequiredForNextLevel(
        uint8 currentLevel
    ) internal pure returns (uint256 requiredXP) {
        if (currentLevel >= 6) {
            return 0; // Max level reached
        }

        // Get XP requirements for next level
        if (currentLevel == 0) return NekoCatConstants.LEVEL_1_XP;
        else if (currentLevel == 1) return NekoCatConstants.LEVEL_2_XP;
        else if (currentLevel == 2) return NekoCatConstants.LEVEL_3_XP;
        else if (currentLevel == 3) return NekoCatConstants.LEVEL_4_XP;
        else if (currentLevel == 4) return NekoCatConstants.LEVEL_5_XP;
        else if (currentLevel == 5) return NekoCatConstants.LEVEL_6_XP;

        return 0;
    }

    /**
     * @dev Get level progress (current XP and required XP for next level)
     * @param totalFeeds Total feeds (current XP)
     * @param currentLevel Current level
     * @return currentXP Current XP (total feeds)
     * @return requiredXP Required XP for next level
     */
    function getLevelProgress(
        uint16 totalFeeds,
        uint8 currentLevel
    ) internal pure returns (uint256 currentXP, uint256 requiredXP) {
        if (currentLevel >= 6) {
            return (totalFeeds, totalFeeds); // Max level
        }

        // Get XP requirements for next level
        requiredXP = getXPRequiredForNextLevel(currentLevel);
        currentXP = totalFeeds;
    }

    /**
     * @dev Get XP requirements for each level
     * @return requirements Array of XP requirements [0, LEVEL_1, LEVEL_2, ..., LEVEL_6]
     */
    function getXPRequirements()
        internal
        pure
        returns (uint16[7] memory requirements)
    {
        return
            [
                uint16(0),
                NekoCatConstants.LEVEL_1_XP,
                NekoCatConstants.LEVEL_2_XP,
                NekoCatConstants.LEVEL_3_XP,
                NekoCatConstants.LEVEL_4_XP,
                NekoCatConstants.LEVEL_5_XP,
                NekoCatConstants.LEVEL_6_XP
            ];
    }

    // =============================================================================
    // FEEDING CALCULATION FUNCTIONS
    // =============================================================================

    /**
     * @dev Check if cat can be fed
     * @param isAlive Whether cat is alive
     * @param lastFedTimestamp Last feeding timestamp
     * @return canFeed True if cat can be fed
     */
    function canFeedCat(
        bool isAlive,
        uint256 lastFedTimestamp
    ) internal view returns (bool canFeed) {
        return isAlive && block.timestamp >= lastFedTimestamp + 1 hours;
    }

    /**
     * @dev Get time until next feed is allowed
     * @param isAlive Whether cat is alive
     * @param lastFedTimestamp Last feeding timestamp
     * @return timeUntilNextFeed Time in seconds until next feed (0 if can feed now or dead)
     */
    function getTimeUntilNextFeed(
        bool isAlive,
        uint256 lastFedTimestamp
    ) internal view returns (uint256 timeUntilNextFeed) {
        if (!isAlive) {
            return 0; // Dead cats can't be fed
        }

        uint256 nextFeedTime = lastFedTimestamp + 1 hours;
        if (block.timestamp >= nextFeedTime) {
            return 0; // Can feed now
        }

        return nextFeedTime - block.timestamp;
    }

    /**
     * @dev Calculate cat info helper (time until death)
     * @param isAlive Whether cat is alive
     * @param lastFedTimestamp Last feeding timestamp
     * @return isDead Whether cat is dead
     * @return timeUntilDeath Time until death (0 if dead)
     */
    function calculateCatInfo(
        bool isAlive,
        uint256 lastFedTimestamp
    ) internal view returns (bool isDead, uint256 timeUntilDeath) {
        isDead = !isAlive;
        if (isAlive) {
            timeUntilDeath = calculateTimeUntilDeath(lastFedTimestamp);
        } else {
            timeUntilDeath = 0;
        }
    }

    // =============================================================================
    // BULK OPERATION HELPERS
    // =============================================================================

    /**
     * @dev Calculate multiple cat infos (batch operation helper)
     * @param isAliveArray Array of isAlive flags
     * @param lastFedTimestampArray Array of last fed timestamps
     * @return isDeadArray Array of isDead flags
     * @return timeUntilDeathArray Array of time until death values
     */
    function calculateMultipleCatInfos(
        bool[] memory isAliveArray,
        uint256[] memory lastFedTimestampArray
    ) internal view returns (bool[] memory isDeadArray, uint256[] memory timeUntilDeathArray) {
        uint256 length = isAliveArray.length;
        isDeadArray = new bool[](length);
        timeUntilDeathArray = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            (isDeadArray[i], timeUntilDeathArray[i]) = calculateCatInfo(
                isAliveArray[i],
                lastFedTimestampArray[i]
            );
        }
    }

    /**
     * @dev Calculate multiple feeding statuses (batch operation helper)
     * @param isAliveArray Array of isAlive flags
     * @param lastFedTimestampArray Array of last fed timestamps
     * @return canFeedArray Array of canFeed flags
     */
    function calculateMultipleFeedingStatuses(
        bool[] memory isAliveArray,
        uint256[] memory lastFedTimestampArray
    ) internal view returns (bool[] memory canFeedArray) {
        uint256 length = isAliveArray.length;
        canFeedArray = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            canFeedArray[i] = canFeedCat(isAliveArray[i], lastFedTimestampArray[i]);
        }
    }

    // =============================================================================
    // IMMORTALITY HELPERS
    // =============================================================================

    /**
     * @dev Calculate max immortal NFTs based on staked amount
     * @param stakedAmount Amount of tokens staked
     * @param threshold Threshold per immortal NFT
     * @return maxImmortalNFTs Maximum number of immortal NFTs allowed
     */
    function calculateMaxImmortalNFTs(
        uint256 stakedAmount,
        uint256 threshold
    ) internal pure returns (uint256 maxImmortalNFTs) {
        return stakedAmount / threshold;
    }

    /**
     * @dev Check if user can use immortality
     * @param currentImmortalCount Current number of immortal NFTs
     * @param stakedAmount Amount of tokens staked  
     * @param threshold Threshold per immortal NFT
     * @return canUse True if user can immortalize another NFT
     */
    function canUseImmortalityHelper(
        uint256 currentImmortalCount,
        uint256 stakedAmount,
        uint256 threshold
    ) internal pure returns (bool canUse) {
        uint256 maxImmortalNFTs = calculateMaxImmortalNFTs(stakedAmount, threshold);
        return currentImmortalCount < maxImmortalNFTs;
    }
}
