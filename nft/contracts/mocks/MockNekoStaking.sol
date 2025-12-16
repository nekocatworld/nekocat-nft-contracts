// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockNekoStaking {
    mapping(address => uint256) private stakedBalance;

    function stake(uint256 amount) external {
        stakedBalance[msg.sender] += amount;
    }

    function unstake(uint256 amount) external {
        require(stakedBalance[msg.sender] >= amount, "Insufficient balance");
        stakedBalance[msg.sender] -= amount;
    }

    function getStakedBalance(address user) external view returns (uint256) {
        return stakedBalance[user];
    }

    function setStakedBalance(address user, uint256 amount) external {
        stakedBalance[user] = amount;
    }
}

