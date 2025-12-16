// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/INekoCatFood.sol";
import "./interfaces/IDepositManager.sol";
import "./interfaces/INekoCatNFT.sol";

/**
 * @title NekoCatFood
 * @dev Food NFTs that are burned when fed to cats
 * @notice These NFTs are non-transferable and single-use
 *
 * Key Features:
 * - Non-transferable (soulbound until consumed)
 * - Burns on feeding
 * - Provides XP to cats
 * - Multiple food types with different effects
 */
contract NekoCatFood is
    ERC721,
    ERC721Enumerable,
    Ownable,
    Pausable,
    ReentrancyGuard,
    INekoCatFood
{
    // ============ Structs ============

    struct FoodType {
        string name;
        string description;
        uint16 baseXP;
        uint16[4] characterBonus; // [Geisha, Ninja, Samurai, Sumo]
        uint8[3] timeSlotBonus; // [Morning, Afternoon, Evening]
        bool isActive;
        uint256 mintPrice; // Price in USD (scaled by 1e8)
        string imageURI;
    }

    struct FoodNFT {
        uint256 foodTypeId;
        uint256 mintedAt;
        bool isConsumed;
    }

    // ============ State Variables ============

    uint256 private _nextTokenId;
    uint256 private _nextFoodTypeId;

    address public nekoCatNFTContract;
    address public depositManager;

    string private _baseTokenURI;

    mapping(uint256 => FoodType) public foodTypes;
    mapping(uint256 => FoodNFT) public foodNFTs;
    mapping(address => mapping(uint256 => uint256)) public userFoodsByTypeCount; // user => foodTypeId => count
    mapping(address => mapping(uint256 => mapping(uint256 => uint256)))
        public userFoodsByType; // user => foodTypeId => index => tokenId

    // Special event management
    bool public specialEventActive;
    uint256 public specialEventMultiplier = 100; // 100 = 1x, 200 = 2x

    // ============ Events ============

    event FoodTypeMinted(
        address indexed minter,
        uint256 indexed tokenId,
        uint256 indexed foodTypeId,
        string name
    );

    event FoodConsumed(
        uint256 indexed tokenId,
        uint256 indexed catTokenId,
        address indexed owner,
        uint16 creditScoreGained
    );

    event FoodTypeAdded(
        uint256 indexed foodTypeId,
        string name,
        uint16 baseXP,
        uint256 mintPrice
    );

    event FoodTypeUpdated(
        uint256 indexed foodTypeId,
        string name,
        uint16 baseXP,
        uint256 mintPrice
    );

    event FoodTypeDeactivated(uint256 indexed foodTypeId);
    event FoodTypeActivated(uint256 indexed foodTypeId);

    event SpecialEventToggled(bool active, uint256 multiplier);
    event FoodTypePriceUpdated(
        uint256 indexed foodTypeId,
        uint256 oldPrice,
        uint256 newPrice
    );
    event BatchFoodPricesUpdated(uint256[] foodTypeIds, uint256[] newPrices);
    event DepositManagerUpdated(
        address indexed oldManager,
        address indexed newManager
    );
    event AdminWithdrawal(address indexed to, uint256 amount);

    // ============ Errors ============

    error TransferNotAllowed();
    error FoodAlreadyConsumed();
    error FoodTypeNotActive();
    error NotFoodOwner();
    error InvalidFoodType();
    error NotNekoCatContract();
    error InsufficientPayment();

    // ============ Constructor ============

    constructor(
        address _nekoCatNFTContract,
        address _depositManager
    ) ERC721("NekoCat Food", "NEKOFOOD") Ownable(msg.sender) {
        require(_nekoCatNFTContract != address(0), "Invalid NFT contract");
        require(_depositManager != address(0), "Invalid deposit manager");

        nekoCatNFTContract = _nekoCatNFTContract;
        depositManager = _depositManager;

        _nextTokenId = 1;
        _nextFoodTypeId = 0;

        _initializeDefaultFoodTypes();
    }

    // ============ Minting Functions ============

    /**
     * @dev Mint a food NFT
     * @param foodTypeId The type of food to mint
     */
    function mintFood(
        uint256 foodTypeId
    ) external payable whenNotPaused nonReentrant returns (uint256) {
        require(foodTypeId < _nextFoodTypeId, "Invalid food type");

        FoodType memory foodType = foodTypes[foodTypeId];
        require(foodType.isActive, "Food type not active");

        // Verify payment
        if (msg.value < foodType.mintPrice) {
            revert InsufficientPayment();
        }

        // Forward payment to deposit manager
        if (msg.value > 0) {
            IDepositManager(depositManager).processFoodPayment{
                value: msg.value
            }(msg.sender, msg.value);
        }

        uint256 tokenId = _nextTokenId++;

        _mint(msg.sender, tokenId);

        foodNFTs[tokenId] = FoodNFT({
            foodTypeId: foodTypeId,
            mintedAt: block.timestamp,
            isConsumed: false
        });

        userFoodsByTypeCount[msg.sender][foodTypeId]++;
        userFoodsByType[msg.sender][foodTypeId][
            userFoodsByTypeCount[msg.sender][foodTypeId] - 1
        ] = tokenId;

        emit FoodTypeMinted(msg.sender, tokenId, foodTypeId, foodType.name);

        return tokenId;
    }

    /**
     * @dev Batch mint multiple foods
     * @param foodTypeId The type of food to mint
     * @param amount Number of foods to mint
     */
    function batchMintFood(
        uint256 foodTypeId,
        uint256 amount
    ) external payable whenNotPaused nonReentrant returns (uint256[] memory) {
        require(amount > 0 && amount <= 50, "Invalid amount");
        require(foodTypeId < _nextFoodTypeId, "Invalid food type");

        FoodType memory foodType = foodTypes[foodTypeId];
        require(foodType.isActive, "Food type not active");

        uint256 totalCost = foodType.mintPrice * amount;
        if (msg.value < totalCost) {
            revert InsufficientPayment();
        }

        // Forward payment to deposit manager
        if (msg.value > 0) {
            IDepositManager(depositManager).processFoodPayment{
                value: msg.value
            }(msg.sender, msg.value);
        }

        uint256[] memory tokenIds = new uint256[](amount);

        userFoodsByTypeCount[msg.sender][foodTypeId] += amount;

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _nextTokenId++;

            _mint(msg.sender, tokenId);

            foodNFTs[tokenId] = FoodNFT({
                foodTypeId: foodTypeId,
                mintedAt: block.timestamp,
                isConsumed: false
            });

            // Add to userFoodsByType mapping
            uint256 currentCount = userFoodsByTypeCount[msg.sender][foodTypeId];
            userFoodsByType[msg.sender][foodTypeId][
                currentCount - amount + i
            ] = tokenId;

            tokenIds[i] = tokenId;

            emit FoodTypeMinted(msg.sender, tokenId, foodTypeId, foodType.name);
        }

        return tokenIds;
    }

    // ============ Feeding Functions ============

    /**
     * @dev Consume food to feed a cat (called by user or NekoCat contract)
     * @param foodTokenId The food NFT to consume
     * @param catTokenId The cat to feed
     * @param characterType Cat's character type
     * @param timeSlot Current feeding time slot
     */
    function consumeFood(
        uint256 foodTokenId,
        uint256 catTokenId,
        uint8 characterType,
        uint8 timeSlot
    ) external nonReentrant returns (uint16 creditScoreGained) {
        _requireOwned(foodTokenId);

        address owner = ownerOf(foodTokenId);

        // Only owner or NekoCat contract can consume
        require(
            msg.sender == owner || msg.sender == nekoCatNFTContract,
            "Not authorized"
        );

        FoodNFT storage foodNFT = foodNFTs[foodTokenId];

        if (foodNFT.isConsumed) {
            revert FoodAlreadyConsumed();
        }

        // Calculate Credit Score
        creditScoreGained = calculateCreditScore(
            foodNFT.foodTypeId,
            characterType,
            timeSlot
        );

        // Mark as consumed
        foodNFT.isConsumed = true;

        // Burn the food NFT
        _burn(foodTokenId);

        // Feed the cat by calling NekoCatNFT contract with calculated XP
        // This must be called from food contract to satisfy onlyFoodNFT modifier
        // Pass the calculated creditScoreGained as XP to add to the cat
        INekoCatNFT(nekoCatNFTContract).feedCatWithFoodNFT(catTokenId, creditScoreGained);

        emit FoodConsumed(foodTokenId, catTokenId, owner, creditScoreGained);

        return creditScoreGained;
    }

    /**
     * @dev Calculate Credit Score for feeding
     */
    function calculateCreditScore(
        uint256 foodTypeId,
        uint8 characterType,
        uint8 timeSlot
    ) public view returns (uint16) {
        require(foodTypeId < _nextFoodTypeId, "Invalid food type");
        require(characterType < 4, "Invalid character type");
        require(timeSlot < 3, "Invalid time slot");

        FoodType memory foodType = foodTypes[foodTypeId];

        // Base Credit Score
        uint256 creditScore = foodType.baseXP;

        // Character bonus
        creditScore += foodType.characterBonus[characterType];

        // Time slot bonus (percentage)
        if (foodType.timeSlotBonus[timeSlot] > 0) {
            creditScore =
                (creditScore * (100 + foodType.timeSlotBonus[timeSlot])) /
                100;
        }

        // Special event bonus
        if (specialEventActive) {
            creditScore = (creditScore * specialEventMultiplier) / 100;
        }

        return uint16(creditScore);
    }

    // ============ Food Type Management ============

    /**
     * @dev Add a new food type
     */
    function addFoodType(
        string memory name,
        string memory description,
        uint16 baseXP,
        uint16[4] memory characterBonus,
        uint8[3] memory timeSlotBonus,
        uint256 mintPrice,
        string memory imageURI
    ) external onlyOwner returns (uint256) {
        require(baseXP > 0, "Base XP must be > 0");
        require(bytes(name).length > 0, "Name required");

        uint256 foodTypeId = _nextFoodTypeId++;

        foodTypes[foodTypeId] = FoodType({
            name: name,
            description: description,
            baseXP: baseXP,
            characterBonus: characterBonus,
            timeSlotBonus: timeSlotBonus,
            isActive: true,
            mintPrice: mintPrice,
            imageURI: imageURI
        });

        emit FoodTypeAdded(foodTypeId, name, baseXP, mintPrice);

        return foodTypeId;
    }

    /**
     * @dev Update existing food type
     */
    function updateFoodType(
        uint256 foodTypeId,
        string memory name,
        string memory description,
        uint16 baseXP,
        uint16[4] memory characterBonus,
        uint8[3] memory timeSlotBonus,
        uint256 mintPrice,
        string memory imageURI
    ) external onlyOwner {
        require(foodTypeId < _nextFoodTypeId, "Food type does not exist");
        require(baseXP > 0, "Base XP must be > 0");

        FoodType storage foodType = foodTypes[foodTypeId];
        foodType.name = name;
        foodType.description = description;
        foodType.baseXP = baseXP;
        foodType.characterBonus = characterBonus;
        foodType.timeSlotBonus = timeSlotBonus;
        foodType.mintPrice = mintPrice;
        foodType.imageURI = imageURI;

        emit FoodTypeUpdated(foodTypeId, name, baseXP, mintPrice);
    }

    /**
     * @dev Set food type active status
     */
    function setFoodTypeActive(
        uint256 foodTypeId,
        bool active
    ) external onlyOwner {
        require(foodTypeId < _nextFoodTypeId, "Food type does not exist");
        foodTypes[foodTypeId].isActive = active;
    }

    /**
     * @dev Deactivate food type
     */
    function deactivateFoodType(uint256 foodTypeId) external onlyOwner {
        require(foodTypeId < _nextFoodTypeId, "Food type does not exist");
        foodTypes[foodTypeId].isActive = false;
        emit FoodTypeDeactivated(foodTypeId);
    }

    /**
     * @dev Activate food type
     */
    function activateFoodType(uint256 foodTypeId) external onlyOwner {
        require(foodTypeId < _nextFoodTypeId, "Food type does not exist");
        foodTypes[foodTypeId].isActive = true;
        emit FoodTypeActivated(foodTypeId);
    }

    /**
     * @dev Toggle special event
     */
    function toggleSpecialEvent(
        bool active,
        uint256 multiplier
    ) external onlyOwner {
        specialEventActive = active;
        if (multiplier > 0) {
            specialEventMultiplier = multiplier;
        }
        emit SpecialEventToggled(active, specialEventMultiplier);
    }

    /**
     * @dev Update food type price (admin only)
     */
    function updateFoodTypePrice(
        uint256 foodTypeId,
        uint256 newPrice
    ) external onlyOwner {
        require(foodTypeId < _nextFoodTypeId, "Food type does not exist");
        require(newPrice > 0, "Price must be > 0");
        uint256 oldPrice = foodTypes[foodTypeId].mintPrice;
        foodTypes[foodTypeId].mintPrice = newPrice;
        emit FoodTypePriceUpdated(foodTypeId, oldPrice, newPrice);
    }

    /**
     * @dev Batch update multiple food type prices (admin only)
     * @param foodTypeIds Array of food type IDs to update
     * @param newPrices Array of new prices (must match foodTypeIds length)
     */
    function batchUpdateFoodPrices(
        uint256[] calldata foodTypeIds,
        uint256[] calldata newPrices
    ) external onlyOwner {
        require(
            foodTypeIds.length == newPrices.length,
            "Arrays length mismatch"
        );
        require(foodTypeIds.length > 0, "Empty arrays not allowed");
        require(foodTypeIds.length <= 50, "Too many food types (max 50)");

        // Validate all food type IDs and prices first
        for (uint256 i = 0; i < foodTypeIds.length; i++) {
            require(foodTypeIds[i] < _nextFoodTypeId, "Invalid food type ID");
            require(newPrices[i] <= 10e18, "Price too high (max $10)");
        }

        // Update all prices
        for (uint256 i = 0; i < foodTypeIds.length; i++) {
            uint256 foodTypeId = foodTypeIds[i];
            uint256 oldPrice = foodTypes[foodTypeId].mintPrice;
            foodTypes[foodTypeId].mintPrice = newPrices[i];
            emit FoodTypePriceUpdated(foodTypeId, oldPrice, newPrices[i]);
        }

        // Emit batch update event
        emit BatchFoodPricesUpdated(foodTypeIds, newPrices);
    }

    /**
     * @dev Update deposit manager (admin only)
     */
    function setDepositManager(address newDepositManager) external onlyOwner {
        require(newDepositManager != address(0), "Invalid deposit manager");
        address oldManager = depositManager;
        depositManager = newDepositManager;
        emit DepositManagerUpdated(oldManager, newDepositManager);
    }

    /**
     * @dev Withdraw all funds (admin only)
     */
    function withdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");

        emit AdminWithdrawal(owner(), balance);
    }

    /**
     * @dev Withdraw specific amount (admin only)
     */
    function withdraw(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        require(address(this).balance >= amount, "Insufficient balance");

        (bool success, ) = owner().call{value: amount}("");
        require(success, "Withdrawal failed");

        emit AdminWithdrawal(owner(), amount);
    }

    /**
     * @dev Get the next food type ID (for debugging)
     */
    function getNextFoodTypeId() external view returns (uint256) {
        return _nextFoodTypeId;
    }

    /**
     * @dev Get all active food types
     */
    function getActiveFoodTypes() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < _nextFoodTypeId; i++) {
            if (foodTypes[i].isActive) {
                count++;
            }
        }

        uint256[] memory activeFoods = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < _nextFoodTypeId; i++) {
            if (foodTypes[i].isActive) {
                activeFoods[index] = i;
                index++;
            }
        }

        return activeFoods;
    }

    /**
     * @dev Calculate XP for a food type (interface implementation)
     */
    function calculateXP(
        uint256 foodTypeId,
        uint8 characterType,
        uint8 timeSlot
    ) external view returns (uint16) {
        require(foodTypeId < _nextFoodTypeId, "Invalid food type");
        require(characterType < 4, "Invalid character type");
        require(timeSlot < 3, "Invalid time slot");

        FoodType storage foodType = foodTypes[foodTypeId];
        require(foodType.isActive, "Food type not active");

        uint256 baseXP = foodType.baseXP;

        // Add character bonus
        baseXP += foodType.characterBonus[characterType];

        // Add time slot bonus (percentage)
        if (foodType.timeSlotBonus[timeSlot] > 0) {
            baseXP = (baseXP * (100 + foodType.timeSlotBonus[timeSlot])) / 100;
        }

        // Special event bonus
        if (specialEventActive) {
            baseXP = (baseXP * specialEventMultiplier) / 100;
        }

        return uint16(baseXP);
    }

    /**
     * @dev Get user's food NFTs
     */
    function getUserFoods(
        address user
    ) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(user);
        uint256[] memory tokenIds = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(user, i);
        }

        return tokenIds;
    }

    /**
     * @dev Get user's food NFTs by type (using optimized mapping)
     * @param user User address
     * @param foodTypeId Food type ID
     * @return tokenIds Array of token IDs for the specific food type
     */
    function getUserFoodsByType(
        address user,
        uint256 foodTypeId
    ) external view returns (uint256[] memory tokenIds) {
        uint256 count = userFoodsByTypeCount[user][foodTypeId];
        tokenIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = userFoodsByType[user][foodTypeId][i];
        }

        return tokenIds;
    }

    /**
     * @dev Get food NFT details
     */
    function getFoodDetails(
        uint256 tokenId
    ) external view returns (FoodType memory foodType, FoodNFT memory foodNFT) {
        _requireOwned(tokenId);

        foodNFT = foodNFTs[tokenId];
        foodType = foodTypes[foodNFT.foodTypeId];

        return (foodType, foodNFT);
    }

    /**
     * @dev Get optimal food for character and time
     */
    function getOptimalFood(
        uint8 characterType,
        uint8 timeSlot
    ) external view returns (uint256 foodTypeId, uint16 maxXP) {
        require(characterType < 4, "Invalid character type");
        require(timeSlot < 3, "Invalid time slot");

        maxXP = 0;
        foodTypeId = type(uint256).max;

        for (uint256 i = 0; i < _nextFoodTypeId; i++) {
            if (foodTypes[i].isActive) {
                uint16 creditScore = calculateCreditScore(
                    i,
                    characterType,
                    timeSlot
                );
                if (creditScore > maxXP) {
                    maxXP = creditScore;
                    foodTypeId = i;
                }
            }
        }

        return (foodTypeId, maxXP);
    }

    // ============ Admin Functions ============

    function setNekoCatNFTContract(
        address _nekoCatNFTContract
    ) external onlyOwner {
        require(_nekoCatNFTContract != address(0), "Invalid address");
        nekoCatNFTContract = _nekoCatNFTContract;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ Internal Functions ============

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Override transfer functions to make NFTs non-transferable
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        address from = _ownerOf(tokenId);

        // Allow minting (from = 0) and burning (to = 0)
        // Block all transfers between users
        if (from != address(0) && to != address(0)) {
            revert TransferNotAllowed();
        }

        return super._update(to, tokenId, auth);
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

    /**
     * @dev Internal function to add food type during initialization
     */
    function _addFoodType(
        string memory name,
        string memory description,
        uint16 baseXP,
        uint16[4] memory characterBonus,
        uint8[3] memory timeSlotBonus,
        uint256 mintPrice,
        string memory imageURI
    ) internal returns (uint256) {
        uint256 foodTypeId = _nextFoodTypeId++;

        foodTypes[foodTypeId] = FoodType({
            name: name,
            description: description,
            baseXP: baseXP,
            characterBonus: characterBonus,
            timeSlotBonus: timeSlotBonus,
            isActive: true,
            mintPrice: mintPrice,
            imageURI: imageURI
        });

        emit FoodTypeAdded(foodTypeId, name, baseXP, mintPrice);

        return foodTypeId;
    }

    /**
     * @dev Initialize default food types
     */
    function _initializeDefaultFoodTypes() internal {
        // Miso Soup - Morning special for Geisha
        _addFoodType(
            "Miso Soup",
            "Traditional Japanese breakfast soup",
            10,
            [uint16(5), uint16(0), uint16(0), uint16(0)],
            [uint8(20), uint8(0), uint8(0)],
            25000000000000, // 0.000025 ETH
            ""
        );

        // Sushi - Afternoon special for Ninja
        _addFoodType(
            "Sushi",
            "Fresh sushi rolls for agile cats",
            12,
            [uint16(0), uint16(5), uint16(0), uint16(0)],
            [uint8(0), uint8(25), uint8(0)],
            30000000000000, // 0.00003 ETH
            ""
        );

        // Ramen - Evening special for Samurai
        _addFoodType(
            "Ramen",
            "Hearty noodle soup for warriors",
            15,
            [uint16(0), uint16(0), uint16(5), uint16(0)],
            [uint8(0), uint8(0), uint8(30)],
            40000000000000, // 0.00004 ETH
            ""
        );

        // Chanko Nabe - Special for Sumo
        _addFoodType(
            "Chanko Nabe",
            "Sumo wrestler's power stew",
            20,
            [uint16(0), uint16(0), uint16(0), uint16(10)],
            [uint8(10), uint8(10), uint8(10)],
            50000000000000, // 0.00005 ETH
            ""
        );

        // Wagyu Beef - Premium food
        _addFoodType(
            "Wagyu Beef",
            "Premium Japanese beef for special occasions",
            30,
            [uint16(5), uint16(5), uint16(5), uint16(5)],
            [uint8(15), uint8(15), uint8(15)],
            75000000000000, // 0.000075 ETH
            ""
        );

        // Matcha Tea Set - Geisha favorite
        _addFoodType(
            "Matcha Tea Set",
            "Ceremonial tea with traditional sweets",
            25,
            [uint16(15), uint16(3), uint16(3), uint16(3)],
            [uint8(20), uint8(10), uint8(5)],
            60000000000000, // 0.00006 ETH
            ""
        );

        // Tempura Set - Ninja favorite
        _addFoodType(
            "Tempura Set",
            "Light and crispy tempura selection",
            18,
            [uint16(3), uint16(8), uint16(3), uint16(3)],
            [uint8(5), uint8(20), uint8(10)],
            45000000000000, // 0.000045 ETH
            ""
        );

        // Yakitori Skewers - Samurai favorite
        _addFoodType(
            "Yakitori Skewers",
            "Grilled chicken skewers with tare sauce",
            22,
            [uint16(3), uint16(3), uint16(10), uint16(3)],
            [uint8(5), uint8(10), uint8(25)],
            53000000000000, // 0.000053 ETH
            ""
        );

        // Sakura Mochi - Spring special
        _addFoodType(
            "Sakura Mochi",
            "Cherry blossom rice cake (Spring special)",
            40,
            [uint16(20), uint16(10), uint16(10), uint16(10)],
            [uint8(25), uint8(25), uint8(25)],
            100000000000000, // 0.0001 ETH
            ""
        );

        // Festival Bento - Celebration special
        _addFoodType(
            "Festival Bento",
            "Special bento box for celebrations",
            50,
            [uint16(15), uint16(15), uint16(15), uint16(15)],
            [uint8(30), uint8(30), uint8(30)],
            200000000000000, // 0.0002 ETH
            ""
        );
    }
}
