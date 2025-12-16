// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/INekoStaking.sol";

contract MockStaking is INekoStaking {
    mapping(address => uint256) private stakedAmounts;
    uint256 public constant IMMORTALITY_THRESHOLD = 2000000 * 10 ** 18; // 2M NEKO

    function getStakedAmount(
        address user
    ) external view override returns (uint256) {
        return stakedAmounts[user];
    }

    function getValidStakedAmount(
        address user
    ) external view override returns (uint256) {
        return stakedAmounts[user]; // Simplified - assume all stakes are valid
    }

    function hasImmortalityStake(
        address user
    ) external view override returns (bool) {
        return stakedAmounts[user] >= IMMORTALITY_THRESHOLD;
    }

    function hasImmortalityStakeWithThreshold(
        address user,
        uint256 threshold
    ) external view override returns (bool) {
        return stakedAmounts[user] >= threshold;
    }

    function hasValidImmortalityStake(
        address user,
        uint256 threshold
    ) external view override returns (bool) {
        return stakedAmounts[user] >= threshold; // Simplified - assume all stakes are valid
    }

    // Test helper functions
    function setStakedAmount(address user, uint256 amount) external {
        stakedAmounts[user] = amount;
    }

    function stake(uint256 amount) external {
        stakedAmounts[msg.sender] += amount;
    }

    function unstake(uint256 amount) external {
        require(stakedAmounts[msg.sender] >= amount, "Insufficient stake");
        stakedAmounts[msg.sender] -= amount;
    }
}
