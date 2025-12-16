// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DepositErrors
 * @dev Custom errors for DepositManager
 */
library DepositErrors {
    // ============ Configuration Errors ============

    error InvalidAddress();
    error ContractAlreadySet();
    error InvalidPrice();
    error InvalidMultiplier();

    // ============ Payment Errors ============

    error InsufficientPayment(uint256 required, uint256 provided);
    error PaymentFailed();
    error WithdrawalFailed();

    error NegativePrice(int256 price);

    // ============ Access Errors ============

    error OnlyNFTContract();
    error Unauthorized();
}
