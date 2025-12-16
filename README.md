# 🐱 NekoCat Living NFT Smart Contracts

A revolutionary Living NFT system deployed on **Base Sepolia** (testnet) and **Soneium Mainnet**. Each NFT is a digital pet that requires daily care and feeding to survive, creating an engaging and interactive NFT experience with real scarcity through auto-burn mechanics.

## 🌟 Overview

NekoCat NFTs are **Living NFTs** - digital collectibles that require active participation. Unlike traditional static NFTs, NekoCat NFTs:

- Require daily feeding to survive
- Can die if not properly cared for
- Can be revived with increasing costs
- Level up through gameplay
- Can achieve immortality through staking
- Are automatically burned when all lives are lost

## 📊 Collection Details

### Character Types & Structure

- **4 Character Types**: Geisha 🌸, Ninja 🥷, Samurai ⚔️, Sumo 🤼
- **5 Variants** per character type
- **7 Levels** per variant (0-6: Kitten to Legend)
- **Total Supply**: 20,000 NFTs
- **Mint Price**: $2.5 USD equivalent (in ETH, dynamic pricing)

### Distribution

- 20,000 total NFTs
- 5,000 NFTs per character type
- 1,000 NFTs per variant
- 142-143 NFTs per level

## 🎮 Game Mechanics

### Feeding System

- **3 Daily Feeding Slots**:
  - Morning (6AM-12PM)
  - Afternoon (12PM-6PM)
  - Evening (6PM-12AM)
- **2 Bonus Feeds**: Available after completing all 3 daily slots
- **Perfect Day**: Feed all 5 times (3 daily + 2 bonus) to build streak
- **Feeding Cost**: Dynamic pricing via DepositManager (default ~$0.10 USD in ETH)
- **Payments**: Processed through modular `DepositManager` contract
- **Food NFTs**: Can use Food NFTs for feeding (NekoCatFood contract)

### Lives & Death System

- **9 Total Lives** (8 revival chances)
- **Death Timer**: 48 hours (2 days) without feeding
- **Revival Cost**: $2.5 base, increases 1.5x per revival
  - 1st revival: $2.5
  - 2nd revival: $3.75
  - 3rd revival: $5.625
  - 4th revival: $8.4375
  - etc.
- **⚠️ AUTO-BURN**: NFT is automatically burned when all 9 lives are lost
- **Death Checker**: Anyone can call `checkDeath` to trigger death check (small reward)

### Progression & Rewards

- **Streak System**: Track consecutive perfect days
- **Level Up**: Requires 30 × (level + 1) perfect days
  - Level 1: 30 days
  - Level 2: 60 days
  - Level 3: 90 days
  - etc.
- **Weekly Tickets**: Earned every 7 perfect days
- **Monthly Tickets**: Earned every 30 perfect days

### Immortality System

- **Requirement**: Stake 2M+ NEKO tokens in staking contract
- **Usage**: Call `useImmortality(tokenId)` to activate on ONE chosen NFT
- **Limit**: Only 1 NFT can be immortal per wallet at a time
- **Benefit**: Chosen NFT cannot die from starvation
- **NON-TRANSFERABLE**: Immortality right stays with staker
  - If you sell/transfer the immortal NFT, it loses immortality
  - You keep the right to use immortality on another NFT you own
  - New owner of transferred NFT does NOT get immortality
- **Switch**: Can transfer immortality to another NFT anytime (removes from previous)
- **Revocation**: Automatically revoked if stake drops below 2M NEKO
- **Verification**: Real-time check through external `NekoStaking` contract
- **Auto-Sync**: Staking contract automatically syncs immortality status on stake/unstake

## 🏗️ Architecture

### Core Contracts

#### NekoCatNFT.sol

Core Living NFT contract with death/revival mechanics.

**Features:**

