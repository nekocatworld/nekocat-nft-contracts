// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface INekoMarketplace {
    struct Listing {
        uint256 listingId;
        uint256 tokenId;
        address seller;
        uint256 price;
        uint64 timestamp;
        bool active;
    }

    event NFTListed(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );

    event NFTSold(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed seller,
        address buyer,
        uint256 price
    );

    event ListingCancelled(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed seller
    );

    function listNFT(uint256 tokenId, uint256 price) external;

    function buyNFT(uint256 listingId) external payable;

    function batchBuyNFT(uint256[] calldata listingIds) external payable;

    function cancelListing(uint256 listingId) external;

    function getListing(
        uint256 listingId
    ) external view returns (Listing memory);

    function getAllActiveListings(
        uint256 offset,
        uint256 limit
    ) external view returns (Listing[] memory, uint256 total);

    function getListingsBySeller(
        address seller,
        uint256 offset,
        uint256 limit
    ) external view returns (Listing[] memory, uint256 total);

    function getListingsByTokenId(
        uint256 tokenId
    ) external view returns (Listing[] memory);

    function getActiveListingCount() external view returns (uint256);

    function updateListingPrice(uint256 listingId, uint256 newPrice) external;

    function batchListNFT(
        uint256[] calldata tokenIds,
        uint256[] calldata prices
    ) external;

    function batchCancelListing(uint256[] calldata listingIds) external;

    function cleanExpiredListings(uint256 maxIterations) external;

    function getMarketplaceStats()
        external
        view
        returns (
            uint256 totalVolume,
            uint256 totalSales,
            uint256 activeListings,
            uint256 platformFeePercent
        );

    function getUserStats(
        address user
    )
        external
        view
        returns (uint256 userVolume, uint256 userSales, uint256 userListings);
}
