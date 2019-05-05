// Copyright (c) 2017 Altcoin Exchange, Inc

// Copyright (c) 2018 BetterToken BVBA
// Use of this source code is governed by an MIT
// license that can be found at https://github.com/rivine/rivine/blob/master/LICENSE.

// Copyright (c) 2019 Chris Haoyu LIN, Runchao HAN, Jiangshan YU

pragma solidity ^0.5.0;

// Notes on security warnings:
//  + block.timestamp is safe to use,
//    given that our timestamp can tolerate a 30-second drift in time;

contract RiskySpeculativeAtomicSwapSpot {
    enum AssetState { Empty, Filled, Redeemed, Refunded }
    enum PremiumState { Empty, Filled, Redeemed, Refunded }

    struct Swap {
        uint256 assetRefundTimestamp;
        uint256 premiumRefundTimestamp;
        bytes32 secretHash;
        bytes32 secret;
        address payable initiator;
        address payable participant;
        uint256 assetValue;
        AssetState assetState;
        uint256 premiumValue;
        PremiumState premiumState;
    }

    mapping(bytes32 => Swap) public swaps;

    event AssetRefunded(
        uint256 refundTimestamp,
        bytes32 secretHash,
        address refunder,
        uint256 value
    );

    event AssetRedeemed(
        uint256 redeemTimestamp,
        bytes32 secretHash,
        bytes32 secret,
        address redeemer,
        uint256 value
    );

    event PremiumRefunded(
        uint256 refundTimestamp,
        bytes32 secretHash,
        address refunder,
        uint256 value
    );

    event PremiumRedeemed(
        uint256 redeemTimestamp,
        bytes32 secretHash,
        address redeemer,
        uint256 value
    );

    event Participated(
        uint256 participateTimestamp,
        uint256 assetRefundTimestamp,
        uint256 premiumRefundTimestamp,
        bytes32 secretHash,
        address initiator,
        address participant,
        uint256 assetValue,
        uint256 premiumValue
    );

    event Initiated(
        uint256 initiateTimestamp,
        uint256 assetRefundTimestamp,
        uint256 premiumRefundTimestamp,
        bytes32 secretHash,
        address initiator,
        address participant,
        uint256 assetValue,
        uint256 premiumValue
    );

    event PremiumFilled(
        uint256 fillPremiumTimestamp,
        uint256 assetRefundTimestamp,
        uint256 premiumRefundTimestamp,
        bytes32 secretHash,
        address initiator,
        address participant,
        uint256 assetValue,
        uint256 premiumValue
    );

    // TODO:
    event SetUp(
        uint256 assetRefundTimestamp,
        uint256 premiumRefundTimestamp,
        bytes32 secretHash,
        address initiator,
        address participant,
        uint256 assetValue,
        uint256 premiumValue
    );

    constructor() public {}

    // TODO:
    modifier isPremiumRefundable(bytes32 secretHash) {
        require(swaps[secretHash].premiumState == PremiumState.Filled);
        require(swaps[secretHash].initiator == msg.sender);
        require(block.timestamp > swaps[secretHash].assetRefundTimestamp);
        _;
    }

    // TODO:
    modifier isPremiumRedeemable(bytes32 secretHash) {
        require(swaps[secretHash].premiumState == PremiumState.Filled);
        require(swaps[secretHash].initiator == msg.sender);
        require(block.timestamp > swaps[secretHash].assetRefundTimestamp);
        _;
    }

    modifier isAssetRefundable(bytes32 secretHash) {
        require(swaps[secretHash].assetState == AssetState.Filled);
        // require(swaps[secretHash].refunder == msg.sender);
        require(block.timestamp > swaps[secretHash].assetRefundTimestamp);
        _;
    }

    // TODO:
    modifier isAssetRedeemable(bytes32 secretHash, bytes32 secret) {
        require(swaps[secretHash].assetState == AssetState.Filled);
        // require(swaps[secretHash].redeemer == msg.sender);
        require(sha256(abi.encodePacked(secret)) == secretHash);
        _;
    }

    modifier isInitiator(bytes32 secretHash) {
        require(swaps[secretHash].initiator == msg.sender);
        _;
    }

    modifier isParticipant(bytes32 secretHash) {
        require(swaps[secretHash].participant == msg.sender);
        _;
    }

    modifier isPremiumFilled(bytes32 secretHash) {
        require(swaps[secretHash].premiumState == PremiumState.Filled);
        _;
    }

    modifier isAssetEmptyState(bytes32 secretHash) {
        require(swaps[secretHash].assetState == AssetState.Empty);
        _;
    }

    modifier isPremiumEmptyState(bytes32 secretHash) {
        require(swaps[secretHash].premiumState == PremiumState.Empty);
        _;
    }

    modifier fulfillAssetPayment(bytes32 secretHash) {
        require(swaps[secretHash].assetValue == msg.value);
        _;
    }

    modifier fulfillPremiumPayment(bytes32 secretHash) {
        require(swaps[secretHash].premiumValue == msg.value);
        _;
    }

    // overflow check for assetRefundTimestamp 
    modifier checkRefundTimestampOverflow(uint256 refundTime) {
        uint256 setupTimestamp = block.timestamp;
        uint256 refundTimestamp = block.timestamp + refundTime;
        require(refundTimestamp > block.timestamp, "calc refundTimestamp overflow");
        require(refundTimestamp > refundTime, "calc refundTimestamp overflow");
        _;
    }

    function setup(uint256 assetRefundTime,
                    uint256 premiumRefundTime,
                    bytes32 secretHash,
                    address payable initiator,
                    address payable participant,
                    uint256 assetValue,
                    uint256 premiumValue)
        public
        payable
        checkRefundTimestampOverflow(assetRefundTime)
        checkRefundTimestampOverflow(premiumRefundTime)
        isAssetEmptyState(secretHash)
        isPremiumEmptyState(secretHash)
    {
        swaps[secretHash].assetRefundTimestamp = block.timestamp + assetRefundTime;
        swaps[secretHash].premiumRefundTimestamp = block.timestamp + premiumRefundTime;
        swaps[secretHash].secretHash = secretHash;
        swaps[secretHash].initiator = initiator;
        swaps[secretHash].participant = participant;
        swaps[secretHash].assetValue = assetValue;
        swaps[secretHash].premiumValue = premiumValue;
        swaps[secretHash].assetState = AssetState.Empty;
        swaps[secretHash].premiumState = PremiumState.Empty;
        
        emit SetUp(
            block.timestamp + assetRefundTime,
            block.timestamp + premiumRefundTime,
            secretHash,
            initiator,
            participant,
            assetValue,
            premiumValue 
        );
    }

    // Initiator needs to pay for the premium with premiumValue
    function fillPremium(bytes32 secretHash)
        public
        payable
        isInitiator(secretHash)
        fulfillPremiumPayment(secretHash)
        isPremiumEmptyState(secretHash)
    {   
        swaps[secretHash].premiumState = PremiumState.Filled;
        
        emit PremiumFilled(
            block.timestamp,
            swaps[secretHash].assetRefundTimestamp,
            swaps[secretHash].premiumRefundTimestamp,
            secretHash,
            msg.sender,
            swaps[secretHash].participant,
            swaps[secretHash].assetValue,
            msg.value
        );
    }

    function initiate(bytes32 secretHash)
        public
        payable
        isInitiator(secretHash)
        fulfillAssetPayment(secretHash)
        isAssetEmptyState(secretHash)
    {
        swaps[secretHash].assetState = AssetState.Filled;
        
        emit Initiated(
            block.timestamp,
            swaps[secretHash].assetRefundTimestamp,
            swaps[secretHash].premiumRefundTimestamp,
            secretHash,
            msg.sender,
            swaps[secretHash].participant,
            msg.value,
            swaps[secretHash].premiumValue
        );
    }

    // TODO:
    function participate(bytes32 secretHash)
        public
        payable
        isParticipant(secretHash)
        fulfillAssetPayment(secretHash)
        isAssetEmptyState(secretHash)
        isPremiumFilled(secretHash)
    {
        swaps[secretHash].assetState = AssetState.Filled;
        
        emit Participated(
            block.timestamp,
            swaps[secretHash].assetRefundTimestamp,
            swaps[secretHash].premiumRefundTimestamp,
            secretHash,
            swaps[secretHash].initiator,
            msg.sender,
            msg.value,
            swaps[secretHash].premiumValue
        );
    }

    function redeemAsset(bytes32 secret, bytes32 secretHash)
        public
        isAssetRedeemable(secretHash, secret)
    {
        msg.sender.transfer(swaps[secretHash].assetValue);

        swaps[secretHash].assetState = AssetState.Redeemed;
        swaps[secretHash].secret = secret;

        emit AssetRedeemed(
            block.timestamp,
            secretHash,
            secret,
            msg.sender,
            swaps[secretHash].assetValue
        );
    }

    function refundAsset(bytes32 secretHash)
        public
        isPremiumFilled(secretHash)
        isAssetRefundable(secretHash)
    {
        msg.sender.transfer(swaps[secretHash].assetValue);

        swaps[secretHash].assetState = AssetState.Refunded;

        emit AssetRefunded(
            block.timestamp,
            swaps[secretHash].secretHash,
            msg.sender,
            swaps[secretHash].assetValue
        );
    }

    function redeemPremium(bytes32 secretHash)
        public
        isPremiumRedeemable(secretHash)
    {
        swaps[secretHash].participant.transfer(swaps[secretHash].premiumValue);
        swaps[secretHash].premiumState = PremiumState.Redeemed;

        emit PremiumRefunded(
            block.timestamp,
            swaps[secretHash].secretHash,
            msg.sender,
            swaps[secretHash].premiumValue
        );
    }
    
    function refundPremium(bytes32 secretHash)
        public
        isPremiumRefundable(secretHash)
    {
        swaps[secretHash].initiator.transfer(swaps[secretHash].premiumValue);
        swaps[secretHash].premiumState = PremiumState.Refunded;

        emit PremiumRefunded(
            block.timestamp,
            swaps[secretHash].secretHash,
            msg.sender,
            swaps[secretHash].premiumValue
        );
    }
}
