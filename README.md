# PaxeerWalletVMFactory - Smart Wallet Factory Contract

## 🏭 Overview

PaxeerWalletVMFactory is the central factory contract that creates individual smart contract wallets (Wallet VMs) for users using the minimal proxy pattern. It manages features, tracks network statistics, and handles reward distribution.

## 📍 Deployment

**Network**: Paxeer Network (Chain ID: 80000)  
**Contract Address**: `0xC86037276DdFD4e6565aF05B267232F72655E82e`  
**Verification**: ⏳ Pending (requires constructor args)  
**Implementation**: `0xC5002F87e1cb8BC850660Dd4BC63Ff8ab2B5543C`

## 🎯 Key Features

### Wallet VM Creation
- **Minimal Proxy Pattern**: Gas-efficient wallet deployment using OpenZeppelin Clones
- **One-per-User**: Each user gets exactly one Wallet VM
- **Feature Configuration**: Initialize wallets with custom feature sets
- **Sponsored Deployment**: Zero gas fees for wallet creation

### Feature Management System
- **10+ Available Features**: From basic transactions to AI trading
- **On-Demand Activation**: Features can be activated after wallet creation
- **Configuration Support**: Each feature supports custom configuration data
- **Upgrade Path**: New features can be added to the ecosystem

### Network Analytics & Rewards
- **Statistics Tracking**: Network-wide usage and activity metrics
- **Data Contribution**: Users earn rewards for contributing transaction data
- **Reward Pool**: Funded pool for distributing network participation rewards
- **Activity Monitoring**: Track wallet activity and engagement

## 🚀 Core Functions

### Wallet Creation
```solidity
function createWalletVM(
    string[] memory initialFeatures,
    bytes[] memory featureConfigs
) external nonReentrant returns (address walletVM)
```
Creates a new Wallet VM with specified initial features.

### Feature Management
```solidity
function activateFeature(
    address walletVM,
    string memory featureName,
    bytes memory config
) external nonReentrant
```
Activates a new feature on an existing Wallet VM.

```solidity
function getAvailableFeatures() external view returns (string[] memory)
```
Returns all features available in the ecosystem.

### Network Statistics
```solidity
function getNetworkStats() external view returns (NetworkStats memory)
```
Returns comprehensive network statistics including total wallets, active wallets, transactions, and rewards.

### User Queries
```solidity
function getUserWallet(address user) external view returns (address)
```
Get the Wallet VM address for a specific user.

```solidity
function hasWallet(address user) external view returns (bool)
```
Check if a user has already created a Wallet VM.

## 📊 Available Features

### Core Features (Always Available)
1. **basic_transactions**
   - Send/receive tokens and ETH
   - Basic wallet functionality
   - Transaction history logging

2. **defi_integrations**
   - Interact with DeFi protocols
   - Automated yield strategies
   - Liquidity provision

3. **nft_management**
   - NFT buying, selling, transferring
   - Marketplace integrations
   - Collection management

4. **dao_participation**
   - Governance voting
   - Proposal creation and execution
   - Multi-DAO participation

### Advanced Features
5. **yield_farming**
   - Automated yield optimization
   - Multi-protocol farming
   - Compound strategy execution

6. **cross_chain_bridge**
   - Cross-chain asset transfers
   - Multi-network operations
   - Bridge protocol integrations

7. **ai_trading**
   - AI-powered trading strategies
   - Automated arbitrage
   - Risk management protocols

8. **social_recovery**
   - Guardian-based recovery
   - Secure key management
   - Emergency access procedures

9. **multi_sig**
   - Multi-signature validation
   - Threshold-based security
   - Collaborative transaction approval

10. **data_contribution**
    - Network data contribution
    - Reward earning mechanism
    - Analytics participation

## 🏗️ Architecture

### Contract Structure
```solidity
struct WalletVMInfo {
    address owner;
    uint256 walletId;
    string[] activeFeatures;
    mapping(string => bytes) featureConfigs;
    uint256 contributionBalance;
    uint256 lastActivity;
}

struct NetworkStats {
    uint256 totalWallets;
    uint256 activeWallets;
    uint256 totalTransactions;
    uint256 totalRewards;
}
```

