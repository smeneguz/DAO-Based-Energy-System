// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interface for the Membership contract
interface IMembership {
    function isActiveMember(address _address) external view returns (bool);
    function updateEnergyContribution(address _memberAddress, uint256 _amount) external;
}

// Interface for the Treasury contract
interface ITreasury {
    function collectFee(uint256 _amount) external;
}

/**
 * @title EnergyManagement
 * @dev Manages energy trading within the community
 */
contract EnergyManagement is Ownable, ReentrancyGuard {
    // Order types
    enum OrderType { Buy, Sell }
    
    // Order status
    enum OrderStatus { Open, Fulfilled, Cancelled }
    
    // Structure for energy trade orders
    struct EnergyOrder {
        uint256 orderId;
        address trader;
        OrderType orderType;
        uint256 energyAmount; // in kWh (represented as kWh * 1000 for precision)
        uint256 pricePerUnit; // price per kWh
        OrderStatus status;
        uint256 timestamp;
        uint256 expiryTime; // orders expire after a set time
    }
    
    // Reference to the membership contract
    IMembership public membershipContract;
    // Reference to the treasury contract
    ITreasury public treasuryContract;
    // Token used for energy trades (could be governance token or stablecoin)
    IERC20 public tradingToken;
    
    // Fee percentage (in basis points, e.g., 100 = 1%)
    uint256 public feePercentage;
    // Order expiry time in seconds (default 24 hours)
    uint256 public orderExpiryTime = 86400;
    
    // Counter for order IDs
    uint256 private nextOrderId = 1;
    
    // Mappings to track orders
    mapping(uint256 => EnergyOrder) public orders;
    mapping(address => uint256[]) public userOrders;
    uint256[] public openBuyOrders;
    uint256[] public openSellOrders;
    
    // Events
    event OrderPlaced(
        uint256 indexed orderId, 
        address indexed trader, 
        OrderType orderType, 
        uint256 energyAmount, 
        uint256 pricePerUnit
    );
    event OrderMatched(
        uint256 indexed buyOrderId, 
        uint256 indexed sellOrderId, 
        uint256 energyAmount, 
        uint256 totalPrice
    );
    event OrderCancelled(uint256 indexed orderId);
    event FeePercentageUpdated(uint256 newFeePercentage);
    
    /**
     * @dev Constructor for the Energy Management contract
     * @param _initialOwner Address that will own the contract
     * @param _membershipContract Address of the Membership contract
     * @param _treasuryContract Address of the Treasury contract
     * @param _tradingToken Address of the ERC20 token used for trading
     * @param _feePercentage Trading fee percentage in basis points (100 = 1%)
     */
    constructor(
        address _initialOwner,
        address _membershipContract,
        address _treasuryContract,
        address _tradingToken,
        uint256 _feePercentage
    ) Ownable(_initialOwner) {
        membershipContract = IMembership(_membershipContract);
        treasuryContract = ITreasury(_treasuryContract);
        tradingToken = IERC20(_tradingToken);
        feePercentage = _feePercentage;
    }
    
    /**
     * @dev Place a new energy order
     * @param _orderType Type of order (Buy or Sell)
     * @param _energyAmount Amount of energy in kWh (multiplied by 1000 for precision)
     * @param _pricePerUnit Price per kWh
     */
    function placeOrder(
        OrderType _orderType, 
        uint256 _energyAmount, 
        uint256 _pricePerUnit
    ) 
        external 
        nonReentrant 
    {
        require(membershipContract.isActiveMember(msg.sender), "Not an active member");
        require(_energyAmount > 0, "Energy amount must be positive");
        require(_pricePerUnit > 0, "Price must be positive");
        
        // For buy orders, ensure user has enough tokens to cover the purchase
        if (_orderType == OrderType.Buy) {
            uint256 totalCost = (_energyAmount * _pricePerUnit) / 1000; // Convert back from precision format
            require(tradingToken.balanceOf(msg.sender) >= totalCost, "Insufficient token balance");
            
            // Lock tokens for the buy order
            require(tradingToken.transferFrom(msg.sender, address(this), totalCost), "Token transfer failed");
        }
        
        // Create the new order
        uint256 orderId = nextOrderId++;
        
        EnergyOrder memory newOrder = EnergyOrder({
            orderId: orderId,
            trader: msg.sender,
            orderType: _orderType,
            energyAmount: _energyAmount,
            pricePerUnit: _pricePerUnit,
            status: OrderStatus.Open,
            timestamp: block.timestamp,
            expiryTime: block.timestamp + orderExpiryTime
        });
        
        // Store the order
        orders[orderId] = newOrder;
        userOrders[msg.sender].push(orderId);
        
        // Add to the appropriate list of open orders
        if (_orderType == OrderType.Buy) {
            openBuyOrders.push(orderId);
        } else {
            openSellOrders.push(orderId);
        }
        
        emit OrderPlaced(orderId, msg.sender, _orderType, _energyAmount, _pricePerUnit);
        
        // Try to match the order immediately
        if (_orderType == OrderType.Buy) {
            tryMatchBuyOrder(orderId);
        } else {
            tryMatchSellOrder(orderId);
        }
    }
    
    /**
     * @dev Try to match a buy order with open sell orders
     * @param _buyOrderId ID of the buy order to match
     */
    function tryMatchBuyOrder(uint256 _buyOrderId) internal {
        EnergyOrder storage buyOrder = orders[_buyOrderId];
        
        // Only try to match open orders
        if (buyOrder.status != OrderStatus.Open) return;
        
        // Loop through open sell orders to find matches
        for (uint256 i = 0; i < openSellOrders.length && buyOrder.energyAmount > 0; i++) {
            uint256 sellOrderId = openSellOrders[i];
            EnergyOrder storage sellOrder = orders[sellOrderId];
            
            // Skip orders that are not open or have expired
            if (sellOrder.status != OrderStatus.Open || sellOrder.expiryTime < block.timestamp) {
                continue;
            }
            
            // Check if the price is acceptable
            if (sellOrder.pricePerUnit <= buyOrder.pricePerUnit) {
                // Calculate the amount that can be traded
                uint256 tradeAmount = (buyOrder.energyAmount < sellOrder.energyAmount) 
                    ? buyOrder.energyAmount 
                    : sellOrder.energyAmount;
                
                // Calculate total price for the trade
                uint256 totalPrice = (tradeAmount * sellOrder.pricePerUnit) / 1000; // Convert back from precision format
                
                // Calculate fee
                uint256 fee = (totalPrice * feePercentage) / 10000;
                uint256 sellerAmount = totalPrice - fee;
                
                // Update energy amounts
                buyOrder.energyAmount -= tradeAmount;
                sellOrder.energyAmount -= tradeAmount;
                
                // Update order statuses if fulfilled
                if (sellOrder.energyAmount == 0) {
                    sellOrder.status = OrderStatus.Fulfilled;
                    // Remove from open orders (handled in a separate function)
                    removeOpenOrder(sellOrderId, OrderType.Sell);
                }
                
                if (buyOrder.energyAmount == 0) {
                    buyOrder.status = OrderStatus.Fulfilled;
                    // Remove from open orders (handled in a separate function)
                    removeOpenOrder(_buyOrderId, OrderType.Buy);
                }
                
                // Transfer tokens to seller
                require(tradingToken.transfer(sellOrder.trader, sellerAmount), "Token transfer to seller failed");
                
                // Send fee to treasury
                if (fee > 0) {
                    treasuryContract.collectFee(fee);
                }
                
                // Update energy contribution for the seller
                membershipContract.updateEnergyContribution(sellOrder.trader, tradeAmount);
                
                emit OrderMatched(_buyOrderId, sellOrderId, tradeAmount, totalPrice);
            }
        }
        
        // If buy order was partially filled and there's remaining amount, 
        // refund the unused tokens to the buyer
        if (buyOrder.energyAmount > 0 && buyOrder.status == OrderStatus.Fulfilled) {
            uint256 refundAmount = (buyOrder.energyAmount * buyOrder.pricePerUnit) / 1000;
            require(tradingToken.transfer(buyOrder.trader, refundAmount), "Refund to buyer failed");
        }
    }
    
    /**
     * @dev Try to match a sell order with open buy orders
     * @param _sellOrderId ID of the sell order to match
     */
    function tryMatchSellOrder(uint256 _sellOrderId) internal {
        EnergyOrder storage sellOrder = orders[_sellOrderId];
        
        // Only try to match open orders
        if (sellOrder.status != OrderStatus.Open) return;
        
        // Loop through open buy orders to find matches
        for (uint256 i = 0; i < openBuyOrders.length && sellOrder.energyAmount > 0; i++) {
            uint256 buyOrderId = openBuyOrders[i];
            EnergyOrder storage buyOrder = orders[buyOrderId];
            
            // Skip orders that are not open or have expired
            if (buyOrder.status != OrderStatus.Open || buyOrder.expiryTime < block.timestamp) {
                continue;
            }
            
            // Check if the price is acceptable
            if (buyOrder.pricePerUnit >= sellOrder.pricePerUnit) {
                // Calculate the amount that can be traded
                uint256 tradeAmount = (sellOrder.energyAmount < buyOrder.energyAmount) 
                    ? sellOrder.energyAmount 
                    : buyOrder.energyAmount;
                
                // Calculate total price for the trade
                uint256 totalPrice = (tradeAmount * sellOrder.pricePerUnit) / 1000; // Convert back from precision format
                
                // Calculate fee
                uint256 fee = (totalPrice * feePercentage) / 10000;
                uint256 sellerAmount = totalPrice - fee;
                
                // Update energy amounts
                buyOrder.energyAmount -= tradeAmount;
                sellOrder.energyAmount -= tradeAmount;
                
                // Update order statuses if fulfilled
                if (buyOrder.energyAmount == 0) {
                    buyOrder.status = OrderStatus.Fulfilled;
                    // Remove from open orders
                    removeOpenOrder(buyOrderId, OrderType.Buy);
                }
                
                if (sellOrder.energyAmount == 0) {
                    sellOrder.status = OrderStatus.Fulfilled;
                    // Remove from open orders
                    removeOpenOrder(_sellOrderId, OrderType.Sell);
                }
                
                // Transfer tokens to seller
                require(tradingToken.transfer(sellOrder.trader, sellerAmount), "Token transfer to seller failed");
                
                // Send fee to treasury
                if (fee > 0) {
                    treasuryContract.collectFee(fee);
                }
                
                // Update energy contribution for the seller
                membershipContract.updateEnergyContribution(sellOrder.trader, tradeAmount);
                
                emit OrderMatched(buyOrderId, _sellOrderId, tradeAmount, totalPrice);
            }
        }
    }
    
    /**
     * @dev Remove an order from the open orders list
     * @param _orderId ID of the order to remove
     * @param _orderType Type of the order (Buy or Sell)
     */
    function removeOpenOrder(uint256 _orderId, OrderType _orderType) internal {
        uint256[] storage openOrders = _orderType == OrderType.Buy ? openBuyOrders : openSellOrders;
        
        for (uint256 i = 0; i < openOrders.length; i++) {
            if (openOrders[i] == _orderId) {
                // Replace with the last element and pop
                openOrders[i] = openOrders[openOrders.length - 1];
                openOrders.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Cancel an open order
     * @param _orderId ID of the order to cancel
     */
    function cancelOrder(uint256 _orderId) external nonReentrant {
        EnergyOrder storage order = orders[_orderId];
        
        require(order.trader == msg.sender, "Not order owner");
        require(order.status == OrderStatus.Open, "Order not open");
        
        order.status = OrderStatus.Cancelled;
        
        // Refund tokens for buy orders
        if (order.orderType == OrderType.Buy) {
            uint256 refundAmount = (order.energyAmount * order.pricePerUnit) / 1000;
            require(tradingToken.transfer(msg.sender, refundAmount), "Refund failed");
        }
        
        // Remove from open orders
        removeOpenOrder(_orderId, order.orderType);
        
        emit OrderCancelled(_orderId);
    }
    
    /**
     * @dev Update the fee percentage (admin only)
     * @param _newFeePercentage New fee percentage in basis points
     */
    function updateFeePercentage(uint256 _newFeePercentage) 
        external 
        onlyOwner 
    {
        require(_newFeePercentage <= 1000, "Fee too high"); // Max 10%
        feePercentage = _newFeePercentage;
        emit FeePercentageUpdated(_newFeePercentage);
    }
    
    /**
     * @dev Update order expiry time (admin only)
     * @param _newExpiryTime New expiry time in seconds
     */
    function updateOrderExpiryTime(uint256 _newExpiryTime) 
        external 
        onlyOwner 
    {
        orderExpiryTime = _newExpiryTime;
    }
    
    /**
     * @dev Update contract references (admin only)
     * @param _membershipContract New membership contract address
     * @param _treasuryContract New treasury contract address
     * @param _tradingToken New trading token address
     */
    function updateContractReferences(
        address _membershipContract,
        address _treasuryContract,
        address _tradingToken
    ) 
        external 
        onlyOwner 
    {
        membershipContract = IMembership(_membershipContract);
        treasuryContract = ITreasury(_treasuryContract);
        tradingToken = IERC20(_tradingToken);
    }
    
    /**
     * @dev Get all open buy orders
     * @return Array of order IDs
     */
    function getOpenBuyOrders() external view returns (uint256[] memory) {
        return openBuyOrders;
    }
    
    /**
     * @dev Get all open sell orders
     * @return Array of order IDs
     */
    function getOpenSellOrders() external view returns (uint256[] memory) {
        return openSellOrders;
    }
    
    /**
     * @dev Get user's orders
     * @param _user Address of the user
     * @return Array of order IDs
     */
    function getUserOrders(address _user) external view returns (uint256[] memory) {
        return userOrders[_user];
    }
    
    /**
     * @dev Clean up expired orders (can be called by anyone)
     * @param _maxOrders Maximum number of orders to process (to avoid gas limit issues)
     */
    function cleanupExpiredOrders(uint256 _maxOrders) external {
        uint256 count = 0;
        
        // Process buy orders
        for (uint256 i = 0; i < openBuyOrders.length && count < _maxOrders; i++) {
            EnergyOrder storage order = orders[openBuyOrders[i]];
            if (order.expiryTime < block.timestamp) {
                order.status = OrderStatus.Cancelled;
                
                // Refund tokens
                uint256 refundAmount = (order.energyAmount * order.pricePerUnit) / 1000;
                tradingToken.transfer(order.trader, refundAmount);
                
                // Remove from open orders (will be handled in the next call)
                count++;
            }
        }
        
        // Process sell orders
        for (uint256 i = 0; i < openSellOrders.length && count < _maxOrders; i++) {
            EnergyOrder storage order = orders[openSellOrders[i]];
            if (order.expiryTime < block.timestamp) {
                order.status = OrderStatus.Cancelled;
                count++;
            }
        }
    }
}