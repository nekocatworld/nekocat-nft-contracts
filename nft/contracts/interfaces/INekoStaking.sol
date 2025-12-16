// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title INekoStaking
 * @dev Interface for NEKO token staking contract
 * @notice Used by NFT contract to check if a user has staked enough NEKO for immortality
 *
 * The staking contract is EXTERNAL - it exists separately in /erc20/contracts/NekoStaking.sol
 * NFT contract tracks this external contract to verify stake amounts for immortality
 */
interface INekoStaking {
    /**
     * @dev Check if user has staked minimum amount for immortality
     * @param user Address to check
     * @return bool True if user has staked 2M+ NEKO across all pools
     * @notice DEPRECATED - Use hasImmortalityStakeWithThreshold instead
     */
    function hasImmortalityStake(address user) external view returns (bool);

    /**
     * @dev Check if user has staked minimum amount for immortality (with custom threshold)
     * @param user Address to check
     * @param threshold Minimum stake amount required
     * @return bool True if user has staked >= threshold
     */
    function hasImmortalityStakeWithThreshold(
        address user,
        uint256 threshold
    ) external view returns (bool);

    /**
     * @dev Check if user has valid immortality stake (amount + duration)
     * @param user Address to check
     * @param threshold Minimum stake amount required
     * @return bool True if user has valid stake for immortality
     */
    function hasValidImmortalityStake(
        address user,
        uint256 threshold
    ) external view returns (bool);

    /**
     * @dev Get user's total staked amount across all pools
     * @param user Address to check
     * @return uint256 Total amount of NEKO staked
     */
    function getStakedAmount(address user) external view returns (uint256);

    /**
     * @dev Get user's valid staked amount (only active stakes within duration)
     * @param user Address to check
     * @return uint256 Total valid staked amount
     */
    function getValidStakedAmount(address user) external view returns (uint256);

    /**
     * @dev Minimum stake required for immortality (2M NEKO = 2,000,000 * 10^18)
     * @return uint256 Minimum stake amount in wei
     * @notice DEPRECATED - NFT contract now maintains its own threshold
     */
    function IMMORTALITY_THRESHOLD() external view returns (uint256);

    /**
     * @dev Event emitted when user's immortality status changes
     */
    event ImmortalityStatusChanged(
        address indexed user,
        bool hasImmortality,
        uint256 totalStaked
    );
}
