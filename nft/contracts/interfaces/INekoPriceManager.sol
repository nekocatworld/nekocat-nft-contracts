// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title INekoPriceManager
 * @dev Interface for centralized price management across the NekoCat ecosystem
 * @notice Provides secure batch operations for updating ETH prices across all contracts
 */
interface INekoPriceManager {
    // =============================================================================
    // STRUCTS
    // =============================================================================

    struct PricingUpdate {
        uint256 baseRevivalCostETH;
        uint256 revivalMultiplier;
        uint256[] foodTypeIds;
        uint256[] foodPrices;
        uint256 timestamp;
        string reason;
    }

    // =============================================================================
    // MAIN FUNCTIONS
    // =============================================================================

    /**
     * @dev Update all ecosystem prices in a single transaction
     * @param pricingUpdate Struct containing all pricing information
     */
    function updateEcosystemPricing(
        PricingUpdate calldata pricingUpdate
    ) external;

    /**
     * @dev Toggle emergency mode
     * @param active Whether to activate or deactivate emergency mode
     * @param reason Reason for emergency mode change
     */
    function toggleEmergencyMode(bool active, string calldata reason) external;

    /**
     * @dev Pause price updates
     */
    function pausePriceUpdates() external;

    /**
     * @dev Unpause price updates
     */
    function unpausePriceUpdates() external;

    /**
     * @dev Update contract addresses
     * @param _depositManager New deposit manager address
     * @param _foodContract New food contract address
     */
    function updateContracts(
        address _depositManager,
        address _foodContract
    ) external;

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    /**
     * @dev Get current pricing status
     * @return isPaused Whether price updates are paused
     * @return isEmergencyMode Whether emergency mode is active
     * @return lastUpdateTime Timestamp of last update
     * @return nextUpdateAvailable Time when next update will be available
     */
    function getPricingStatus()
        external
        view
        returns (
            bool isPaused,
            bool isEmergencyMode,
            uint256 lastUpdateTime,
            uint256 nextUpdateAvailable
        );

    /**
     * @dev Get contract addresses
     * @return depositManager Current deposit manager address
     * @return foodContract Current food contract address
     */
    function getContractAddresses()
        external
        view
        returns (address depositManager, address foodContract);
}
