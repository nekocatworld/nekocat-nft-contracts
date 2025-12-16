// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./NekoCatConstants.sol";
import "../interfaces/INekoCatNFT.sol";

/**
 * @title MetadataGenerator
 * @dev Library for generating dynamic NFT metadata based on current state
 */
library MetadataGenerator {
    using Strings for uint256;

    // ============ CHARACTER TYPE HELPERS ============

    /**
     * @dev Get character type name as string
     */
    function getCharacterTypeName(
        INekoCatNFT.CharacterType characterType
    ) internal pure returns (string memory) {
        if (characterType == INekoCatNFT.CharacterType.Geisha) return "Geisha";
        if (characterType == INekoCatNFT.CharacterType.Ninja) return "Ninja";
        if (characterType == INekoCatNFT.CharacterType.Samurai)
            return "Samurai";
        if (characterType == INekoCatNFT.CharacterType.Sumo) return "Sumo";
        return "Unknown";
    }

    /**
     * @dev Get character type folder name
     */
    function getCharacterFolder(
        INekoCatNFT.CharacterType characterType
    ) internal pure returns (string memory) {
        if (characterType == INekoCatNFT.CharacterType.Geisha) return "geisha";
        if (characterType == INekoCatNFT.CharacterType.Ninja) return "ninja";
        if (characterType == INekoCatNFT.CharacterType.Samurai)
            return "samuray";
        if (characterType == INekoCatNFT.CharacterType.Sumo) return "sumo";
        return "unknown";
    }

    // ============ LEVEL HELPERS ============

    /**
     * @dev Calculate current level based on total feeds
     */
    function calculateLevel(uint16 totalFeeds) internal pure returns (uint8) {
        if (totalFeeds >= NekoCatConstants.LEVEL_6_XP) return 6;
        if (totalFeeds >= NekoCatConstants.LEVEL_5_XP) return 5;
        if (totalFeeds >= NekoCatConstants.LEVEL_4_XP) return 4;
        if (totalFeeds >= NekoCatConstants.LEVEL_3_XP) return 3;
        if (totalFeeds >= NekoCatConstants.LEVEL_2_XP) return 2;
        if (totalFeeds >= NekoCatConstants.LEVEL_1_XP) return 1;
        return 0;
    }

    /**
     * @dev Get level name as string
     */
    function getLevelName(uint8 level) internal pure returns (string memory) {
        if (level == 0) return "Kitten";
        if (level == 1) return "Apprentice";
        if (level == 2) return "Student";
        if (level == 3) return "Warrior";
        if (level == 4) return "Master";
        if (level == 5) return "Grandmaster";
        if (level == 6) return "Legend";
        return "Unknown";
    }

    // ============ IMAGE PATH GENERATION ============

    /**
     * @dev Build image path based on character type, variant, and level
     */
    function buildImagePath(
        INekoCatNFT.CharacterType characterType,
        uint8 variant,
        uint8 level
    ) internal pure returns (string memory) {
        string memory charFolder = getCharacterFolder(characterType);
        string memory charName = getCharacterFolder(characterType);

        return
            string(
                abi.encodePacked(
                    charFolder,
                    Strings.toString(uint256(variant)),
                    "/neko-cat-",
                    charName,
                    "-t",
                    Strings.toString(uint256(variant)),
                    "-l",
                    Strings.toString(uint256(level)),
                    ".jpg"
                )
            );
    }

    // ============ METADATA JSON GENERATION ============

    /**
     * @dev Generate complete metadata JSON string
     */
    function generateMetadataJson(
        uint256 tokenId,
        INekoCatNFT.CatMetadata memory metadata,
        INekoCatNFT.CatState memory state,
        uint8 currentLevel,
        string memory imagePath
    ) internal pure returns (string memory) {
        string memory charName = getCharacterTypeName(metadata.characterType);
        string memory levelName = getLevelName(currentLevel);

        return
            string(
                abi.encodePacked(
                    '{"name":"NekoCat #',
                    tokenId.toString(),
                    '","description":"A ',
                    charName,
                    " cat that has reached the ",
                    levelName,
                    " level with ",
                    Strings.toString(metadata.totalFeeds),
                    ' total feeds.","image":"',
                    imagePath,
                    '","attributes":[{"trait_type":"Character Type","value":"',
                    charName,
                    '"},{"trait_type":"Variant","value":',
                    Strings.toString(uint256(metadata.variant)),
                    '},{"trait_type":"Level","value":',
                    Strings.toString(currentLevel),
                    '},{"trait_type":"Level Name","value":"',
                    levelName,
                    '"},{"trait_type":"Total Feeds","value":',
                    Strings.toString(metadata.totalFeeds),
                    '},{"trait_type":"Lives Remaining","value":',
                    Strings.toString(uint256(state.livesRemaining)),
                    '},{"trait_type":"Is Alive","value":',
                    state.isAlive ? "true" : "false",
                    '},{"trait_type":"Is Immortal","value":',
                    state.isImmortal ? "true" : "false",
                    "}]}"
                )
            );
    }

    // ============ BASE64 ENCODING ============

    /**
     * @dev Base64 encode function for metadata
     */
    function base64Encode(
        bytes memory data
    ) internal pure returns (string memory) {
        if (data.length == 0) return "";

        // Base64 alphabet
        bytes
            memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

        // Calculate output length
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // Create result string
        bytes memory result = new bytes(encodedLen);

        uint256 i = 0;
        uint256 j = 0;

        // Process 3-byte chunks
        while (i + 2 < data.length) {
            uint32 chunk = (uint32(uint8(data[i])) << 16) |
                (uint32(uint8(data[i + 1])) << 8) |
                uint32(uint8(data[i + 2]));

            result[j] = table[(chunk >> 18) & 0x3F];
            result[j + 1] = table[(chunk >> 12) & 0x3F];
            result[j + 2] = table[(chunk >> 6) & 0x3F];
            result[j + 3] = table[chunk & 0x3F];

            i += 3;
            j += 4;
        }

        // Handle remaining bytes
        if (i < data.length) {
            uint32 chunk = uint32(uint8(data[i])) << 16;
            if (i + 1 < data.length) {
                chunk |= uint32(uint8(data[i + 1])) << 8;
            }

            result[j] = table[(chunk >> 18) & 0x3F];
            result[j + 1] = table[(chunk >> 12) & 0x3F];

            if (i + 1 < data.length) {
                result[j + 2] = table[(chunk >> 6) & 0x3F];
                result[j + 3] = "=";
            } else {
                result[j + 2] = "=";
                result[j + 3] = "=";
            }
        }

        return string(result);
    }

    // ============ COMPLETE METADATA GENERATION ============

    /**
     * @dev Generate complete token URI with IPFS URL format
     * @param baseURI The base URI for metadata (e.g., "ipfs://QmHash/" or "https://api.example.com/metadata/")
     * @param tokenId The token ID
     * @return IPFS/HTTP URL pointing to metadata JSON file
     */
    function generateTokenURI(
        string memory baseURI,
        uint256 tokenId,
        INekoCatNFT.CatMetadata memory,
        INekoCatNFT.CatState memory
    ) internal pure returns (string memory) {
        // Return IPFS/HTTP URL format: baseURI + tokenId
        // Metadata JSON files should be hosted at these URLs
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }
}
