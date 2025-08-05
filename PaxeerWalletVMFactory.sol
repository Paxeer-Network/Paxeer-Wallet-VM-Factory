// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title PaxeerWalletVMFactory
 * @dev Factory contract that creates unique wallet VM instances for each user
 * Each wallet is a smart contract with VM capabilities and network participation
 */
contract PaxeerWalletVMFactory is Ownable, ReentrancyGuard {
    using Clones for address;

    // Events
    event WalletVMCreated(address indexed user, address indexed walletVM, uint256 walletId);
    event WalletVMUpgraded(address indexed walletVM, uint256 newVersion);
    event NetworkDataContributed(address indexed walletVM, bytes32 dataHash, uint256 reward);
    event FeatureActivated(address indexed walletVM, string featureName, bytes config);

    // Structs
    struct WalletVMInfo {
        address owner;
        address walletVM;
        uint256 walletId;
        uint256 version;
        uint256 createdAt;
        uint256 lastActivity;
        uint256 contributionScore;
        bool isActive;
        string[] activeFeatures;
        mapping(string => bytes) featureConfigs;
    }

    struct NetworkStats {
        uint256 totalWallets;
        uint256 activeWallets;
        uint256 totalContributions;
        uint256 totalRewardsDistributed;
    }

    // State variables
    address public walletVMImplementation;
    uint256 public currentVersion = 1;
    uint256 public nextWalletId = 1;
    uint256 public contributionRewardPool;
    
    mapping(address => WalletVMInfo) public walletVMs;
    mapping(address => address) public userToWallet;
    mapping(uint256 => address) public walletIdToAddress;
    
    NetworkStats public networkStats;
    string[] public availableFeatures;
    mapping(string => bool) public isFeatureAvailable;

    constructor(address _walletVMImplementation) Ownable(msg.sender) {
        walletVMImplementation = _walletVMImplementation;
        
        // Initialize available features
        _addFeature("basic_transactions");
        _addFeature("defi_integrations");
        _addFeature("nft_management");
        _addFeature("dao_participation");
        _addFeature("yield_farming");
        _addFeature("cross_chain_bridge");
        _addFeature("ai_trading");
        _addFeature("social_recovery");
        _addFeature("multi_sig");
        _addFeature("data_contribution");
    }

    /**
     * @dev Creates a new wallet VM for a user
     * One-click wallet generation with full smart contract capabilities
     */
    function createWalletVM(
        string[] memory initialFeatures,
        bytes[] memory featureConfigs
    ) external nonReentrant returns (address walletVM) {
        require(userToWallet[msg.sender] == address(0), "User already has a wallet");
        require(initialFeatures.length == featureConfigs.length, "Features/configs length mismatch");

        // Clone the wallet VM implementation
        walletVM = walletVMImplementation.clone();
        
        uint256 walletId = nextWalletId++;
        
        // Initialize wallet VM info
        WalletVMInfo storage info = walletVMs[walletVM];
        info.owner = msg.sender;
        info.walletVM = walletVM;
        info.walletId = walletId;
        info.version = currentVersion;
        info.createdAt = block.timestamp;
        info.lastActivity = block.timestamp;
        info.contributionScore = 0;
        info.isActive = true;

        // Set up mappings
        userToWallet[msg.sender] = walletVM;
        walletIdToAddress[walletId] = walletVM;

        // Initialize the wallet VM with features
        IPaxeerWalletVM(walletVM).initialize(
            msg.sender,
            walletId,
            address(this)
        );

        // Activate initial features
        for (uint256 i = 0; i < initialFeatures.length; i++) {
            _activateFeature(walletVM, initialFeatures[i], featureConfigs[i]);
        }

        // Update network stats
        networkStats.totalWallets++;
        networkStats.activeWallets++;

        emit WalletVMCreated(msg.sender, walletVM, walletId);
        return walletVM;
    }

    /**
     * @dev Activates a new feature for a wallet VM
     */
    function activateFeature(string memory featureName, bytes memory config) external {
        address walletVM = userToWallet[msg.sender];
        require(walletVM != address(0), "User has no wallet");
        require(isFeatureAvailable[featureName], "Feature not available");

        _activateFeature(walletVM, featureName, config);
    }

    /**
     * @dev Records data contribution from a wallet VM and distributes rewards
     */
    function contributeNetworkData(
        bytes32 dataHash,
        uint256 dataType,
        bytes memory metadata
    ) external {
        address walletVM = msg.sender;
        require(walletVMs[walletVM].isActive, "Wallet VM not active");

        // Calculate contribution reward based on data type and quality
        uint256 reward = _calculateContributionReward(dataType, metadata);
        
        if (reward > 0 && contributionRewardPool >= reward) {
            contributionRewardPool -= reward;
            walletVMs[walletVM].contributionScore += reward;
            networkStats.totalRewardsDistributed += reward;
            
            // Transfer reward to wallet VM
            IPaxeerWalletVM(walletVM).receiveContributionReward(reward);
        }

        networkStats.totalContributions++;
        walletVMs[walletVM].lastActivity = block.timestamp;

        emit NetworkDataContributed(walletVM, dataHash, reward);
    }

    /**
     * @dev Updates wallet VM activity (called by wallet VMs during transactions)
     */
    function updateActivity(address walletVM) external {
        require(msg.sender == walletVM || walletVMs[walletVM].owner == msg.sender, "Unauthorized");
        walletVMs[walletVM].lastActivity = block.timestamp;
    }

    /**
     * @dev Gets comprehensive wallet VM information
     */
    function getWalletVMInfo(address user) external view returns (
        address walletVM,
        uint256 walletId,
        uint256 version,
        uint256 createdAt,
        uint256 lastActivity,
        uint256 contributionScore,
        bool isActive,
        string[] memory activeFeatures
    ) {
        address userWallet = userToWallet[user];
        require(userWallet != address(0), "User has no wallet");
        
        WalletVMInfo storage info = walletVMs[userWallet];
        return (
            info.walletVM,
            info.walletId,
            info.version,
            info.createdAt,
            info.lastActivity,
            info.contributionScore,
            info.isActive,
            info.activeFeatures
        );
    }

    /**
     * @dev Gets network statistics
     */
    function getNetworkStats() external view returns (NetworkStats memory) {
        return networkStats;
    }

    /**
     * @dev Gets all available features
     */
    function getAvailableFeatures() external view returns (string[] memory) {
        return availableFeatures;
    }

    /**
     * @dev Gets user's wallet VM address
     */
    function getUserWallet(address user) external view returns (address) {
        return userToWallet[user];
    }

    /**
     * @dev Checks if user has a wallet VM
     */
    function hasWallet(address user) external view returns (bool) {
        return userToWallet[user] != address(0);
    }

    // Internal functions
    function _activateFeature(address walletVM, string memory featureName, bytes memory config) internal {
        require(isFeatureAvailable[featureName], "Feature not available");
        
        WalletVMInfo storage info = walletVMs[walletVM];
        info.activeFeatures.push(featureName);
        info.featureConfigs[featureName] = config;

        // Notify the wallet VM about the new feature
        IPaxeerWalletVM(walletVM).activateFeature(featureName, config);

        emit FeatureActivated(walletVM, featureName, config);
    }

    function _calculateContributionReward(uint256 dataType, bytes memory metadata) internal pure returns (uint256) {
        // Simple reward calculation - can be made more sophisticated
        uint256 baseReward = 100; // Base reward in wei
        
        if (dataType == 1) return baseReward * 2; // Transaction data
        if (dataType == 2) return baseReward * 3; // DeFi interaction data
        if (dataType == 3) return baseReward * 5; // Cross-chain data
        if (dataType == 4) return baseReward * 4; // NFT activity data
        
        return baseReward;
    }

    function _addFeature(string memory featureName) internal {
        if (!isFeatureAvailable[featureName]) {
            availableFeatures.push(featureName);
            isFeatureAvailable[featureName] = true;
        }
    }

    // Admin functions
    function updateWalletVMImplementation(address newImplementation) external onlyOwner {
        walletVMImplementation = newImplementation;
        currentVersion++;
    }

    function addFeature(string memory featureName) external onlyOwner {
        _addFeature(featureName);
    }

    function fundContributionRewards() external payable onlyOwner {
        contributionRewardPool += msg.value;
    }

    function deactivateWallet(address walletVM) external onlyOwner {
        require(walletVMs[walletVM].isActive, "Wallet already inactive");
        walletVMs[walletVM].isActive = false;
        networkStats.activeWallets--;
    }
}

/**
 * @title IPaxeerWalletVM
 * @dev Interface for Paxeer Wallet VM instances
 */
interface IPaxeerWalletVM {
    function initialize(address owner, uint256 walletId, address factory) external;
    function activateFeature(string memory featureName, bytes memory config) external;
    function receiveContributionReward(uint256 amount) external;
    function getBalance() external view returns (uint256);
    function getActiveFeatures() external view returns (string[] memory);
}
