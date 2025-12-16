// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IDepositManager.sol";
import "./interfaces/INekoCatFood.sol";

/**
 * @title NekoPriceManager
 * @dev Centralized admin contract for managing all ETH-based pricing across the NekoCat ecosystem
 * @notice Provides secure batch operations for updating ETH prices across all contracts
 *
 * Key Features:
 * - Batch update all ecosystem prices in single transaction
 * - ETH-only pricing system (no USDT/ASTR)
 * - Comprehensive validation and safety checks
 * - Emergency pause functionality
 * - Detailed event logging for transparency
 * - Multi-signature support ready
 */
contract NekoPriceManager is Ownable, ReentrancyGuard, Pausable {
    // ============ State Variables ============

    address public depositManager;
    address public foodContract;

    // Price update limits for safety
    uint256 public constant MAX_FOOD_PRICE_ETH = 1e18; // 1 ETH max per food

    // Emergency controls
    bool public emergencyMode = false;
    uint256 public lastPriceUpdate;
    uint256 public constant MIN_UPDATE_INTERVAL = 1 hours; // Minimum 1 hour between updates

    // ============ Structs ============

    struct PricingUpdate {
        // DepositManager pricing
        uint256 baseRevivalCostETH;
        uint256 revivalMultiplier;
        // Food pricing
        uint256[] foodTypeIds;
        uint256[] foodPrices;
        // Metadata
        uint256 timestamp;
        string reason;
    }

    // ============ Events ============

    event EcosystemPricingUpdated(
        address indexed admin,
        PricingUpdate update,
        uint256 blockNumber
    );

    event EmergencyModeToggled(bool enabled, string reason);
    event ContractsUpdated(
        address indexed oldDepositManager,
        address indexed newDepositManager,
        address indexed oldFoodContract,
        address newFoodContract
    );

    event PriceUpdateRejected(string reason, uint256 attemptedTimestamp);

    // ============ Errors ============

    error InvalidContractAddress();
    error PriceUpdateTooFrequent();
    error EmergencyModeActive();
    error InvalidPriceRange();
    error ArrayLengthMismatch();
    error InvalidRevivalMultiplier();
    error ContractCallFailed();

    // ============ Constructor ============

    constructor(
        address _depositManager,
        address _foodContract
    ) Ownable(msg.sender) {
        require(_depositManager != address(0), "Invalid deposit manager");
        require(_foodContract != address(0), "Invalid food contract");

        depositManager = _depositManager;
        foodContract = _foodContract;

        lastPriceUpdate = block.timestamp;
    }

    // ============ Main Admin Functions ============

    /**
     * @dev Update all ecosystem pricing in a single transaction
     * @param update Complete pricing update structure
     */
    function updateEcosystemPricing(
        PricingUpdate calldata update
    ) external onlyOwner whenNotPaused nonReentrant {
        // Check emergency mode
        if (emergencyMode) {
            revert EmergencyModeActive();
        }

        // Check update frequency
        if (block.timestamp - lastPriceUpdate < MIN_UPDATE_INTERVAL) {
            revert PriceUpdateTooFrequent();
        }

        // Validate pricing update
        _validatePricingUpdate(update);

        // Update DepositManager pricing
        _updateDepositManagerPricing(update);

        // Update Food contract pricing
        if (update.foodTypeIds.length > 0) {
            _updateFoodPricing(update);
        }

        // Update timestamp
        lastPriceUpdate = block.timestamp;

        // Emit comprehensive event
        emit EcosystemPricingUpdated(msg.sender, update, block.number);
    }

    /**
     * @dev Emergency pricing update (bypasses frequency check)
     * @param update Complete pricing update structure
     * @param emergencyReason Reason for emergency update
     */
    function emergencyPricingUpdate(
        PricingUpdate calldata update,
        string calldata emergencyReason
    ) external onlyOwner nonReentrant {
        // Validate pricing update
        _validatePricingUpdate(update);

        // Update DepositManager pricing
        _updateDepositManagerPricing(update);

        // Update Food contract pricing
        if (update.foodTypeIds.length > 0) {
            _updateFoodPricing(update);
        }

        // Update timestamp
        lastPriceUpdate = block.timestamp;

        // Emit comprehensive event with emergency flag
        emit EcosystemPricingUpdated(msg.sender, update, block.number);
        emit EmergencyModeToggled(true, emergencyReason);
    }

    // ============ Individual Update Functions ============

    /**
     * @dev Update only DepositManager pricing
     */
    function updateDepositManagerPricing(
        uint256 baseRevivalCostETH,
        uint256 revivalMultiplier
    ) external onlyOwner whenNotPaused {
        PricingUpdate memory update = PricingUpdate({
            baseRevivalCostETH: baseRevivalCostETH,
            revivalMultiplier: revivalMultiplier,
            foodTypeIds: new uint256[](0),
            foodPrices: new uint256[](0),
            timestamp: block.timestamp,
            reason: "DepositManager only update"
        });

        _validateDepositManagerPricing(update);
        _updateDepositManagerPricing(update);

        emit EcosystemPricingUpdated(msg.sender, update, block.number);
    }

    /**
     * @dev Update only Food contract pricing
     */
    function updateFoodPricing(
        uint256[] calldata foodTypeIds,
        uint256[] calldata foodPrices,
        string calldata reason
    ) external onlyOwner whenNotPaused {
        PricingUpdate memory update = PricingUpdate({
            baseRevivalCostETH: 0,
            revivalMultiplier: 0,
            foodTypeIds: foodTypeIds,
            foodPrices: foodPrices,
            timestamp: block.timestamp,
            reason: reason
        });

        _validateFoodPricing(update);
        _updateFoodPricing(update);

        emit EcosystemPricingUpdated(msg.sender, update, block.number);
    }

    // ============ Emergency Controls ============

    /**
     * @dev Toggle emergency mode
     */
    function toggleEmergencyMode(
        bool enabled,
        string calldata reason
    ) external onlyOwner {
        emergencyMode = enabled;
        emit EmergencyModeToggled(enabled, reason);
    }

    /**
     * @dev Pause all price updates
     */
    function pausePriceUpdates() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause price updates
     */
    function unpausePriceUpdates() external onlyOwner {
        _unpause();
    }

    // ============ Contract Management ============

    /**
     * @dev Update contract addresses
     */
    function updateContracts(
        address newDepositManager,
        address newFoodContract
    ) external onlyOwner {
        if (newDepositManager == address(0)) revert InvalidContractAddress();
        if (newFoodContract == address(0)) revert InvalidContractAddress();

        address oldDepositManager = depositManager;
        address oldFoodContract = foodContract;

        depositManager = newDepositManager;
        foodContract = newFoodContract;

        emit ContractsUpdated(
            oldDepositManager,
            newDepositManager,
            oldFoodContract,
            newFoodContract
        );
    }

    // ============ Internal Functions ============

    /**
     * @dev Validate complete pricing update
     */
    function _validatePricingUpdate(
        PricingUpdate calldata update
    ) internal pure {
        // Validate DepositManager pricing
        if (update.baseRevivalCostETH > 0) {
            if (update.baseRevivalCostETH > 1e18) {
                // Max 1 ETH
                revert InvalidPriceRange();
            }
        }

        if (update.revivalMultiplier > 0) {
            if (
                update.revivalMultiplier < 100 || update.revivalMultiplier > 300
            ) {
                revert InvalidRevivalMultiplier();
            }
        }

        // Validate Food pricing
        if (update.foodTypeIds.length > 0) {
            if (update.foodTypeIds.length != update.foodPrices.length) {
                revert ArrayLengthMismatch();
            }

            for (uint256 i = 0; i < update.foodPrices.length; i++) {
                if (update.foodPrices[i] > MAX_FOOD_PRICE_ETH) {
                    revert InvalidPriceRange();
                }
            }
        }
    }

    /**
     * @dev Validate DepositManager pricing only
     */
    function _validateDepositManagerPricing(
        PricingUpdate memory update
    ) internal pure {
        if (update.baseRevivalCostETH > 1e18) {
            // Max 1 ETH
            revert InvalidPriceRange();
        }

        if (
            update.revivalMultiplier > 0 &&
            (update.revivalMultiplier < 100 || update.revivalMultiplier > 300)
        ) {
            revert InvalidRevivalMultiplier();
        }
    }

    /**
     * @dev Validate Food pricing only
     */
    function _validateFoodPricing(PricingUpdate memory update) internal pure {
        if (update.foodTypeIds.length != update.foodPrices.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < update.foodPrices.length; i++) {
            if (update.foodPrices[i] > MAX_FOOD_PRICE_ETH) {
                revert InvalidPriceRange();
            }
        }
    }

    /**
     * @dev Update DepositManager pricing
     */
    function _updateDepositManagerPricing(
        PricingUpdate memory update
    ) internal {
        try
            IDepositManager(depositManager).updateBaseRevivalCost(
                update.baseRevivalCostETH
            )
        {
            // Success
        } catch {
            revert ContractCallFailed();
        }

        try
            IDepositManager(depositManager).updateRevivalMultiplier(
                update.revivalMultiplier
            )
        {
            // Success
        } catch {
            revert ContractCallFailed();
        }
    }

    /**
     * @dev Update Food contract pricing
     */
    function _updateFoodPricing(PricingUpdate memory update) internal {
        try
            INekoCatFood(foodContract).batchUpdateFoodPrices(
                update.foodTypeIds,
                update.foodPrices
            )
        {
            // Success
        } catch {
            revert ContractCallFailed();
        }
    }

    // ============ View Functions ============

    /**
     * @dev Get current pricing status
     */
    function getPricingStatus()
        external
        view
        returns (
            bool isEmergencyMode,
            bool isPaused,
            uint256 lastUpdate,
            uint256 timeSinceLastUpdate,
            address currentDepositManager,
            address currentFoodContract
        )
    {
        return (
            emergencyMode,
            paused(),
            lastPriceUpdate,
            block.timestamp - lastPriceUpdate,
            depositManager,
            foodContract
        );
    }

    /**
     * @dev Check if price update is allowed
     */
    function canUpdatePrices() external view returns (bool) {
        if (emergencyMode || paused()) {
            return false;
        }

        return block.timestamp - lastPriceUpdate >= MIN_UPDATE_INTERVAL;
    }

    /**
     * @dev Get time until next update is allowed
     */
    function timeUntilNextUpdate() external view returns (uint256) {
        if (emergencyMode || paused()) {
            return type(uint256).max;
        }

        uint256 timePassed = block.timestamp - lastPriceUpdate;
        if (timePassed >= MIN_UPDATE_INTERVAL) {
            return 0;
        }

        return MIN_UPDATE_INTERVAL - timePassed;
    }
}