- ERC-721 Enumerable standard
- Living NFT mechanics
- Death and revival system
- Immortality system integration
- Level progression (0-6)
- 9 lives system with auto-burn
- Credit score calculation
- Marketplace integration

**Key Functions:**

```solidity
function mintCatSimple() external payable
function feedCat(uint256 tokenId, uint256 foodTokenId) external payable
function reviveCat(uint256 tokenId) external payable
function useImmortality(uint256 tokenId) external
function checkDeath(uint256 tokenId) external
function getCatInfo(uint256 tokenId) external view returns (CatMetadata memory, CatState memory, bool, uint256)
```

#### NekoCatFood.sol

Food NFT system for feeding NekoCat NFTs.

**Features:**

- ERC-721 standard
- Multiple food types with different XP values
- Character-specific bonuses
- XP calculation and consumption
- Food NFTs are consumed when feeding

**Key Functions:**

```solidity
function mintFood(uint256 amount) external payable
function feedCat(uint256 catTokenId, uint256 foodTokenId) external
function getFoodXP(uint256 foodTokenId) external view returns (uint256)
```

#### NekoMarketplace.sol

NFT marketplace for buying and selling NekoCat NFTs.

**Features:**

- List NFTs for sale
- Buy listed NFTs
- Cancel listings
- Update listing prices
- Batch operations
- Expiration system
- Platform fees (2.5% default)
- Blacklist support

**Key Functions:**

```solidity
function listNFT(uint256 tokenId, uint256 price) external
function buyNFT(uint256 listingId) external payable
function cancelListing(uint256 listingId) external
function updateListingPrice(uint256 listingId, uint256 newPrice) external
function getAllActiveListings(uint256 offset, uint256 limit) external view returns (Listing[] memory, uint256)
```

#### DepositManager.sol

Multi-token payment processing contract.

**Features:**

- Multi-token support (ETH, WETH, USDT, USDC)
- Dynamic pricing (ETH/USD rate)
- Mint payment processing
- Feeding payment processing
- Revival payment processing
- Treasury integration
- Reward pool integration

**Supported Tokens:**

- ETH (native)
- WETH: `0x4200000000000000000000000000000000000006` (Base Sepolia)
- USDT (future)
- USDC (future)

**Key Functions:**

```solidity
function processMintPayment() external payable returns (uint256)
function processFeedingPayment() external payable returns (uint256)
function processRevivalPayment() external payable returns (uint256)
function getMintPrice() external view returns (uint256)
function getFeedingCost() external view returns (uint256)
function getRevivalCost(uint256 revivalCount) external view returns (uint256)
```

#### NekoPriceManager.sol

Dynamic pricing management contract.

**Features:**

- ETH/USD price management
- Fallback pricing
- Price update cooldown
- Manual price updates
- Price source tracking

**Key Functions:**

```solidity
function updateFoodPricing() external
function getPricingStatus() external view returns (bool, uint256, uint256)
function canUpdatePrices() external view returns (bool)
```

#### NekoTreasuryNFT.sol

Treasury contract for NFT-related funds.

**Features:**

- ETH balance management
- ERC20 token balance management
- Withdrawal functionality
- Integration with ICO and NFT contracts

**Key Functions:**

```solidity
function withdrawFunds(address token, uint256 amount, address to) external
function getBalance(address token) external view returns (uint256)
```

### Contract Integration

```
NekoCatNFT
  ├── DepositManager (payment processing)
  ├── NekoStaking (immortality verification)
  ├── NekoCatFood (food NFT integration)
  └── NekoMarketplace (trading)

NekoMarketplace
  ├── NekoCatNFT (NFT transfers)
  └── NekoTreasuryNFT (fee collection)

DepositManager
  ├── NekoTreasuryNFT (fund management)
  └── NekoPriceManager (pricing)
```

## 📍 Contract Addresses

### Base Sepolia (Testnet)

