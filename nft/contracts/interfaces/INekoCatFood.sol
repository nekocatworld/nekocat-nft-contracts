// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title INekoCatFood
 * @dev Interface for NekoCat Food NFT contract
 */
interface INekoCatFood {
    function mintFood(uint256 foodTypeId) external payable returns (uint256);
    function batchMintFood(
        uint256 foodTypeId,
        uint256 amount
    ) external payable returns (uint256[] memory);
    function consumeFood(
        uint256 foodTokenId,
        uint256 catTokenId,
        uint8 characterType,
        uint8 timeSlot
    ) external returns (uint16);
    function getActiveFoodTypes() external view returns (uint256[] memory);
    function getUserFoodsByType(
        address user,
        uint256 foodTypeId
    ) external view returns (uint256[] memory);
    function calculateXP(
        uint256 foodTypeId,
        uint8 characterType,
        uint8 timeSlot
    ) external view returns (uint16);

    /**
     * @dev Batch update multiple food type prices
     * @param foodTypeIds Array of food type IDs to update
     * @param newPrices Array of new prices (must match foodTypeIds length)
     */
    function batchUpdateFoodPrices(
        uint256[] calldata foodTypeIds,
        uint256[] calldata newPrices
    ) external;
}
