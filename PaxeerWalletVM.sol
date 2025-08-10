// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title PaxeerWalletVM
 * @dev Individual smart contract wallet with VM capabilities for each user
 * Each instance is a fully programmable wallet that contributes to the network
 */
contract PaxeerWalletVM is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    // Events
    event TransactionExecuted(address indexed target, uint256 value, bytes data, bool success);
    event FeatureActivated(string featureName, bytes config);
    event DataContributed(bytes32 dataHash, uint256 dataType, uint256 reward);
    event CrossChainAction(uint256 targetChain, bytes data);
    event AIActionExecuted(string strategy, bytes result);
    event SocialRecoveryInitiated(address[] guardians, uint256 threshold);

    // Structs
    struct WalletState {
        address owner;
        uint256 walletId;
        address factory;
        bool initialized;
        uint256 nonce;
        uint256 contributionBalance;
    }

    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        uint256 executedAt;
        bool success;
    }

    struct FeatureConfig {
        bool isActive;
        bytes config;
        uint256 activatedAt;
    }

    // State variables
    WalletState public walletState;
    mapping(string => FeatureConfig) public features;
    string[] public activeFeatures;
    Transaction[] public transactionHistory;
    
    // Feature-specific storage
    mapping(address => bool) public socialRecoveryGuardians;
    uint256 public socialRecoveryThreshold;
    uint256 public recoveryRequestTime;
    address public pendingRecoveryOwner;

    mapping(string => bytes) public aiStrategies;
    mapping(address => uint256) public stakedBalances;
    mapping(uint256 => bytes) public crossChainState;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == walletState.owner, "Not wallet owner");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == walletState.factory, "Not factory");
        _;
    }

    modifier featureActive(string memory featureName) {
        require(features[featureName].isActive, "Feature not active");
        _;
    }

    modifier initialized() {
        require(walletState.initialized, "Not initialized");
        _;
    }

    /**
     * @dev Initializes the wallet VM (called by factory)
     */
    function initialize(
        address owner,
        uint256 walletId,
        address factory
    ) external {
        require(!walletState.initialized, "Already initialized");
        
        walletState.owner = owner;
        walletState.walletId = walletId;
        walletState.factory = factory;
        walletState.initialized = true;
        walletState.nonce = 0;
        walletState.contributionBalance = 0;
    }

    /**
     * @dev Activates a feature with configuration
     */
    function activateFeature(string memory featureName, bytes memory config) external onlyFactory {
        if (!features[featureName].isActive) {
            features[featureName] = FeatureConfig({
                isActive: true,
                config: config,
                activatedAt: block.timestamp
            });
            activeFeatures.push(featureName);
            
            // Initialize feature-specific logic
            _initializeFeature(featureName, config);
            
            emit FeatureActivated(featureName, config);
        }
    }

    /**
     * @dev Executes a transaction from the wallet
     */
    function executeTransaction(
        address target,
        uint256 value,
        bytes memory data
    ) external onlyOwner nonReentrant initialized returns (bool success, bytes memory result) {
        
        // Update activity in factory
        IPaxeerWalletVMFactory(walletState.factory).updateActivity(address(this));
        
        // Execute transaction
        (success, result) = target.call{value: value}(data);
        
        // Record transaction
        transactionHistory.push(Transaction({
            target: target,
            value: value,
            data: data,
            executedAt: block.timestamp,
            success: success
        }));

        // Contribute transaction data to network
        _contributeTransactionData(target, value, data, success);

        emit TransactionExecuted(target, value, data, success);
    }

    /**
     * @dev Batch execute multiple transactions
     */
    function batchExecute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory datas
    ) external onlyOwner nonReentrant initialized returns (bool[] memory successes, bytes[] memory results) {
        require(targets.length == values.length && values.length == datas.length, "Array length mismatch");
        
        successes = new bool[](targets.length);
        results = new bytes[](targets.length);
        
        for (uint256 i = 0; i < targets.length; i++) {
            (successes[i], results[i]) = this.executeTransaction(targets[i], values[i], datas[i]);
        }
    }

    /**
     * @dev DeFi integration feature - interact with DeFi protocols
     */
    function defiInteract(
        address protocol,
        string memory action,
        bytes memory params
    ) external onlyOwner featureActive("defi_integrations") returns (bytes memory result) {
        
        // Execute DeFi action
        (bool success, bytes memory data) = protocol.call(params);
        require(success, "DeFi interaction failed");
        
        // Contribute DeFi data to network
        bytes32 dataHash = keccak256(abi.encodePacked(protocol, action, params, block.timestamp));
        IPaxeerWalletVMFactory(walletState.factory).contributeNetworkData(dataHash, 2, params);
        
        return data;
    }

    /**
     * @dev Cross-chain bridge feature
     */
    function initiateCrossChain(
        uint256 targetChain,
        address targetAddress,
        bytes memory data
    ) external onlyOwner featureActive("cross_chain_bridge") {
        
        // Store cross-chain state
        bytes32 actionId = keccak256(abi.encodePacked(targetChain, targetAddress, data, block.timestamp));
        crossChainState[uint256(actionId)] = data;
        
        // Contribute cross-chain data
        IPaxeerWalletVMFactory(walletState.factory).contributeNetworkData(actionId, 3, data);
        
        emit CrossChainAction(targetChain, data);
    }

    /**
     * @dev AI trading strategy execution
     */
    function executeAIStrategy(
        string memory strategyName,
        bytes memory parameters
    ) external onlyOwner featureActive("ai_trading") returns (bytes memory result) {
        
        bytes memory strategy = aiStrategies[strategyName];
        require(strategy.length > 0, "Strategy not found");
        
        // Execute AI strategy (simplified - would integrate with AI service)
        result = _executeStrategy(strategy, parameters);
        
        emit AIActionExecuted(strategyName, result);
        return result;
    }

    /**
     * @dev Social recovery feature - setup guardians
     */
    function setupSocialRecovery(
        address[] memory guardians,
        uint256 threshold
    ) external onlyOwner featureActive("social_recovery") {
        require(threshold > 0 && threshold <= guardians.length, "Invalid threshold");
        
        // Clear existing guardians
        for (uint256 i = 0; i < guardians.length; i++) {
            socialRecoveryGuardians[guardians[i]] = false;
        }
        
        // Set new guardians
        for (uint256 i = 0; i < guardians.length; i++) {
            socialRecoveryGuardians[guardians[i]] = true;
        }
        
        socialRecoveryThreshold = threshold;
        emit SocialRecoveryInitiated(guardians, threshold);
    }

    /**
     * @dev Initiate social recovery (called by guardians)
     */
    function initiateSocialRecovery(address newOwner) external featureActive("social_recovery") {
        require(socialRecoveryGuardians[msg.sender], "Not a guardian");
        require(newOwner != address(0), "Invalid new owner");
        
        pendingRecoveryOwner = newOwner;
        recoveryRequestTime = block.timestamp;
        
        // In a full implementation, this would require multiple guardian signatures
        // For now, simplified to demonstrate the concept
    }

    /**
     * @dev Complete social recovery after timelock
     */
    function completeSocialRecovery() external featureActive("social_recovery") {
        require(pendingRecoveryOwner != address(0), "No pending recovery");
        require(block.timestamp >= recoveryRequestTime + 2 days, "Recovery timelock not met");
        
        walletState.owner = pendingRecoveryOwner;
        pendingRecoveryOwner = address(0);
        recoveryRequestTime = 0;
    }

    /**
     * @dev Stake tokens for yield farming
     */
    function stakeTokens(
        address token,
        uint256 amount,
        address stakingContract
    ) external onlyOwner featureActive("yield_farming") {
        IERC20(token).safeTransferFrom(walletState.owner, address(this), amount);
        
        // Interact with staking contract
        (bool success,) = stakingContract.call(
            abi.encodeWithSignature("stake(uint256)", amount)
        );
        require(success, "Staking failed");
        
        stakedBalances[token] += amount;
    }

    /**
     * @dev Receive contribution rewards from factory
     */
    function receiveContributionReward(uint256 amount) external onlyFactory {
        walletState.contributionBalance += amount;
    }

    /**
     * @dev Get wallet VM information
     */
    function getWalletInfo() external view returns (
        address owner,
        uint256 walletId,
        uint256 nonce,
        uint256 contributionBalance,
        uint256 transactionCount,
        string[] memory activeFeaturesList
    ) {
        return (
            walletState.owner,
            walletState.walletId,
            walletState.nonce,
            walletState.contributionBalance,
            transactionHistory.length,
            activeFeatures
        );
    }

    /**
     * @dev Get balance of the wallet
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Get active features
     */
    function getActiveFeatures() external view returns (string[] memory) {
        return activeFeatures;
    }

    /**
     * @dev Get transaction history
     */
    function getTransactionHistory() external view returns (Transaction[] memory) {
        return transactionHistory;
    }

    // Internal functions
    function _initializeFeature(string memory featureName, bytes memory config) internal {
        bytes32 featureHash = keccak256(abi.encodePacked(featureName));
        
        if (featureHash == keccak256(abi.encodePacked("ai_trading"))) {
            // Initialize AI trading strategies
            _initializeAITrading(config);
        } else if (featureHash == keccak256(abi.encodePacked("social_recovery"))) {
            // Initialize social recovery
            _initializeSocialRecovery(config);
        }
        // Add more feature initializations as needed
    }

    function _initializeAITrading(bytes memory config) internal {
        // Decode and set up AI trading strategies
        (string[] memory strategies, bytes[] memory configs) = abi.decode(config, (string[], bytes[]));
        
        for (uint256 i = 0; i < strategies.length; i++) {
            aiStrategies[strategies[i]] = configs[i];
        }
    }

    function _initializeSocialRecovery(bytes memory config) internal {
        // Decode social recovery config
        (address[] memory guardians, uint256 threshold) = abi.decode(config, (address[], uint256));
        
        for (uint256 i = 0; i < guardians.length; i++) {
            socialRecoveryGuardians[guardians[i]] = true;
        }
        socialRecoveryThreshold = threshold;
    }

    function _executeStrategy(bytes memory strategy, bytes memory parameters) internal pure returns (bytes memory) {
        // Simplified strategy execution - would integrate with actual AI service
        return abi.encodePacked("Strategy executed with parameters: ", parameters);
    }

    function _contributeTransactionData(address target, uint256 value, bytes memory data, bool success) internal {
        bytes32 dataHash = keccak256(abi.encodePacked(
            target,
            value,
            data,
            success,
            block.timestamp,
            walletState.walletId
        ));
        
        bytes memory metadata = abi.encode(target, value, success, block.timestamp);
        IPaxeerWalletVMFactory(walletState.factory).contributeNetworkData(dataHash, 1, metadata);
    }

    // Receive function to accept ETH
    receive() external payable {}
    
    // Fallback function
    fallback() external payable {}
}

/**
 * @title IPaxeerWalletVMFactory
 * @dev Interface for the factory contract
 */
interface IPaxeerWalletVMFactory {
    function updateActivity(address walletVM) external;
    function contributeNetworkData(bytes32 dataHash, uint256 dataType, bytes memory metadata) external;
}
