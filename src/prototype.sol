// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.19;

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/security/Pausable.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";





/**
 * @title Auction
 * @notice Personal Project, not open for public
 * @author Arman Uddin
 * @dev Centralized crypto market auctions exchange
 */


abstract contract Auction {

    // Struct for every order
    enum OrderType { MarketUSD, MarketCoin, Limit, Stop, StopLimit, OCO }
    enum Side { Buy, Sell }
    enum OrderStatus { Active, Pending, Filled, Canceled }

    struct Order {
        uint256 id;
        uint256 amount;
        address seller;
        address buyer;
        uint256 price;
        uint256 triggerPrice;
        uint256 timestamp;
        OrderType orderType;
        Side side;
        OrderStatus status;
    }
    struct YourPosition {
        uint256 quantity;
        uint256 avgCost;
        uint256 value;
        uint256 todaysReturn;
        uint256 totalReturn;
    }
    struct OCOOrder {
        uint256 id;
        Order limitOrder;
        Order stopOrder;
        OrderType orderType;
        address owner;
        bool isActive; // true until one executes
    }
    

    mapping(address => Order[]) internal userHistory;
    mapping(uint256 => Order) public ordersById;


    // State Variables
    address public owner;
    Order[] public bids;
    Order[] public asks;
    Order[] public pendingBids;
    Order[] public pendingAsks;
    OCOOrder[] public pendingOCOOrders;
    uint256 public orderCounter = 0; // reset at the end of day

    // oracle.sol info
    uint256 currentPrice;
    uint256 wkhigh; // reset at end of week for both
    uint256 wklow;
    uint256 circulatingSupply; // update by the minute
    uint256 dayVolume; // reset at end of day 
    uint256 totalVolume; // update by the minute
    uint256 marketCap; // currentPrice * totalVolume
    

    modifier onlyOrderer(uint256 orderId) {
        require((bids[orderId].buyer == msg.sender) || (asks[orderId].seller == msg.sender), "Not buyer or seller");
        _;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }


    // Backend order functions, buyer or sller calls these with three inputs
    function BidLimitOrder(uint256 _amount, uint256 _limitPrice) public {
        /**
        * Buy at a maximum price or lower
        */
        Order memory newBid = Order({
            id: orderCounter++,
            amount: _amount,
            buyer: msg.sender,
            seller: address(0),
            price: _limitPrice,
            triggerPrice: 0,
            timestamp: block.timestamp,
            orderType: OrderType.Limit,
            side: Side.Buy,
            status: OrderStatus.Active
        });
        bids.push(newBid);
        userHistory[msg.sender].push(newBid);
        ordersById[newBid.id] = newBid;

        
        
    }
    function BidStopOrder(uint256 _amount, uint256 _stopPrice) public {
        /**
        * Trigger a buy at a minimum price or higher
        */
        Order memory newBid = Order({
            id: orderCounter++,
            amount: _amount,
            buyer: msg.sender,
            seller: address(0),
            price: _stopPrice,
            triggerPrice: _stopPrice,
            timestamp: block.timestamp,
            orderType: OrderType.Stop,
            side: Side.Buy,
            status: OrderStatus.Pending
        });
        pendingBids.push(newBid);
        ordersById[newBid.id] = newBid;
    
    }
    function AskLimitOrder(uint256 _amount, uint256 _limitPrice) public {
        /**
        * Sell at a minimum price or higher
        */
        Order memory newAsk = Order({
            id: orderCounter++,
            amount: _amount,
            buyer: address(0),
            seller: msg.sender,
            price: _limitPrice,
            triggerPrice: 0,
            timestamp: block.timestamp,
            orderType: OrderType.Limit,
            side: Side.Sell,
            status: OrderStatus.Active
        });
        asks.push(newAsk);
        userHistory[msg.sender].push(newAsk);
        ordersById[newAsk.id] = newAsk;
        
    }
    function AskStopOrder(uint256 _amount, uint256 _stopPrice) public {
        /**
        * Trigger a sell at a maximum price or lower
        */
            Order memory newAsk = Order({
                id: orderCounter++,
                amount: _amount,
                buyer: address(0),
                seller: msg.sender,
                price: _stopPrice,
                triggerPrice: _stopPrice,
                timestamp: block.timestamp,
                orderType: OrderType.Stop,
                side: Side.Sell,
                status: OrderStatus.Pending
            });
            pendingAsks.push(newAsk);
            ordersById[newAsk.id] = newAsk;

        
    }
    function BidStopLimitOrder(uint256 _amount, uint256 _stopPrice, uint256 _limitPrice) public {
        //if (currentPrice >= _stopPrice){ // bid stop
        //   if (currentPrice <= _limitPrice) { // bid limit
        Order memory newBid = Order({
            id: orderCounter++,
            amount: _amount,
            buyer: msg.sender,
            seller: address(0),
            price: _limitPrice,
            triggerPrice: _stopPrice,
            timestamp: block.timestamp,
            orderType: OrderType.StopLimit,
            side: Side.Buy,
            status: OrderStatus.Pending
        });
        pendingBids.push(newBid);
        ordersById[newBid.id] = newBid;
        //    }
        //}
    }
    function AskStopLimitOrder(uint256 _amount, uint256 _stopPrice, uint256 _limitPrice) public {
        //if (currentPrice <= _stopPrice) { // ask stop
        //    if (currentPrice >= _limitPrice) { // ask limit
        Order memory newAsk = Order({
            id: orderCounter++,
            amount: _amount,
            buyer: address(0),
            seller: msg.sender,
            price: _limitPrice,
            triggerPrice: _stopPrice,
            timestamp: block.timestamp,
            orderType: OrderType.StopLimit,
            side: Side.Sell,
            status: OrderStatus.Pending
        });
        pendingAsks.push(newAsk);
        ordersById[newAsk.id] = newAsk;
        //    }
        //}
    }
    function ocoBidOrder(uint256 _amount, uint256 _stopPrice, uint256 _limitPrice) public {
        Order memory newLimitBid = Order({
            id: orderCounter++,
            amount: _amount,
            buyer: msg.sender,
            seller: address(0),
            price: _limitPrice,
            triggerPrice: 0,
            timestamp: block.timestamp,
            orderType: OrderType.OCO,
            side: Side.Buy,
            status: OrderStatus.Active
        });
        bids.push(newLimitBid);
        ordersById[newLimitBid.id] = newLimitBid;

        Order memory newStopBid = Order({
            id: orderCounter++,
            amount: _amount,
            buyer: msg.sender,
            seller: address(0),
            price: _stopPrice,
            triggerPrice: _stopPrice,
            timestamp: block.timestamp,
            orderType: OrderType.OCO,
            side: Side.Buy,
            status: OrderStatus.Pending
        });
        pendingBids.push(newStopBid);
        ordersById[newStopBid.id] = newStopBid;
        

        

    }
    function ocoAskOrder(uint256 _amount, uint256 _stopPrice, uint256 _limitPrice) public {
        Order memory newLimitBid = Order({
            id: orderCounter++,
            amount: _amount,
            buyer: address(0),
            seller: msg.sender,
            price: _limitPrice,
            triggerPrice: 0,
            timestamp: block.timestamp,
            orderType: OrderType.OCO,
            side: Side.Sell,
            status: OrderStatus.Active
        });
        asks.push(newLimitBid);
        ordersById[newLimitBid.id] = newLimitBid;
        

        Order memory newStopBid = Order({
            id: orderCounter++,
            amount: _amount,
            buyer: address(0),
            seller: msg.sender,
            price: _stopPrice,
            triggerPrice: _stopPrice,
            timestamp: block.timestamp,
            orderType: OrderType.OCO,
            side: Side.Sell,
            status: OrderStatus.Pending
        });
        pendingAsks.push(newStopBid);
        ordersById[newStopBid.id] = newStopBid;
    }


    function bidOrder(uint256 _amount,uint256 _price, uint256 _stopPrice, uint256 _limitPrice, OrderType _orderType) public {
        /** 
        *   Market order - USD
        *   Market order - Coin
        *   Limit order
        *   Stop order
        *   Stop limit order
        *   OCO order
        */
        if (_orderType == OrderType.MarketUSD || _orderType == OrderType.MarketCoin) {
            Order memory newBid = Order({
                id: orderCounter++,
                amount: _amount,
                buyer: msg.sender,
                seller: address(0),
                price: _price,
                triggerPrice: 0,
                timestamp: block.timestamp,
                orderType: _orderType,
                side: Side.Buy,
                status: OrderStatus.Active
            });
            bids.push(newBid);
            userHistory[msg.sender].push(newBid);
            ordersById[newBid.id] = newBid;
        }
        if (_orderType == OrderType.Limit){
            BidLimitOrder(_amount, _limitPrice);
        }
        if (_orderType == OrderType.Stop){
            BidStopOrder(_amount, _stopPrice);
        }
        if (_orderType == OrderType.StopLimit){
            BidStopLimitOrder(_amount, _stopPrice, _limitPrice);
        }
        if (_orderType == OrderType.OCO){
            ocoBidOrder(_amount, _stopPrice, _limitPrice);
        }

    }
    function askOrder(uint256 _amount, uint256 _price, uint256 _stopPrice, uint256 _limitPrice, OrderType _orderType) public{
        /** 
        *   Market order - USD
        *   Market order - Coin
        *   Limit order
        *   Stop order
        *   Stop limit order
        *   OCO order
        */
        if (_orderType == OrderType.MarketUSD || _orderType == OrderType.MarketCoin) {
            Order memory newAsk = Order({
                id: orderCounter++,
                amount: _amount,
                buyer: address(0),
                seller: msg.sender,
                price: _price,
                triggerPrice: 0,
                timestamp: block.timestamp,
                orderType: _orderType,
                side: Side.Sell,
                status: OrderStatus.Active
            });
            asks.push(newAsk);
            userHistory[msg.sender].push(newAsk);
            ordersById[newAsk.id] = newAsk;
        }

        if (_orderType == OrderType.Limit){
            AskLimitOrder(_amount, _limitPrice);
        }
        if (_orderType == OrderType.Stop){
            AskStopOrder(_amount, _stopPrice);
        }
        if (_orderType == OrderType.StopLimit){
            AskStopLimitOrder(_amount, _stopPrice, _limitPrice);
        }
        if (_orderType == OrderType.OCO){
            ocoAskOrder(_amount, _stopPrice, _limitPrice);
        }

    }

    // function matchOrders() public {
    //     // match orders; this will take a bid whenever palced and match with best ask possible, then therefore removing
    //     // the bid and ask, and then repeating. will be called by Chainlink Automation whenever new bid placed
    //     // later optimize for gas, dont use linear search
    //     for (uint i = 0; i < bids.length; i++) {
    //         if (bids[i].status != OrderStatus.Active) continue; // skips non-active bids

    //         uint bestAskIndex = type(uint).max; 
    //         uint bestAskPrice = type(uint).max;

    //         for (uint j = 0; j < asks.length; j++) {
    //             if (
    //                 asks[j].status == OrderStatus.Active &&
    //                 asks[j].price <= bids[i].price &&
    //                 asks[j].price < bestAskPrice
    //             ) {
    //                 bestAskIndex = j;
    //                 bestAskPrice = asks[j].price;
    //             }
    //         }

    //         if (bestAskIndex != type(uint).max) {
    //             // Match bids[i] and asks[bestAskIndex]
    //             // Update amounts, set status = Filled if amount == 0
    //             // Transfer tokens/ETH
    //             // Emit events
    //         }
    //     }
    // }

    function cancelOrder(uint256 _id) public onlyOrderer(_id){
        /**
        * applies to all orders
        * accessible only to the orderer
        */
        bool found = false;

        for (uint i = 0; i < bids.length; i++) {
            if (bids[i].id == _id && bids[i].status == OrderStatus.Active) {
                bids[i].status = OrderStatus.Canceled;
                found = true;
                break;
            }
        }

        if (!found) {
            for (uint j = 0; j < asks.length; j++) {
                if (asks[j].id == _id && asks[j].status == OrderStatus.Active) {
                    asks[j].status = OrderStatus.Canceled;
                    found = true;
                    break;
                }
            }
        }
    }
    function modifyOrder(
        uint256 _id, uint256 _amount, 
        uint256 _newStopPrice, uint256 _newLimitPrice) 
        public onlyOrderer(_id){
        /**
        * applies to limit orders, stop orders, oco, and stop limits, not market orders
        * changes include: amount, price, duration in time, limits and stops
        * accessible only to the orderer
        */
        Order storage order = ordersById[_id];
        Order storage nextOrder = ordersById[_id + 1];
        require(
            order.buyer == msg.sender || order.seller == msg.sender,
            "Not the order owner"
        );

        if (order.orderType == OrderType.Limit){
            order.amount = _amount;
            order.price = _newLimitPrice;
        }
        if (order.orderType == OrderType.Stop){
            order.amount = _amount;
            order.triggerPrice = _newStopPrice;
        }
        if (order.orderType == OrderType.StopLimit){
            order.amount = _amount;
            order.price = _newLimitPrice;
            order.triggerPrice = _newStopPrice;
        }
        if (order.orderType == OrderType.OCO){
            order.price = _newLimitPrice;
            nextOrder.price = _newStopPrice;
            nextOrder.triggerPrice = _newStopPrice;
        }




    }

    function viewBids() public view returns (Order[] memory) {
        return bids;
    }
    function viewAsks() public view returns (Order[] memory) {
        return asks;
    }
    function viewHistory() public view returns (Order[] memory) {
        return userHistory[msg.sender];
    }






}






