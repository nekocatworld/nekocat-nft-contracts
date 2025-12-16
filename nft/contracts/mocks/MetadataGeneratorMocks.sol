// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/MetadataGenerator.sol";
import "../interfaces/INekoCatNFT.sol";

contract TestMetadataGenerator {
    using MetadataGenerator for *;

    // Character type helpers
    function testGetCharacterTypeName(
        uint8 characterType
    ) external pure returns (string memory) {
        return
            MetadataGenerator.getCharacterTypeName(
                INekoCatNFT.CharacterType(characterType)
            );
    }

    function testGetCharacterFolder(
        uint8 characterType
    ) external pure returns (string memory) {
        return
            MetadataGenerator.getCharacterFolder(
                INekoCatNFT.CharacterType(characterType)
            );
    }

    // Level helpers
    function testCalculateLevel(
        uint16 totalFeeds
    ) external pure returns (uint8) {
        return MetadataGenerator.calculateLevel(totalFeeds);
    }

    function testGetLevelName(
        uint8 level
    ) external pure returns (string memory) {
        return MetadataGenerator.getLevelName(level);
    }

    // Image path generation
    function testBuildImagePath(
        uint8 characterType,
        uint8 variant,
        uint8 level
    ) external pure returns (string memory) {
        return
            MetadataGenerator.buildImagePath(
                INekoCatNFT.CharacterType(characterType),
                variant,
                level
            );
    }

    // Metadata JSON generation
    function testGenerateMetadataJson(
        uint256 tokenId,
        INekoCatNFT.CatMetadata memory metadata,
        INekoCatNFT.CatState memory state,
        uint8 currentLevel,
        string memory imagePath
    ) external pure returns (string memory) {
        return
            MetadataGenerator.generateMetadataJson(
                tokenId,
                metadata,
                state,
                currentLevel,
                imagePath
            );
    }

    // Base64 encoding
    function testBase64Encode(
        string memory data
    ) external pure returns (string memory) {
        return MetadataGenerator.base64Encode(bytes(data));
    }

    // Complete token URI generation
    function testGenerateTokenURI(
        string memory baseURI,
        uint256 tokenId,
        INekoCatNFT.CatMetadata memory metadata,
        INekoCatNFT.CatState memory state
    ) external pure returns (string memory) {
        return MetadataGenerator.generateTokenURI(baseURI, tokenId, metadata, state);
    }
}