- **NekoCatNFT**: `0xeA35E626a71bB25b392c793356c3361299Ff2F2D`
- **NekoCatFood**: `0x33B9A89971dc00935652D7F7EB7Db3eb79282565`
- **NekoMarketplace**: `0xCE5F6Ad225D3F272A3024DB276371Cff2f7f70B0`
- **DepositManager**: `0x8010Dc0591A629E8cE911f4Fc26d54B08c4C0DB8`
- **NekoTreasuryNFT**: `0x45289F864A92D51320aB80b5524f8C542DeB5e92`
- **NekoPriceManager**: `0xcC3Ced4285d8923F2C5a50fdE7a2668DbB89C93b`

### Block Explorer

- **Base Sepolia**: https://sepolia-explorer.base.org
- **Soneium Mainnet**: https://explorer.soneium.org

## 🚀 Getting Started

### Prerequisites

- **Node.js** >= 18.0.0
- **npm** >= 8.0.0
- **Hardhat** >= 2.19.0
- **MetaMask** or compatible wallet

### Installation

```bash
# Install dependencies
npm install

# Copy environment template
cp env.example .env

# Edit .env with your configuration
```

### Environment Setup

Edit the `.env` file:

```env
# Network Configuration
SONEIUM_RPC_URL=https://rpc.soneium.org
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
PRIVATE_KEY=your_private_key

# Treasury and Reward Pools
TREASURY_WALLET=0x_your_treasury
FEEDING_REWARD_POOL=0x_your_reward_pool

# Marketplace Configuration
MARKETPLACE_FEE_PERCENT=250          # 2.5% (basis points)
MARKETPLACE_MIN_PRICE=0.001         # Min listing price in ETH
MARKETPLACE_MAX_PRICE=100           # Max listing price in ETH (optional)
MARKETPLACE_EXPIRATION_DAYS=30       # Listing expiration in days

# API Keys
ETHERSCAN_API_KEY=your_etherscan_api_key
BASESCAN_API_KEY=your_basescan_api_key

# IPFS/NFT Storage (Optional)
PINATA_API_KEY=your_pinata_api_key
PINATA_SECRET_KEY=your_pinata_secret_key
NFT_STORAGE_API_KEY=your_nft_storage_api_key
```

### Compilation

```bash
npm run compile
```

### Generate TypeChain Types

```bash
npm run typechain
```

### Testing

```bash
# Run all tests
npm test

# Run specific test suite
npm run test:nft
npm run test:deposit
npm run test:food

# Run tests with gas reporting
npm run test:gas

# Run coverage
npm run coverage
```

### Deployment

```bash
# Deploy to Base Sepolia testnet
npm run deploy:testnet

# Deploy to Soneium mainnet
npm run deploy:local  # For local testing first

# Deploy to local network
npx hardhat run scripts/deploy.js --network localhost
```

## 🔧 Contract Functions

### Minting

```solidity
// Mint a single NFT (simple mint)
function mintCatSimple() external payable

// Mint with specific parameters (owner only)
function mintCat(CharacterType characterType, uint8 variant, uint8 level) external payable

// Batch mint (owner only)
function batchMint(address to, CharacterType[] calldata types, uint8[] calldata variants, uint8[] calldata levels) external
```

### Feeding

```solidity
// Feed a single cat with ETH
function feedCat(uint256 tokenId) external payable

// Feed a cat with Food NFT
function feedCat(uint256 tokenId, uint256 foodTokenId) external

// Batch feed multiple cats
function batchFeedCats(uint256[] calldata tokenIds) external payable
```

### Death & Revival

```solidity
// Check if cat should die (anyone can call, small reward)
function checkDeath(uint256 tokenId) external

// Revive a dead cat
function reviveCat(uint256 tokenId) external payable
```

### Immortality

