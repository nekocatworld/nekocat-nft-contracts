// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title INekoCatNFT
 * @dev Interface for NekoCat NFT contract
 */
interface INekoCatNFT {
    enum CharacterType {
        Geisha,
        Ninja,
        Samurai,
        Sumo
    }

    struct CatMetadata {
        CharacterType characterType;
        uint8 variant;
        uint8 level;
        uint256 mintTimestamp;
        uint16 totalFeeds; // Total lifetime feeds for XP tracking
    }

    struct CatState {
        bool isAlive;
        bool isImmortal;
        uint8 livesRemaining;
        uint256 lastFedTimestamp;
        uint8 reviveCount;
    }

    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);

    // Commit-reveal random functions
    function commitRandom(bytes32 commitHash) external;
    function canReveal(address user) external view returns (bool);

    // Minting functions
    function mintCat(
        uint256 nonce,
        bytes32 randomSecret
    ) external payable returns (uint256);
    
    function mintCatSimple() external payable returns (uint256);

    // Feeding functions
    function feedCatWithFoodNFT(uint256 catTokenId, uint16 xpGain) external;

    // Death and revival functions
    function checkDeath(uint256 tokenId) external;
    function reviveCat(uint256 tokenId) external payable;
    function batchReviveCats(uint256[] calldata tokenIds) external payable;

    // Immortality functions
    function useImmortality(uint256 tokenId) external;
    function syncImmortality(address user) external;

    // View functions
    function getCatInfo(
        uint256 tokenId
    )
        external
        view
        returns (
            CatMetadata memory metadata,
            CatState memory state,
            bool isDead,
            uint256 timeUntilDeath
        );
    function getCatMetadata(
        uint256 tokenId
    ) external view returns (CatMetadata memory);
    function getCatState(
        uint256 tokenId
    ) external view returns (CatState memory);
    function canFeedCat(uint256 tokenId) external view returns (bool);

    function getMintStats()
        external
        view
        returns (
            uint256 totalMinted,
            uint256 ninjaCount,
            uint256 sumoCount,
            uint256 samuraiCount,
            uint256 geishaCount,
            uint256 remaining
        );
    function getMintPrice() external view returns (uint256);
    function getXPRequirements() external pure returns (uint16[7] memory);

    // Bulk view functions
    function getMultipleCatsInfo(
        uint256[] calldata tokenIds
    )
        external
        view
        returns (
            CatMetadata[] memory metadataArray,
            CatState[] memory stateArray,
            bool[] memory isDeadArray,
            uint256[] memory timeUntilDeathArray
        );
    function getUserAllCats(
        address user
    ) external view returns (uint256[] memory tokenIds);
    function getMultipleFeedingStatus(
        uint256[] calldata tokenIds
    )
        external
        view
        returns (
            bool[] memory isAliveArray,
            uint256[] memory lastFedArray,
            bool[] memory canFeedArray
        );

    // Immortality view functions
    function canUseImmortality(address holder) external view returns (bool);
    function getUserImmortalNFTs(address holder) external view returns (uint256[] memory);
    function isNFTImmortal(uint256 tokenId) external view returns (bool);

    // Admin functions
    function stakingContract() external view returns (address);
    function immortalityThreshold() external view returns (uint256);
    function setImmortalityThreshold(uint256 _threshold) external;
    function setStakingContract(address _stakingContract) external;
    function setDepositManager(address _depositManager) external;
    function setFoodMenu(address _foodMenu) external;
    function setFoodNFTContract(address _foodNFTContract) external;

    // Emergency functions
    function pause() external;
    function unpause() external;
    function withdraw(uint256 amount) external;

    // Internal helper (for batch operations)
    function processSingleFeed(uint256 tokenId) external;

    // Utility functions
    function getLevelProgress(
        uint256 tokenId
    ) external view returns (uint256 currentXP, uint256 requiredXP);
    function getXPRequiredForNextLevel(
        uint256 tokenId
    ) external view returns (uint256);
    function getRarityScore(uint256 tokenId) external view returns (uint256);
    function getTimeUntilNextFeed(
        uint256 tokenId
    ) external view returns (uint256);
}