### Security Features
- **ReentrancyGuard**: All state-changing functions protected
- **Ownable Pattern**: Administrative control for ecosystem management
- **One-Wallet-Per-User**: Prevents wallet spam and ensures uniqueness
- **Feature Validation**: Only registered features can be activated

## 💰 Reward System

### Data Contribution Rewards
Users earn rewards for contributing various types of network data:

```solidity
function contributeNetworkData(
    bytes32 dataHash,
    uint256 dataType,
    bytes memory metadata
) external
```

**Reward Structure**:
- Type 1 (Transaction data): 200 wei base reward
- Type 2 (DeFi interactions): 300 wei base reward  
- Type 3 (Cross-chain data): 500 wei base reward
- Type 4 (NFT activity): 400 wei base reward

### Pool Management
```solidity
function fundRewardPool() external payable onlyOwner
function withdrawRewards(address recipient, uint256 amount) external onlyOwner
```

## 📈 Network Statistics

The factory tracks comprehensive ecosystem metrics:

```solidity
struct NetworkStats {
    uint256 totalWallets;      // Total Wallet VMs created
    uint256 activeWallets;     // Recently active wallets
    uint256 totalTransactions; // All-time transaction count
    uint256 totalRewards;      // Total rewards distributed
}
```

### Activity Tracking
```solidity
function updateActivity(address walletVM) external
```
Called by Wallet VMs to update their last activity timestamp.

## 🧪 Integration Example

### Creating a Wallet VM
```javascript
// Using the SDK
const factory = new ethers.Contract(factoryAddress, factoryABI, signer);

const initialFeatures = [
    "basic_transactions",
    "defi_integrations", 
    "data_contribution"
];

const featureConfigs = ["0x", "0x", "0x"]; // No special config needed

const tx = await factory.createWalletVM(
    initialFeatures,
    featureConfigs,
    { gasPrice: 0 } // Sponsored transaction
);

const receipt = await tx.wait();
const walletVMAddress = await factory.getUserWallet(userAddress);
```

### Activating Features
```javascript
await factory.activateFeature(
    walletVMAddress,
    "ai_trading",
    "0x", // Feature-specific configuration
    { gasPrice: 0 }
);
```

## 🔧 Development

### Prerequisites
- Solidity ^0.8.19
- OpenZeppelin Contracts (Clones, ReentrancyGuard, Ownable)
- Hardhat development environment

### Constructor Parameters
```solidity
constructor(address _walletVMImplementation)
```
Requires the address of the deployed PaxeerWalletVM implementation contract.

### Compilation
```bash
npx hardhat compile
```

### Testing
```bash
npx hardhat test test/PaxeerWalletVMFactory.test.js
```

### Deployment
```bash
npx hardhat run scripts/deploy-ecosystem.js --network paxeer-network
```

## 📊 Gas Optimization

- **Minimal Proxy Pattern**: ~90% gas savings on wallet deployment
- **Sponsored Transactions**: All operations use gasPrice: 0
- **Batch Operations**: Support for multiple feature activations
- **Efficient Storage**: Optimized data structures and packing

## 🛡️ Security Considerations

### Access Control
- **OnlyOwner**: Administrative functions restricted
- **User Restrictions**: One wallet per user address
- **Feature Validation**: Only valid features can be activated

### Economic Security
- **Reward Pool Limits**: Controlled reward distribution
- **Activity Monitoring**: Prevents spam and abuse
- **Configuration Validation**: Secure feature configuration

## 📈 Analytics & Monitoring

The factory provides real-time ecosystem analytics:
- Total ecosystem growth
- Feature adoption rates
- User activity patterns
- Reward distribution metrics

## 🤝 Contributing

Part of the Paxeer Ecosystem - see main repository for contribution guidelines.

## 📄 License

MIT License - Full ecosystem license applies.

---

*Creating the Future of Smart Wallets - Built with ❤️ by the Paxeer Team*
