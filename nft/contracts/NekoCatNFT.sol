// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/INekoCatNFT.sol";
import "./interfaces/INekoStaking.sol";
import "./interfaces/IDepositManager.sol";
import "./lib/NekoCatConstants.sol";
import "./lib/NekoCatErrors.sol";
import "./lib/NekoCatHelpers.sol";
import "./lib/MetadataGenerator.sol";

/**
 * @title NekoCatNFT
 * @dev Living NFT system with feeding, death, revival, and immortality mechanics
 * @notice Simplified system - only Food NFT feeding, no time slots
 */
contract NekoCatNFT is
    ERC721,
    ERC721Enumerable,
    Ownable,
    Pausable,
    ReentrancyGuard,
    INekoCatNFT
{
    using Strings for uint256;

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    // Contract addresses
    address public depositManager;
    address public stakingContract;
    address public foodNFTContract;
    address public foodMenu;

    // Metadata URI
    string private _baseTokenURI;
    string private _imageBaseURI;

    // Token tracking
    uint256 private _nextTokenId = 1;
    uint256 public totalCatsMinted = 0;

    // Cat data storage
    mapping(uint256 => CatMetadata) public catMetadata;
    mapping(uint256 => CatState) public catState;

    // Commit-reveal random system
    mapping(address => bytes32) public userCommits;
    mapping(address => uint256) public commitTimestamps;

    // Character type counts for efficient stats
    mapping(CharacterType => uint256) public characterTypeCounts;

    // Variant supply tracking for rarity calculation
    mapping(CharacterType => mapping(uint8 => uint256)) public variantSupply;

    // Admin configurable immortality threshold
    uint256 public immortalityThreshold = 20_000_000 * 10 ** 18; // 20M NEKO

    // FIFO tracking for immortal NFTs per user
    mapping(address => uint256[]) public userImmortalNFTs;

    // Events
    event CatMinted(
        uint256 indexed tokenId,
        address indexed owner,
        CharacterType characterType,
        uint8 variant,
        uint8 level
    );
    event CatFed(
        uint256 indexed tokenId,
        address indexed owner,
        uint8 newLevel,
        uint256 totalFeeds
    );
    event CatDied(uint256 indexed tokenId, address indexed owner);
    event CatRevived(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 cost
    );
    event CatBecameImmortal(uint256 indexed tokenId, address indexed owner);
    event ImmortalityRemoved(uint256 indexed tokenId, address indexed owner);
    event BaseURIUpdated(string newBaseURI);
    event ImmortalityThresholdUpdated(uint256 newThreshold);
    event RandomCommitted(address indexed user, bytes32 commitHash);

    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================

    constructor(
        address _depositManager
    ) ERC721("NekoCat Living NFT", "NEKOCAT") Ownable(msg.sender) {
        depositManager = _depositManager;
        stakingContract = address(0); // Will be set later by admin
        _baseTokenURI = "https://ipfs.io/ipfs/QmYourMetadataHash/"; // Default, can be updated via updateBaseURI
        _imageBaseURI = "ipfs://QmYourIPFSHash/"; // Default, can be updated via updateImageBaseURI
    }

    // =============================================================================
    // MODIFIERS
    // =============================================================================

    modifier onlyDepositManager() {
        require(msg.sender == depositManager, "Only deposit manager");
        _;
    }

    modifier onlyFoodNFT() {
        require(msg.sender == foodNFTContract, "Only food NFT contract");
        _;
    }

    modifier onlyStakingContract() {
        require(msg.sender == stakingContract, "Only staking contract");
        _;
    }

    // =============================================================================
    // COMMIT-REVEAL FUNCTIONS
    // =============================================================================

    /**
     * @dev Commit random hash for commit-reveal scheme (optional)
     * @notice Commit is optional - users can mint directly without commit
     */
    function commitRandom(bytes32 commitHash) external {
        require(commitHash != bytes32(0), "Invalid commit hash");

        // Check if there's an active commit that hasn't expired (5 minutes timeout - reduced for better UX)
        if (userCommits[msg.sender] != bytes32(0)) {
            require(
                block.timestamp >= commitTimestamps[msg.sender] + 5 minutes,
                "Previous commit still active"
            );
        }

        userCommits[msg.sender] = commitHash;
        commitTimestamps[msg.sender] = block.timestamp;

        emit RandomCommitted(msg.sender, commitHash);
    }

    /**
     * @dev Check if user can reveal their random value
     */
    function canReveal(address user) external view returns (bool) {
        // No delay - can reveal immediately after commit
        return userCommits[user] != bytes32(0);
    }

    // =============================================================================
    // MINTING FUNCTIONS
    // =============================================================================

    /**
     * @dev Mint a new NekoCat NFT (interface compatible)
     * @param nonce Random nonce for commit-reveal (use 0 if no commit)
     * @param randomSecret Random secret for character/variant selection (use blockhash if no commit)
     * @notice Commit-reveal is optional. If no commit exists, uses block-based randomness
     */
    function mintCat(
        uint256 nonce,
        bytes32 randomSecret
    ) external payable whenNotPaused nonReentrant returns (uint256) {
        uint256 mintPrice = IDepositManager(depositManager).getMintPrice();
        if (msg.value != mintPrice) {
            revert NekoCatErrors.InsufficientMintPayment();
        }

        bytes32 userCommit = userCommits[msg.sender];
        bytes32 finalRandomSecret = randomSecret;
        uint256 finalNonce = nonce;

        // If user has a commit, validate it
        if (userCommit != bytes32(0)) {
            // Can reveal immediately after commit (no delay)
            // Check commit hasn't expired (24 hours)
            require(
                block.timestamp <= commitTimestamps[msg.sender] + 24 hours,
                "Commit expired"
            );

            // Validate reveal
            bytes32 expectedCommit = keccak256(
                abi.encodePacked(msg.sender, nonce, randomSecret)
            );
            require(userCommit == expectedCommit, "Invalid reveal");

            // Clear the commit after successful reveal
            delete userCommits[msg.sender];
            delete commitTimestamps[msg.sender];
        } else {
            // No commit - use block-based randomness for easier minting
            // Combine block data with sender address for randomness
            finalRandomSecret = keccak256(
                abi.encodePacked(
                    blockhash(block.number - 1),
                    block.timestamp,
                    msg.sender,
                    block.prevrandao
                )
            );
            finalNonce = block.timestamp;
        }

        uint256 tokenId = _nextTokenId++;
        totalCatsMinted++;

        // Generate character type and variant from random secret
        uint8 characterTypeNum = NekoCatHelpers.generateCharacterType(
            finalRandomSecret,
            finalNonce
        );
        uint8 variant = NekoCatHelpers.generateVariant(
            finalRandomSecret,
            finalNonce
        );

        CharacterType characterType = CharacterType(characterTypeNum);

        // Initialize cat metadata
        catMetadata[tokenId] = CatMetadata({
            characterType: characterType,
            variant: variant,
            level: 0,
            mintTimestamp: block.timestamp,
            totalFeeds: 0
        });

        // Initialize cat state
        catState[tokenId] = CatState({
            isAlive: true,
            isImmortal: false,
            livesRemaining: NekoCatConstants.MAX_LIVES,
            lastFedTimestamp: block.timestamp,
            reviveCount: 0
        });

        // Increment character type count
        characterTypeCounts[characterType]++;

        // Increment variant supply for rarity calculation
        variantSupply[characterType][variant]++;

        // Process payment through deposit manager
        IDepositManager(depositManager).processMintPayment{value: msg.value}(
            msg.sender,
            mintPrice
        );

        // Mint NFT
        _safeMint(msg.sender, tokenId);

        emit CatMinted(tokenId, msg.sender, characterType, variant, 0);
        return tokenId;
    }

    /**
     * @dev Simple mint function - no commit-reveal needed
     * @notice Easiest way to mint - just send ETH, randomness is handled automatically
     */
    function mintCatSimple()
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        uint256 mintPrice = IDepositManager(depositManager).getMintPrice();
        if (msg.value != mintPrice) {
            revert NekoCatErrors.InsufficientMintPayment();
        }

        // Use block-based randomness (no commit needed)
        bytes32 randomSecret = keccak256(
            abi.encodePacked(
                blockhash(block.number - 1),
                block.timestamp,
                msg.sender,
                block.prevrandao,
                totalCatsMinted
            )
        );
        uint256 nonce = block.timestamp;

        uint256 tokenId = _nextTokenId++;
        totalCatsMinted++;

        // Generate character type and variant from random secret
        uint8 characterTypeNum = NekoCatHelpers.generateCharacterType(
            randomSecret,
            nonce
        );
        uint8 variant = NekoCatHelpers.generateVariant(randomSecret, nonce);

        CharacterType characterType = CharacterType(characterTypeNum);

        // Initialize cat metadata
        catMetadata[tokenId] = CatMetadata({
            characterType: characterType,
            variant: variant,
            level: 0,
            mintTimestamp: block.timestamp,
            totalFeeds: 0
        });

        // Initialize cat state
        catState[tokenId] = CatState({
            isAlive: true,
            isImmortal: false,
            livesRemaining: NekoCatConstants.MAX_LIVES,
            lastFedTimestamp: block.timestamp,
            reviveCount: 0
        });

        // Increment character type count
        characterTypeCounts[characterType]++;

        // Increment variant supply for rarity calculation
        variantSupply[characterType][variant]++;

        // Process payment through deposit manager
        IDepositManager(depositManager).processMintPayment{value: msg.value}(
            msg.sender,
            mintPrice
        );

        // Mint NFT
        _safeMint(msg.sender, tokenId);

        emit CatMinted(tokenId, msg.sender, characterType, variant, 0);
        return tokenId;
    }

    // =============================================================================
    // FEEDING FUNCTIONS
    // =============================================================================

    /**
     * @dev Feed a cat directly with payment (for testing and simple feeding)
     * @param catTokenId Cat token ID
     */
    function feedCat(
        uint256 catTokenId
    ) external payable whenNotPaused nonReentrant {
        uint256 feedingCost = IDepositManager(depositManager).getFeedingCost();
        if (msg.value != feedingCost) {
            revert NekoCatErrors.InsufficientFeedingPayment(
                feedingCost,
                msg.value
            );
        }

        // Process payment through deposit manager
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = catTokenId;
        IDepositManager(depositManager).processFeedingPayment{value: msg.value}(
            msg.sender,
            tokenIds,
            feedingCost
        );

        // Process the feeding
        _processFeed(catTokenId);
    }

    /**
     * @dev Feed a cat with food NFT (called by food contract)
     * @param catTokenId Cat token ID
     * @param xpGain XP amount to add (calculated by food contract with bonuses)
     */
    function feedCatWithFoodNFT(
        uint256 catTokenId,
        uint16 xpGain
    ) external onlyFoodNFT whenNotPaused nonReentrant {
        _processFeed(catTokenId, xpGain);
    }

    // =============================================================================
    // DEATH AND REVIVAL FUNCTIONS
    // =============================================================================

    /**
     * @dev Check if cat should die
     * @param tokenId Cat token ID
     */
    function checkDeath(uint256 tokenId) external {
        _requireTokenExists(tokenId);
        require(catState[tokenId].isAlive, "Cat is already dead");

        // Immortal cats cannot die
        if (catState[tokenId].isImmortal) {
            return;
        }

        // Simple death check - if not fed for 48 hours, cat dies
        if (NekoCatHelpers.isCatDead(catState[tokenId].lastFedTimestamp)) {
            catState[tokenId].isAlive = false;
            catState[tokenId].livesRemaining--;

            emit CatDied(tokenId, _ownerOf(tokenId));

            // Burn NFT if no lives remaining
            if (catState[tokenId].livesRemaining == 0) {
                _burn(tokenId);
            }
        }
    }

    /**
     * @dev Revive a dead cat
     * @param tokenId Cat token ID
     */
    function reviveCat(
        uint256 tokenId
    ) external payable whenNotPaused nonReentrant {
        _requireTokenExists(tokenId);

        // Check if cat needs death check first (timeUntilDeath might be 0 but isAlive still true)
        if (catState[tokenId].isAlive) {
            // Check if cat is actually dead by time calculation
            if (NekoCatHelpers.isCatDead(catState[tokenId].lastFedTimestamp)) {
                // Cat is dead by time but state not updated - update it
                catState[tokenId].isAlive = false;
                catState[tokenId].livesRemaining--;

                // If no lives remaining, cannot revive
                if (catState[tokenId].livesRemaining == 0) {
                    revert NekoCatErrors.NoLivesRemaining();
                }
            } else {
                // Cat is actually alive
                revert NekoCatErrors.CatIsAlive();
            }
        }

        if (catState[tokenId].livesRemaining == 0) {
            revert NekoCatErrors.NoLivesRemaining();
        }

        // FIXED: Use reviveCount instead of level for cost calculation
        uint256 revivalCost = IDepositManager(depositManager).getRevivalCost(
            catState[tokenId].reviveCount
        );
        if (msg.value != revivalCost) {
            revert NekoCatErrors.InsufficientRevivalPayment(
                revivalCost,
                msg.value
            );
        }

        // Simple revival - just make cat alive again
        catState[tokenId].isAlive = true;
        catState[tokenId].reviveCount++;

        // FIXED: Use reviveCount instead of level for payment processing
        IDepositManager(depositManager).processRevivalPayment{value: msg.value}(
            msg.sender,
            tokenId,
            catState[tokenId].reviveCount - 1, // Use reviveCount before increment (current revive count)
            revivalCost
        );

        emit CatRevived(tokenId, _ownerOf(tokenId), revivalCost);
    }

    /**
     * @dev Batch revive multiple cats
     * @param tokenIds Array of cat token IDs
     */
    function batchReviveCats(
        uint256[] calldata tokenIds
    ) external payable whenNotPaused nonReentrant {
        require(tokenIds.length > 0, "No cats to revive");

        uint256 totalCost = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            _requireTokenExists(tokenId);

            // Check if cat needs death check first
            if (catState[tokenId].isAlive) {
                if (
                    NekoCatHelpers.isCatDead(catState[tokenId].lastFedTimestamp)
                ) {
                    catState[tokenId].isAlive = false;
                    catState[tokenId].livesRemaining--;
                } else {
                    revert("Cat is already alive");
                }
            }

            require(!catState[tokenId].isAlive, "Cat is already alive");
            require(
                catState[tokenId].livesRemaining > 0,
                "Cat has no lives left"
            );

            // FIXED: Use reviveCount instead of level for cost calculation
            totalCost += IDepositManager(depositManager).getRevivalCost(
                catState[tokenId].reviveCount
            );
        }

        require(msg.value == totalCost, "Exact payment required");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            // Simple revival - just make cat alive again
            catState[tokenId].isAlive = true;
            uint8 currentReviveCount = catState[tokenId].reviveCount;
            catState[tokenId].reviveCount++;

            emit CatRevived(
                tokenId,
                _ownerOf(tokenId),
                IDepositManager(depositManager).getRevivalCost(
                    currentReviveCount
                )
            );
        }

        // Process payment - use average reviveCount for batch (or 0 as placeholder)
        IDepositManager(depositManager).processRevivalPayment{value: msg.value}(
            msg.sender,
            0, // Batch operation
            0, // reviveCount not applicable for batch (individual costs already calculated)
            totalCost
        );
    }

    // =============================================================================
    // IMMORTALITY FUNCTIONS
    // =============================================================================

    /**
     * @dev Use immortality for a cat
     * @param tokenId Cat token ID
     */
    function useImmortality(uint256 tokenId) external {
        _requireTokenExists(tokenId);
        CatState storage state = catState[tokenId];
        require(state.isAlive, "Cat must be alive");
        require(!state.isImmortal, "Cat is already immortal");

        address owner = _ownerOf(tokenId);
        require(owner == msg.sender, "Not the owner");

        // Get current stake amount and calculate available slots
        uint256 stakedAmount = INekoStaking(stakingContract).getStakedAmount(
            owner
        );
        uint256 maxImmortalNFTs = NekoCatHelpers.calculateMaxImmortalNFTs(stakedAmount, immortalityThreshold);
        require(
            userImmortalNFTs[owner].length < maxImmortalNFTs,
            "No available immortality slots"
        );

        state.isImmortal = true;
        userImmortalNFTs[owner].push(tokenId);
        emit CatBecameImmortal(tokenId, owner);
    }

    /**
     * @dev Internal function to remove immortality from an NFT
     * @param tokenId Cat token ID
     * @param owner Owner address
     * @param removeFromList Whether to remove from FIFO list (false for syncImmortality FIFO removal)
     */
    function _removeImmortalityInternal(
        uint256 tokenId,
        address owner,
        bool removeFromList
    ) internal {
        catState[tokenId].isImmortal = false;

        if (removeFromList) {
            // Remove from FIFO list (optimized: swap with last and pop)
            uint256[] storage immortalList = userImmortalNFTs[owner];
            uint256 listLength = immortalList.length;
            for (uint256 i = 0; i < listLength; i++) {
                if (immortalList[i] == tokenId) {
                    // Swap with last element and pop (gas efficient)
                    immortalList[i] = immortalList[listLength - 1];
                    immortalList.pop();
                    break;
                }
            }
        }

        emit ImmortalityRemoved(tokenId, owner);
    }

    /**
     * @dev Sync immortality based on current stake (removes excess immortal NFTs in FIFO order)
     * @param user User address to sync
     * @notice Only callable by staking contract
     */
    function syncImmortality(address user) external onlyStakingContract {
        uint256 stakedAmount = INekoStaking(stakingContract).getStakedAmount(
            user
        );
        uint256 maxImmortalNFTs = NekoCatHelpers.calculateMaxImmortalNFTs(stakedAmount, immortalityThreshold);
        uint256[] storage immortalList = userImmortalNFTs[user];

        // Remove excess immortal NFTs in FIFO order (first in, first out)
        while (immortalList.length > maxImmortalNFTs) {
            uint256 tokenIdToRemove = immortalList[0];

            // Remove immortality (don't remove from list here, we'll do it manually for FIFO)
            _removeImmortalityInternal(tokenIdToRemove, user, false);

            // Remove from list (FIFO - remove first element by shifting left)
            uint256 listLength = immortalList.length;
            for (uint256 i = 0; i < listLength - 1; i++) {
                immortalList[i] = immortalList[i + 1];
            }
            immortalList.pop();
        }
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    /**
     * @dev Get comprehensive cat information
     */
    function getCatInfo(
        uint256 tokenId
    )
        external
        view
        returns (
            CatMetadata memory metadata,
            CatState memory state,
            bool isDead,
            uint256 timeUntilDeath
        )
    {
        _requireTokenExists(tokenId);
        metadata = catMetadata[tokenId];
        state = catState[tokenId];
        (isDead, timeUntilDeath) = NekoCatHelpers.calculateCatInfo(
            state.isAlive,
            state.lastFedTimestamp
        );
    }


    /**
     * @dev Get mint statistics
     */
    function getMintStats()
        external
        view
        returns (
            uint256 totalMinted,
            uint256 ninjaCount,
            uint256 sumoCount,
            uint256 samuraiCount,
            uint256 geishaCount,
            uint256 remaining
        )
    {
        totalMinted = totalCatsMinted;
        remaining = NekoCatConstants.MAX_SUPPLY - totalMinted;

        // Get character type counts from optimized mappings
        ninjaCount = characterTypeCounts[CharacterType.Ninja];
        sumoCount = characterTypeCounts[CharacterType.Sumo];
        samuraiCount = characterTypeCounts[CharacterType.Samurai];
        geishaCount = characterTypeCounts[CharacterType.Geisha];
    }

    /**
     * @dev Get XP requirements for each level
     */
    function getXPRequirements() external pure returns (uint16[7] memory) {
        return NekoCatHelpers.getXPRequirements();
    }

    /**
     * @dev Check if user can use immortality (has available slot)
     */
    function canUseImmortality(address holder) external view returns (bool) {
        uint256 stakedAmount = INekoStaking(stakingContract).getStakedAmount(
            holder
        );
        return NekoCatHelpers.canUseImmortalityHelper(
            userImmortalNFTs[holder].length,
            stakedAmount,
            immortalityThreshold
        );
    }


    /**
     * @dev Get user's immortal NFTs (FIFO order)
     * @param holder User address
     * @return tokenIds Array of immortal NFT token IDs
     */
    function getUserImmortalNFTs(
        address holder
    ) external view returns (uint256[] memory tokenIds) {
        return userImmortalNFTs[holder];
    }

    /**
     * @dev Check if NFT is immortal
     */
    function isNFTImmortal(uint256 tokenId) external view returns (bool) {
        _requireTokenExists(tokenId);
        return catState[tokenId].isImmortal;
    }

    /**
     * @dev Get multiple cats information
     */
    function getMultipleCatsInfo(
        uint256[] calldata tokenIds
    )
        external
        view
        returns (
            CatMetadata[] memory metadataArray,
            CatState[] memory stateArray,
            bool[] memory isDeadArray,
            uint256[] memory timeUntilDeathArray
        )
    {
        uint256 length = tokenIds.length;
        metadataArray = new CatMetadata[](length);
        stateArray = new CatState[](length);
        bool[] memory isAliveArray = new bool[](length);
        uint256[] memory lastFedTimestampArray = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = tokenIds[i];
            _requireTokenExists(tokenId);

            metadataArray[i] = catMetadata[tokenId];
            stateArray[i] = catState[tokenId];
            isAliveArray[i] = stateArray[i].isAlive;
            lastFedTimestampArray[i] = stateArray[i].lastFedTimestamp;
        }

        // Use library function for batch calculation
        (isDeadArray, timeUntilDeathArray) = NekoCatHelpers
            .calculateMultipleCatInfos(isAliveArray, lastFedTimestampArray);
    }

    /**
     * @dev Get all cats owned by a user
     */
    function getUserAllCats(
        address user
    ) external view returns (uint256[] memory tokenIds) {
        uint256 balance = balanceOf(user);
        tokenIds = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(user, i);
        }
    }

    /**
     * @dev Check if cat can be fed
     * @param tokenId Cat token ID
     * @return canFeed True if cat can be fed
     */
    function canFeedCat(uint256 tokenId) external view returns (bool canFeed) {
        _requireTokenExists(tokenId);
        CatState memory state = catState[tokenId];
        return NekoCatHelpers.canFeedCat(state.isAlive, state.lastFedTimestamp);
    }

    /**
     * @dev Get multiple cats feeding status
     */
    function getMultipleFeedingStatus(
        uint256[] calldata tokenIds
    )
        external
        view
        returns (
            bool[] memory isAliveArray,
            uint256[] memory lastFedArray,
            bool[] memory canFeedArray
        )
    {
        uint256 length = tokenIds.length;
        isAliveArray = new bool[](length);
        lastFedArray = new uint256[](length);
        bool[] memory tempIsAliveArray = new bool[](length);
        uint256[] memory tempLastFedArray = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = tokenIds[i];
            _requireTokenExists(tokenId);

            CatState memory state = catState[tokenId];
            isAliveArray[i] = state.isAlive;
            lastFedArray[i] = state.lastFedTimestamp;
            tempIsAliveArray[i] = state.isAlive;
            tempLastFedArray[i] = state.lastFedTimestamp;
        }

        // Use library function for batch calculation
        canFeedArray = NekoCatHelpers.calculateMultipleFeedingStatuses(
            tempIsAliveArray,
            tempLastFedArray
        );
    }

    /**
     * @dev Internal function to process feeding logic
     * @param tokenId Cat token ID
     * @param xpGain XP amount to add (default 1 for basic feed, calculated for food NFT)
     */
    function _processFeed(uint256 tokenId, uint16 xpGain) internal {
        _requireTokenExists(tokenId);
        require(catState[tokenId].isAlive, "Cat is not alive");

        // Add XP (xpGain can be > 1 for food NFTs with bonuses)
        catMetadata[tokenId].totalFeeds += xpGain;
        catState[tokenId].lastFedTimestamp = block.timestamp;

        // Level up based on XP requirements
        uint8 newLevel = NekoCatHelpers.calculateLevel(
            catMetadata[tokenId].totalFeeds
        );
        if (newLevel > catMetadata[tokenId].level) {
            catMetadata[tokenId].level = newLevel;
        }

        emit CatFed(
            tokenId,
            _ownerOf(tokenId),
            catMetadata[tokenId].level,
            catMetadata[tokenId].totalFeeds
        );
    }

    /**
     * @dev Internal function to process feeding logic (overload for basic feed - 1 XP)
     * @param tokenId Cat token ID
     */
    function _processFeed(uint256 tokenId) internal {
        _processFeed(tokenId, 1);
    }

    /**
     * @dev Process single feed (for batch operations)
     */
    function processSingleFeed(uint256 tokenId) external {
        _processFeed(tokenId);
    }

    // =============================================================================
    // ADMIN FUNCTIONS
    // =============================================================================

    /**
     * @dev Set staking contract address
     */
    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "Invalid address");
        stakingContract = _stakingContract;
    }

    /**
     * @dev Set deposit manager address
     */
    function setDepositManager(address _depositManager) external onlyOwner {
        require(_depositManager != address(0), "Invalid address");
        depositManager = _depositManager;
    }

    /**
     * @dev Set food NFT contract address
     */
    function setFoodNFTContract(address _foodNFTContract) external onlyOwner {
        require(_foodNFTContract != address(0), "Invalid address");
        foodNFTContract = _foodNFTContract;
    }

    /**
     * @dev Set food menu address
     * @param _foodMenu Food menu contract address
     */
    function setFoodMenu(address _foodMenu) external onlyOwner {
        require(_foodMenu != address(0), "Invalid address");
        foodMenu = _foodMenu;
    }

    /**
     * @dev Set immortality threshold
     */
    function setImmortalityThreshold(uint256 _threshold) external onlyOwner {
        require(_threshold > 0, "Threshold must be > 0");
        immortalityThreshold = _threshold;
        emit ImmortalityThresholdUpdated(_threshold);
    }

    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Withdraw funds
     * @param amount Amount to withdraw (0 = withdraw all)
     */
    function withdraw(uint256 amount) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        if (amount == 0) {
            amount = balance; // Withdraw all if 0 specified
        }

        require(amount <= balance, "Insufficient balance");

        (bool success, ) = owner().call{value: amount}("");
        require(success, "Transfer failed");
    }

    // =============================================================================
    // VIEW FUNCTIONS (EXISTING)
    // =============================================================================

    /**
     * @dev Get mint price
     */
    function getMintPrice() external view returns (uint256) {
        return IDepositManager(depositManager).getMintPrice();
    }

    /**
     * @dev Get cat metadata
     */
    function getCatMetadata(
        uint256 tokenId
    ) external view returns (CatMetadata memory) {
        _requireTokenExists(tokenId);
        return catMetadata[tokenId];
    }

    /**
     * @dev Get cat state
     */
    function getCatState(
        uint256 tokenId
    ) external view returns (CatState memory) {
        _requireTokenExists(tokenId);
        return catState[tokenId];
    }

    /**
     * @dev Get base URI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Update base URI
     */
    function updateBaseURI(string memory newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @dev Update image base URI
     * @notice Used for on-chain metadata to construct image URLs
     */
    function updateImageBaseURI(
        string memory newImageBaseURI
    ) external onlyOwner {
        _imageBaseURI = newImageBaseURI;
        emit BaseURIUpdated(newImageBaseURI);
    }

    /**
     * @dev Get token URI with dynamic on-chain metadata
     * @notice Returns data URI with JSON metadata that updates based on current level
     * @notice Image path updates automatically when level changes
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _requireOwned(tokenId);

        CatMetadata memory metadata = catMetadata[tokenId];
        CatState memory state = catState[tokenId];

        // Build image path based on current level
        string memory imagePath = MetadataGenerator.buildImagePath(
            metadata.characterType,
            metadata.variant,
            metadata.level
        );

        // Construct full image URL
        string memory imageUrl = string(
            abi.encodePacked(_imageBaseURI, imagePath)
        );

        // Generate metadata JSON
        string memory json = MetadataGenerator.generateMetadataJson(
            tokenId,
            metadata,
            state,
            metadata.level,
            imageUrl
        );

        // Return as data URI (base64 encoded)
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    MetadataGenerator.base64Encode(bytes(json))
                )
            );
    }

    // =============================================================================
    // OVERRIDE FUNCTIONS
    // =============================================================================

    function balanceOf(
        address owner
    ) public view override(ERC721, IERC721, INekoCatNFT) returns (uint256) {
        return super.balanceOf(owner);
    }

    function ownerOf(
        uint256 tokenId
    ) public view override(ERC721, IERC721, INekoCatNFT) returns (address) {
        return super.ownerOf(tokenId);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        address from = _ownerOf(tokenId);
        address newOwner = super._update(to, tokenId, auth);

        // If NFT is being transferred and it's immortal, remove immortality
        // Immortality right stays with the staker, not the NFT
        if (from != address(0) && to != from && catState[tokenId].isImmortal) {
            _removeImmortalityInternal(tokenId, from, true);
        }

        return newOwner;
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // =============================================================================
    // INTERNAL HELPER FUNCTIONS
    // =============================================================================

    /**
     * @dev Internal function to check if token exists
     */
    function _requireTokenExists(uint256 tokenId) internal view {
        require(_ownerOf(tokenId) != address(0), "Cat does not exist");
    }

    // =============================================================================
    // UTILITY FUNCTIONS
    // =============================================================================

    /**
     * @dev Get level progress for a cat
     */
    function getLevelProgress(
        uint256 tokenId
    ) external view returns (uint256 currentXP, uint256 requiredXP) {
        _requireTokenExists(tokenId);
        CatMetadata memory metadata = catMetadata[tokenId];
        return
            NekoCatHelpers.getLevelProgress(
                metadata.totalFeeds,
                metadata.level
            );
    }

    /**
     * @dev Get XP required for next level
     */
    function getXPRequiredForNextLevel(
        uint256 tokenId
    ) external view returns (uint256) {
        _requireTokenExists(tokenId);
        return
            NekoCatHelpers.getXPRequiredForNextLevel(
                catMetadata[tokenId].level
            );
    }

    /**
     * @dev Get rarity score for a cat
     */
    function getRarityScore(uint256 tokenId) external view returns (uint256) {
        _requireTokenExists(tokenId);
        CatMetadata memory metadata = catMetadata[tokenId];
        CatState memory state = catState[tokenId];

        // Get variant supply and character type supply for rarity calculation
        uint256 variantSupplyCount = variantSupply[metadata.characterType][
            metadata.variant
        ];
        uint256 characterTypeSupplyCount = characterTypeCounts[
            metadata.characterType
        ];

        return
            NekoCatHelpers.calculateRarityScore(
                metadata,
                state,
                variantSupplyCount,
                characterTypeSupplyCount
            );
    }

    /**
     * @dev Get time until next feed is allowed
     */
    function getTimeUntilNextFeed(
        uint256 tokenId
    ) external view returns (uint256) {
        _requireTokenExists(tokenId);
        CatState memory state = catState[tokenId];
        return
            NekoCatHelpers.getTimeUntilNextFeed(
                state.isAlive,
                state.lastFedTimestamp
            );
    }
}
