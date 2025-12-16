// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NekoCatErrors
 * @dev Custom errors for NekoCat NFT system
 */
library NekoCatErrors {
    // ============ Minting Errors ============
    error MaxSupplyReached();
    error InvalidCharacterType();
    error InvalidVariant();
    error InvalidLevel();
    error InsufficientMintPayment();

    // ============ Feeding Errors ============
    error CatIsDead();
    error CatIsImmortal();
    error NotFeedingTime();
    error AlreadyFedThisSlot(uint256 tokenId, uint8 slot);
    error DailyFeedsNotComplete();
    error InsufficientFeedingPayment(uint256 required, uint256 provided);
    error NotCatOwner();
    error FeedTooSoon(uint256 timeRemaining);
    error InvalidFoodType(uint256 foodId, bool isActive);
    error FoodContractNotSet();

    // ============ Revival Errors ============
    error CatIsAlive();
    error NoLivesRemaining();
    error InsufficientRevivalPayment(uint256 required, uint256 provided);
    error RevivalCountExceeded(uint256 maxRevivals);

    // ============ Immortality Errors ============
    error AlreadyImmortal();
    error NotImmortal();
    error InsufficientStake();
    error OnlyStakingContract();

    // ============ Security Errors ============
    error CannotKillOwnNFT();
    error DeathCheckTooFrequent();
    error InvalidTimestamp();
    error TimestampManipulation();
    error SuspiciousTiming();
    error IntegerOverflow();
    error IntegerUnderflow();

    // ============ General Errors ============
    error TokenDoesNotExist();
    error InvalidTokenId();
    error InvalidPaymentAmount();
    error ContractPaused();
    error InvalidAddress();
    error Unauthorized();
    error TransferFailed();

    // ============ Batch Operation Errors ============
    error EmptyArray();
    error ArrayLengthMismatch();
    error BatchTooLarge();
    error DuplicateTokenIds();

    // ============ Admin Errors ============
    error InvalidContractAddress();
    error ContractAlreadySet();
    error ThresholdTooLow();
    error ThresholdTooHigh();
}