```solidity
// Use immortality on a specific NFT (requires 2M+ NEKO staked)
function useImmortality(uint256 tokenId) external

// Check if user can use immortality
function canUseImmortality(address holder) external view returns (bool)

// Get user's immortal NFT token ID (0 if none)
function getUserImmortalNFT(address holder) external view returns (uint256)

// Check if specific NFT is immortal
function isNFTImmortal(uint256 tokenId) external view returns (bool)
```

### Marketplace

```solidity
// List NFT for sale
function listNFT(uint256 tokenId, uint256 price) external

// Buy listed NFT
function buyNFT(uint256 listingId) external payable

// Cancel listing
function cancelListing(uint256 listingId) external

// Update listing price
function updateListingPrice(uint256 listingId, uint256 newPrice) external

// Batch operations
function batchListNFT(uint256[] calldata tokenIds, uint256[] calldata prices) external
function batchCancelListing(uint256[] calldata listingIds) external

// View functions
function getAllActiveListings(uint256 offset, uint256 limit) external view returns (Listing[] memory, uint256 total)
function getListingsBySeller(address seller, uint256 offset, uint256 limit) external view returns (Listing[] memory, uint256 total)
function getMarketplaceStats() external view returns (uint256 totalVolume, uint256 totalSales, uint256 activeListings, uint256 platformFeePercent)
```

### Information

```solidity
// Get complete cat information
function getCatInfo(uint256 tokenId) external view returns (
    CatMetadata memory metadata,
    CatState memory state,
    bool isDead,
    uint256 timeUntilDeath
)

// Get current feeding slot
function getCurrentFeedingSlot() public view returns (FeedingSlot)

// Calculate revival cost
function getRevivalCost(uint256 tokenId) public view returns (uint256)

// Get mint price (dynamic based on ETH/USD rate)
function getMintPrice() public view returns (uint256)

// Get feeding cost
function getFeedingCost() public view returns (uint256)
```

## 🔐 Security Features

### Core Security

- ✅ **OpenZeppelin v5.0.1** (latest stable)
- ✅ **ReentrancyGuard** on all state-changing functions
- ✅ **Pausable** for emergency stops
- ✅ **Ownable** with proper access control
- ✅ **Safe math** operations (Solidity 0.8.20+)
- ✅ **Modular design** - no funds stuck in NFT contract

### Input Validation

- ✅ All parameters validated before processing
- ✅ Array length checks and bounds validation
- ✅ Address zero checks
- ✅ Amount range validation
- ✅ Character type, variant, and level validation

### MEV Protection

- ✅ **Same-block minting prevention** - can't mint twice in same block
- ✅ **Same-block feeding prevention** - prevents sandwich attacks
- ✅ **Duplicate detection** in batch operations
- ✅ **Overpayment protection** - rejects excessive payments (2x max)
- ✅ **Rate limiting** - minimum 1 hour between feeds per NFT

### Timestamp Manipulation Protection

- ✅ **Time-based mechanics** use block.timestamp with tolerance
- ✅ **Feeding slots** based on hour-of-day (not manipulable)
- ✅ **Death timer** checks time differences, not absolute values
- ✅ **Daily reset** uses midnight calculation (deterministic)

### Additional Protections

- ✅ **Custom error library** for gas efficiency
- ✅ **SecurityLib** with helper functions
- ✅ **Interface-based** external calls
- ✅ **Auto-burn** on final death (no zombie NFTs)
- ✅ **Batch size limits** to prevent DOS
- ✅ **No funds in NFT contract** - all via DepositManager
- ✅ **Marketplace security** - ReentrancyGuard, expiration, blacklist, price limits, role-based access control

## 🛠 Tech Stack

- **Solidity**: ^0.8.20
- **OpenZeppelin Contracts**: ^5.0.1
- **Hardhat**: ^2.19.0
- **Network**: Base Sepolia (Chain ID: 84532) / Soneium Mainnet (Chain ID: 1868)

## 📊 Gas Optimization

- Packed storage for CatState and CatMetadata
- Bitmap for feeding slots (saves gas vs array)
- Batch operations for multiple NFTs
- Optimized loops and conditions
- Compiler optimization enabled (200 runs)

