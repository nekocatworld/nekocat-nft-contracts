// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library MarketplaceErrors {
    error InvalidNFTContract();
    error InvalidFeeRecipient();
    error InvalidPrice();
    error PriceTooLow(uint256 minPrice);
    error PriceTooHigh(uint256 maxPrice);
    error NotOwner();
    error MarketplaceNotApproved();
    error ListingNotActive();
    error ListingDoesNotExist();
    error InsufficientPayment();
    error CannotBuyOwnNFT();
    error NotSeller();
    error FeeTransferFailed();
    error SellerPaymentFailed();
    error RefundFailed();
    error FeeExceedsMaximum(uint256 maxFee);
    error InvalidAddress();
    error DirectETHTransferNotAllowed();
    error NFTTransferFailed();
    error ListingAlreadyExists();
    error TokenAlreadyListed(uint256 tokenId);
    error ArrayLengthMismatch();
    error BatchTooLarge();
    error ListingExpired();
    error InvalidExpirationTime();
    error ExactPaymentRequired(uint256 required, uint256 received);
}

