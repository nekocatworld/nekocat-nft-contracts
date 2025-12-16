// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/INekoMarketplace.sol";
import "./lib/MarketplaceErrors.sol";

contract NekoMarketplace is
    INekoMarketplace,
    Ownable,
    AccessControl,
    Pausable,
    ReentrancyGuard,
    IERC721Receiver
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    bytes32 public constant PRICE_MANAGER_ROLE =
        keccak256("PRICE_MANAGER_ROLE");
    bytes32 public constant BLACKLIST_MANAGER_ROLE =
        keccak256("BLACKLIST_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    IERC721 public immutable nftContract;

    uint256 private _nextListingId = 1;
    uint256 public platformFeePercent = 250; // 2.5% (in basis points)
    uint256 public constant MAX_FEE_PERCENT = 1000; // 10% maximum
    uint256 public minPrice = 0;
    uint256 public maxPrice = type(uint256).max;
    uint256 public listingExpirationTime = 30 days; // Default 30 days
    address public feeRecipient;

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => uint256[]) private tokenIdToListings;
    mapping(address => uint256[]) private sellerToListings;
    mapping(uint256 => uint256) private activeListingIdsIndex;
    mapping(address => bool) public blacklist;
    uint256[] private activeListingIds;

    uint256 public totalVolume;
    uint256 public totalSales;
    mapping(address => uint256) public userVolume;
    mapping(address => uint256) public userSales;

    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event MinPriceUpdated(uint256 oldMinPrice, uint256 newMinPrice);
    event MaxPriceUpdated(uint256 oldMaxPrice, uint256 newMaxPrice);
    event ListingExpirationTimeUpdated(uint256 oldTime, uint256 newTime);
    event EmergencyWithdraw(address recipient, uint256 amount);
    event BlacklistUpdated(address user, bool isBlacklisted);
    event ListingPriceUpdated(
        uint256 indexed listingId,
        uint256 oldPrice,
        uint256 newPrice
    );
    event ExpiredListingsCleaned(uint256 count);

    modifier onlyActiveListing(uint256 listingId) {
        if (!listings[listingId].active) {
            revert MarketplaceErrors.ListingNotActive();
        }
        if (listings[listingId].seller == address(0)) {
            revert MarketplaceErrors.ListingDoesNotExist();
        }
        if (
            block.timestamp >
            listings[listingId].timestamp + listingExpirationTime
        ) {
            revert MarketplaceErrors.ListingNotActive();
        }
        _;
    }

    modifier validPrice(uint256 price) {
        if (price == 0) {
            revert MarketplaceErrors.InvalidPrice();
        }
        if (price < minPrice) {
            revert MarketplaceErrors.PriceTooLow(minPrice);
        }
        if (price > maxPrice) {
            revert MarketplaceErrors.PriceTooHigh(maxPrice);
        }
        _;
    }

    modifier notBlacklisted() {
        if (blacklist[msg.sender]) {
            revert MarketplaceErrors.InvalidAddress();
        }
        _;
    }

    constructor(
        address _nftContract,
        address _feeRecipient
    ) Ownable(msg.sender) {
        if (_nftContract == address(0)) {
            revert MarketplaceErrors.InvalidNFTContract();
        }
        if (_feeRecipient == address(0)) {
            revert MarketplaceErrors.InvalidFeeRecipient();
        }
        nftContract = IERC721(_nftContract);
        feeRecipient = _feeRecipient;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(FEE_MANAGER_ROLE, msg.sender);
        _grantRole(PRICE_MANAGER_ROLE, msg.sender);
        _grantRole(BLACKLIST_MANAGER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
    }

    function listNFT(
        uint256 tokenId,
        uint256 price
    ) external whenNotPaused nonReentrant validPrice(price) notBlacklisted {
        if (nftContract.ownerOf(tokenId) != msg.sender) {
            revert MarketplaceErrors.NotOwner();
        }

        address approved = _getApproved(tokenId);
        bool isApprovedForAll = _isApprovedForAll(msg.sender, address(this));
        if (approved != address(this) && !isApprovedForAll) {
            revert MarketplaceErrors.MarketplaceNotApproved();
        }

        uint256[] memory existingListings = tokenIdToListings[tokenId];
        for (uint256 i = 0; i < existingListings.length; i++) {
            if (listings[existingListings[i]].active) {
                revert MarketplaceErrors.TokenAlreadyListed(tokenId);
            }
        }

        uint256 listingId = _nextListingId++;
        listings[listingId] = Listing({
            listingId: listingId,
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            timestamp: uint64(block.timestamp),
            active: true
        });

        tokenIdToListings[tokenId].push(listingId);
        sellerToListings[msg.sender].push(listingId);
        activeListingIdsIndex[listingId] = activeListingIds.length;
        activeListingIds.push(listingId);

        emit NFTListed(listingId, tokenId, msg.sender, price);
    }

    function buyNFT(
        uint256 listingId
    )
        external
        payable
        whenNotPaused
        nonReentrant
        onlyActiveListing(listingId)
        notBlacklisted
    {
        Listing storage listing = listings[listingId];

        if (nftContract.ownerOf(listing.tokenId) != listing.seller) {
            listing.active = false;
            _removeFromActiveListings(listingId);
            revert MarketplaceErrors.NotOwner();
        }

        if (msg.value != listing.price) {
            revert MarketplaceErrors.ExactPaymentRequired(
                listing.price,
                msg.value
            );
        }
        if (msg.sender == listing.seller) {
            revert MarketplaceErrors.CannotBuyOwnNFT();
        }

        uint256 fee = (listing.price * platformFeePercent) / 10000;
        uint256 sellerAmount = listing.price - fee;

        listing.active = false;
        _removeFromActiveListings(listingId);

        try
            nftContract.safeTransferFrom(
                listing.seller,
                msg.sender,
                listing.tokenId
            )
        {} catch {
            listing.active = true;
            activeListingIdsIndex[listingId] = activeListingIds.length;
            activeListingIds.push(listingId);
            revert MarketplaceErrors.NFTTransferFailed();
        }
        bool feeSent = false;
        bool sellerSent = false;

        if (fee > 0) {
            (feeSent, ) = feeRecipient.call{value: fee}("");
            if (!feeSent) {
                listing.active = true;
                activeListingIdsIndex[listingId] = activeListingIds.length;
                activeListingIds.push(listingId);
                revert MarketplaceErrors.FeeTransferFailed();
            }
        }

        if (sellerAmount > 0) {
            (sellerSent, ) = listing.seller.call{value: sellerAmount}("");
            if (!sellerSent) {
                listing.active = true;
                activeListingIdsIndex[listingId] = activeListingIds.length;
                activeListingIds.push(listingId);
                revert MarketplaceErrors.SellerPaymentFailed();
            }
        }

        totalVolume += listing.price;
        totalSales++;
        userVolume[listing.seller] += listing.price;
        userSales[listing.seller]++;
        userVolume[msg.sender] += listing.price;

        emit NFTSold(
            listingId,
            listing.tokenId,
            listing.seller,
            msg.sender,
            listing.price
        );
    }

    function batchBuyNFT(
        uint256[] calldata listingIds
    )
        external
        payable
        whenNotPaused
        nonReentrant
        notBlacklisted
    {
        if (listingIds.length == 0 || listingIds.length > 50) {
            revert MarketplaceErrors.BatchTooLarge();
        }

        uint256 totalPrice = 0;
        
        // First pass: validate all listings and calculate total price
        for (uint256 i = 0; i < listingIds.length; i++) {
            Listing storage listing = listings[listingIds[i]];
            
            if (!listing.active) {
                revert MarketplaceErrors.ListingNotActive();
            }
            if (listing.seller == address(0)) {
                revert MarketplaceErrors.ListingDoesNotExist();
            }
            if (block.timestamp > listing.timestamp + listingExpirationTime) {
                revert MarketplaceErrors.ListingNotActive();
            }
            if (nftContract.ownerOf(listing.tokenId) != listing.seller) {
                revert MarketplaceErrors.NotOwner();
            }
            if (msg.sender == listing.seller) {
                revert MarketplaceErrors.CannotBuyOwnNFT();
            }
            
            totalPrice += listing.price;
        }

        // Check total payment
        if (msg.value != totalPrice) {
            revert MarketplaceErrors.ExactPaymentRequired(totalPrice, msg.value);
        }

        // Second pass: execute all purchases
        for (uint256 i = 0; i < listingIds.length; i++) {
            Listing storage listing = listings[listingIds[i]];
            
            uint256 fee = (listing.price * platformFeePercent) / 10000;
            uint256 sellerAmount = listing.price - fee;

            listing.active = false;
            _removeFromActiveListings(listingIds[i]);

            // Transfer NFT
            try
                nftContract.safeTransferFrom(
                    listing.seller,
                    msg.sender,
                    listing.tokenId
                )
            {} catch {
                listing.active = true;
                activeListingIdsIndex[listingIds[i]] = activeListingIds.length;
                activeListingIds.push(listingIds[i]);
                revert MarketplaceErrors.NFTTransferFailed();
            }

            // Transfer fee
            if (fee > 0) {
                (bool feeSent, ) = feeRecipient.call{value: fee}("");
                if (!feeSent) {
                    listing.active = true;
                    activeListingIdsIndex[listingIds[i]] = activeListingIds.length;
                    activeListingIds.push(listingIds[i]);
                    revert MarketplaceErrors.FeeTransferFailed();
                }
            }

            // Transfer to seller
            if (sellerAmount > 0) {
                (bool sellerSent, ) = listing.seller.call{value: sellerAmount}("");
                if (!sellerSent) {
                    listing.active = true;
                    activeListingIdsIndex[listingIds[i]] = activeListingIds.length;
                    activeListingIds.push(listingIds[i]);
                    revert MarketplaceErrors.SellerPaymentFailed();
                }
            }

            // Update stats
            totalVolume += listing.price;
            totalSales++;
            userVolume[listing.seller] += listing.price;
            userSales[listing.seller]++;
            userVolume[msg.sender] += listing.price;

            emit NFTSold(
                listingIds[i],
                listing.tokenId,
                listing.seller,
                msg.sender,
                listing.price
            );
        }
    }

    function cancelListing(
        uint256 listingId
    ) external whenNotPaused onlyActiveListing(listingId) {
        Listing storage listing = listings[listingId];
        if (listing.seller != msg.sender) {
            revert MarketplaceErrors.NotSeller();
        }

        listing.active = false;
        _removeFromActiveListings(listingId);

        emit ListingCancelled(listingId, listing.tokenId, listing.seller);
    }

    function updateListingPrice(
        uint256 listingId,
        uint256 newPrice
    ) external whenNotPaused onlyActiveListing(listingId) validPrice(newPrice) {
        Listing storage listing = listings[listingId];
        if (listing.seller != msg.sender) {
            revert MarketplaceErrors.NotSeller();
        }
        if (nftContract.ownerOf(listing.tokenId) != msg.sender) {
            revert MarketplaceErrors.NotOwner();
        }

        uint256 oldPrice = listing.price;
        listing.price = newPrice;
        listing.timestamp = uint64(block.timestamp);

        emit ListingPriceUpdated(listingId, oldPrice, newPrice);
    }

    function batchListNFT(
        uint256[] calldata tokenIds,
        uint256[] calldata prices
    ) external whenNotPaused nonReentrant notBlacklisted {
        if (tokenIds.length != prices.length) {
            revert MarketplaceErrors.ArrayLengthMismatch();
        }
        if (tokenIds.length == 0 || tokenIds.length > 50) {
            revert MarketplaceErrors.BatchTooLarge();
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (nftContract.ownerOf(tokenIds[i]) != msg.sender) {
                continue;
            }

            address approved = _getApproved(tokenIds[i]);
            bool isApprovedForAll = _isApprovedForAll(
                msg.sender,
                address(this)
            );
            if (approved != address(this) && !isApprovedForAll) {
                continue;
            }

            if (
                prices[i] < minPrice || prices[i] > maxPrice || prices[i] == 0
            ) {
                continue;
            }

            uint256 listingId = _nextListingId++;
            listings[listingId] = Listing({
                listingId: listingId,
                tokenId: tokenIds[i],
                seller: msg.sender,
                price: prices[i],
                timestamp: uint64(block.timestamp),
                active: true
            });

            tokenIdToListings[tokenIds[i]].push(listingId);
            sellerToListings[msg.sender].push(listingId);
            activeListingIdsIndex[listingId] = activeListingIds.length;
            activeListingIds.push(listingId);

            emit NFTListed(listingId, tokenIds[i], msg.sender, prices[i]);
        }
    }

    function batchCancelListing(
        uint256[] calldata listingIds
    ) external whenNotPaused {
        if (listingIds.length == 0 || listingIds.length > 50) {
            revert MarketplaceErrors.BatchTooLarge();
        }

        for (uint256 i = 0; i < listingIds.length; i++) {
            Listing storage listing = listings[listingIds[i]];
            if (!listing.active || listing.seller != msg.sender) {
                continue;
            }

            listing.active = false;
            _removeFromActiveListings(listingIds[i]);

            emit ListingCancelled(
                listingIds[i],
                listing.tokenId,
                listing.seller
            );
        }
    }

    function cleanExpiredListings(uint256 maxIterations) external {
        uint256 cleaned = 0;
        uint256 iterations = 0;

        for (
            uint256 i = activeListingIds.length;
            i > 0 && iterations < maxIterations;
            i--
        ) {
            uint256 listingId = activeListingIds[i - 1];
            Listing storage listing = listings[listingId];

            if (
                listing.active &&
                block.timestamp > listing.timestamp + listingExpirationTime
            ) {
                listing.active = false;
                _removeFromActiveListings(listingId);
                cleaned++;
            }
            iterations++;
        }

        if (cleaned > 0) {
            emit ExpiredListingsCleaned(cleaned);
        }
    }

    function getListing(
        uint256 listingId
    ) external view returns (Listing memory) {
        return listings[listingId];
    }

    function getAllActiveListings(
        uint256 offset,
        uint256 limit
    ) external view returns (Listing[] memory, uint256 total) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < activeListingIds.length; i++) {
            uint256 listingId = activeListingIds[i];
            if (
                listings[listingId].active &&
                block.timestamp <=
                listings[listingId].timestamp + listingExpirationTime
            ) {
                activeCount++;
            }
        }

        if (offset >= activeCount) {
            return (new Listing[](0), activeCount);
        }

        uint256 end = offset + limit;
        if (end > activeCount) {
            end = activeCount;
        }

        Listing[] memory activeListings = new Listing[](end - offset);
        uint256 index = 0;
        uint256 currentIndex = 0;

        for (
            uint256 i = 0;
            i < activeListingIds.length && currentIndex < end;
            i++
        ) {
            uint256 listingId = activeListingIds[i];
            Listing memory listing = listings[listingId];

            if (
                listing.active &&
                block.timestamp <= listing.timestamp + listingExpirationTime
            ) {
                if (currentIndex >= offset) {
                    activeListings[index] = listing;
                    index++;
                }
                currentIndex++;
            }
        }

        return (activeListings, activeCount);
    }

    function getListingsBySeller(
        address seller,
        uint256 offset,
        uint256 limit
    ) external view returns (Listing[] memory, uint256 total) {
        uint256[] memory sellerListings = sellerToListings[seller];
        uint256 totalCount = sellerListings.length;

        if (offset >= totalCount) {
            return (new Listing[](0), totalCount);
        }

        uint256 end = offset + limit;
        if (end > totalCount) {
            end = totalCount;
        }

        Listing[] memory result = new Listing[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = listings[sellerListings[i]];
        }

        return (result, totalCount);
    }

    function getListingsByTokenId(
        uint256 tokenId
    ) external view returns (Listing[] memory) {
        uint256[] memory tokenListings = tokenIdToListings[tokenId];
        Listing[] memory result = new Listing[](tokenListings.length);

        for (uint256 i = 0; i < tokenListings.length; i++) {
            result[i] = listings[tokenListings[i]];
        }

        return result;
    }

    function getActiveListingCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < activeListingIds.length; i++) {
            uint256 listingId = activeListingIds[i];
            if (
                listings[listingId].active &&
                block.timestamp <=
                listings[listingId].timestamp + listingExpirationTime
            ) {
                count++;
            }
        }
        return count;
    }

    function getMarketplaceStats()
        external
        view
        returns (
            uint256 _totalVolume,
            uint256 _totalSales,
            uint256 _activeListings,
            uint256 _platformFeePercent
        )
    {
        return (
            totalVolume,
            totalSales,
            this.getActiveListingCount(),
            platformFeePercent
        );
    }

    function getUserStats(
        address user
    )
        external
        view
        returns (uint256 _userVolume, uint256 _userSales, uint256 _userListings)
    {
        return (
            userVolume[user],
            userSales[user],
            sellerToListings[user].length
        );
    }

    function _getApproved(uint256 tokenId) internal view returns (address) {
        (bool success, bytes memory data) = address(nftContract).staticcall(
            abi.encodeWithSignature("getApproved(uint256)", tokenId)
        );
        if (success && data.length >= 32) {
            return abi.decode(data, (address));
        }
        return address(0);
    }

    function _isApprovedForAll(
        address owner,
        address operator
    ) internal view returns (bool) {
        (bool success, bytes memory data) = address(nftContract).staticcall(
            abi.encodeWithSignature(
                "isApprovedForAll(address,address)",
                owner,
                operator
            )
        );
        if (success && data.length >= 32) {
            return abi.decode(data, (bool));
        }
        return false;
    }

    function _removeFromActiveListings(uint256 listingId) internal {
        uint256 index = activeListingIdsIndex[listingId];
        if (
            index >= activeListingIds.length ||
            activeListingIds[index] != listingId
        ) {
            return;
        }

        uint256 lastIndex = activeListingIds.length - 1;
        if (index != lastIndex) {
            uint256 lastListingId = activeListingIds[lastIndex];
            activeListingIds[index] = lastListingId;
            activeListingIdsIndex[lastListingId] = index;
        }

        activeListingIds.pop();
        delete activeListingIdsIndex[listingId];
    }

    function setPlatformFee(
        uint256 _feePercent
    ) external onlyRole(FEE_MANAGER_ROLE) {
        if (_feePercent > MAX_FEE_PERCENT) {
            revert MarketplaceErrors.FeeExceedsMaximum(MAX_FEE_PERCENT);
        }
        uint256 oldFee = platformFeePercent;
        platformFeePercent = _feePercent;
        emit PlatformFeeUpdated(oldFee, _feePercent);
    }

    function setFeeRecipient(
        address _feeRecipient
    ) external onlyRole(FEE_MANAGER_ROLE) {
        if (_feeRecipient == address(0)) {
            revert MarketplaceErrors.InvalidAddress();
        }
        if (_feeRecipient == address(this)) {
            revert MarketplaceErrors.InvalidAddress();
        }
        address oldRecipient = feeRecipient;
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(oldRecipient, _feeRecipient);
    }

    function setMinPrice(
        uint256 _minPrice
    ) external onlyRole(PRICE_MANAGER_ROLE) {
        uint256 oldMinPrice = minPrice;
        minPrice = _minPrice;
        emit MinPriceUpdated(oldMinPrice, _minPrice);
    }

    function setMaxPrice(
        uint256 _maxPrice
    ) external onlyRole(PRICE_MANAGER_ROLE) {
        uint256 oldMaxPrice = maxPrice;
        maxPrice = _maxPrice;
        emit MaxPriceUpdated(oldMaxPrice, _maxPrice);
    }

    function setListingExpirationTime(
        uint256 _expirationTime
    ) external onlyRole(ADMIN_ROLE) {
        if (_expirationTime == 0 || _expirationTime > 365 days) {
            revert MarketplaceErrors.InvalidExpirationTime();
        }
        uint256 oldTime = listingExpirationTime;
        listingExpirationTime = _expirationTime;
        emit ListingExpirationTimeUpdated(oldTime, _expirationTime);
    }

    function setBlacklist(
        address user,
        bool isBlacklisted
    ) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        blacklist[user] = isBlacklisted;
        emit BlacklistUpdated(user, isBlacklisted);
    }

    function batchSetBlacklist(
        address[] calldata users,
        bool[] calldata isBlacklisted
    ) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        if (users.length != isBlacklisted.length) {
            revert MarketplaceErrors.ArrayLengthMismatch();
        }
        for (uint256 i = 0; i < users.length; i++) {
            blacklist[users[i]] = isBlacklisted[i];
            emit BlacklistUpdated(users[i], isBlacklisted[i]);
        }
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function emergencyWithdraw() external onlyRole(EMERGENCY_ROLE) {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool sent, ) = feeRecipient.call{value: balance}("");
            if (!sent) {
                revert MarketplaceErrors.FeeTransferFailed();
            }
            emit EmergencyWithdraw(feeRecipient, balance);
        }
    }

    /**
     * @notice Recover accidentally sent ERC20 tokens
     * @dev Only EMERGENCY_ROLE can call this function
     * @param token The ERC20 token address to recover
     * @param to The address to send recovered tokens to
     */
    function recoverERC20(
        address token,
        address to
    ) external onlyRole(EMERGENCY_ROLE) {
        if (to == address(0)) {
            revert MarketplaceErrors.InvalidAddress();
        }
        if (to == address(this)) {
            revert MarketplaceErrors.InvalidAddress();
        }
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        if (balance > 0) {
            tokenContract.transfer(to, balance);
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {
        revert MarketplaceErrors.DirectETHTransferNotAllowed();
    }
}