## 🧪 Testing

```bash
# Run all tests
npm test

# Run with gas reporter
REPORT_GAS=true npm run test

# Run coverage
npm run coverage
```

## 📈 Post-Deployment Checklist

1. ✅ Deploy all contracts
2. ✅ Verify contracts on block explorer
3. ✅ Link contracts together (staking, treasury, etc.)
4. ✅ Set base URI for metadata
5. ✅ Configure pricing (mint, feed, revival)
6. ✅ Update ETH/USD price
7. ✅ Set up automated death checker bot
8. ✅ Connect NEKO staking contract for immortality
9. ✅ Upload metadata to IPFS
10. ✅ Test minting flow
11. ✅ Test feeding mechanics
12. ✅ Test marketplace
13. ✅ Announce launch

## 🎛️ Admin Configuration Guide

### Pricing Configuration

#### Update Feeding Cost

```javascript
// Set to $0.10
await depositManager.updateFeedingCost(ethers.parseEther("0.10"));

// Set to $0.50
await depositManager.updateFeedingCost(ethers.parseEther("0.50"));

// Set to FREE
await depositManager.updateFeedingCost(0);
```

#### Update Revival Base Cost

```javascript
// Set base cost to $2.50
await depositManager.updateBaseRevivalCost(ethers.parseEther("2.5"));

// Set base cost to $5.00
await depositManager.updateBaseRevivalCost(ethers.parseEther("5.0"));
```

#### Update Revival Multiplier

```javascript
// Set to 1.5x (each revival costs 1.5x the previous)
await depositManager.updateRevivalMultiplier(150);

// Set to 2x (each revival costs 2x the previous)
await depositManager.updateRevivalMultiplier(200);

// Set to 1.2x (gentler progression)
await depositManager.updateRevivalMultiplier(120);
```

**Multiplier Constraints:**

- Minimum: 100 (1.0x - no increase)
- Maximum: 300 (3.0x - triple each time)

#### Revival Cost Examples

**With 1.5x multiplier (150):**

```
Revival 1: $2.50
Revival 2: $2.50 × 1.5 = $3.75
Revival 3: $3.75 × 1.5 = $5.63
Revival 4: $5.63 × 1.5 = $8.44
```

**With 2x multiplier (200):**

```
Revival 1: $2.50
Revival 2: $2.50 × 2 = $5.00
Revival 3: $5.00 × 2 = $10.00
Revival 4: $10.00 × 2 = $20.00
```

### Manual ETH Price Configuration

```javascript
// Update ETH/USD price manually
await depositManager.updateEthPrice(ethers.parseEther("3500")); // $3500

// Update fallback prices
await depositManager.updateFallbackEthPrice(ethers.parseEther("3000"));
```

### Immortality Configuration

```javascript
// Update immortality threshold to 3M NEKO
await nekoCatNFT.setImmortalityThreshold(ethers.parseEther("3000000"));

// Update staking contract
await nekoCatNFT.setStakingContract("0x_new_staking_address");
```

## 📚 Documentation

- **[Root README](../../README.md)**: Project overview
- **[Frontend README](../../frontend/README.md)**: Frontend application
- **[Contracts README](../erc20/README.md)**: ERC20 token contracts

## 📜 License

MIT License - see LICENSE file for details

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Make your changes
4. Add tests
5. Submit a Pull Request

## ⚠️ Disclaimer

This smart contract handles real value. Always:

- Test thoroughly on testnet first
- Audit the contract before mainnet deployment
- Use a hardware wallet for deployment
- Keep private keys secure
- Verify all addresses before deployment

## 📞 Support

For questions or issues:

- GitHub Issues: [Create an issue](https://github.com/nekocatworld/nekocat-nft-contracts/issues)
- Documentation: [Read the docs](../../docs/)

---

by the NEKO Team
