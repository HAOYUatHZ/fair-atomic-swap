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
    enum Kind { Initiator, Participant }
    enum AssetState { Empty, Filled, Redeemed, Refunded }
    enum PremiumState { Empty, Filled, Redeemed, Refunded }

    struct Swap {
        bytes32 secretHash;
        bytes32 secret;
        address payable initiator;
        address payable participant;
        Kind kind;
        uint256 assetValue;
        uint256 assetRefundTimestamp;
        AssetState assetState;
        uint256 premiumValue;
        uint256 premiumRefundTimestamp;
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
        bytes32 secretHash,
        address initiator,
        address participant,
        uint256 assetValue,
        uint256 assetRefundTimestamp,
        uint256 premiumValue,
        uint256 premiumRefundTimestamp
    );

    event Initiated(
        uint256 initiateTimestamp,
        bytes32 secretHash,
        address initiator,
        address participant,
        uint256 assetValue,
        uint256 assetRefundTimestamp,
        uint256 premiumValue,
        uint256 premiumRefundTimestamp
    );

    event PremiumFilled(
        uint256 fillPremiumTimestamp,
        bytes32 secretHash,
        address initiator,
        address participant,
        uint256 assetValue,
        uint256 assetRefundTimestamp,
        uint256 premiumValue,
        uint256 premiumRefundTimestamp
    );

    event SetUp(
        bytes32 secretHash,
        address initiator,
        address participant,
        uint256 assetValue,
        uint256 assetRefundTimestamp,
        uint256 premiumValue,
        uint256 premiumRefundTimestamp
    );

    constructor() public {}

    // Premium is refundable on blokchian2 when
    // 1. Alice initiates but Bob does not participate
    //   after premium's timelock expires;
    // 2. asset2 is redeemed by Alice;
    modifier isPremiumRefundable(bytes32 secretHash) {
        // on asset2 chain
        require(swaps[secretHash].kind == Kind.Participant);
        // the premium should be deposited
        require(swaps[secretHash].premiumState == PremiumState.Filled);
        // the initiator invokes this method to refund the premium        
        require(swaps[secretHash].initiator == msg.sender);
        // if the asset2 timelock is still valid
        if (block.timestamp <= swaps[secretHash].assetRefundTimestamp) {
            // the asset2 should be redeemded by Alice
            require(swaps[secretHash].assetState == AssetState.Redeemed);
        } else {
            require(block.timestamp > swaps[secretHash].premiumRefundTimestamp);
            require(swaps[secretHash].assetState != AssetState.Refunded);
        }
        _;
    }

    // Premium is redeemable on blockchian2 for Bob when asset2 is refunded
    // which means Alice holds the secret maliciously;
    // and refundable on blokchain1 before premium timelock expires.
    modifier isPremiumRedeemable(bytes32 secretHash) {
        // on asset2 chain
        require(swaps[secretHash].kind == Kind.Participant);
        // the premium should be deposited
        require(swaps[secretHash].premiumState == PremiumState.Filled);
        // the participant invokes this method to redeem the premium
        require(swaps[secretHash].participant == msg.sender);
        // the asset2 should be refunded
        // this also indicates the asset2 timelock is expired
        require(swaps[secretHash].assetState == AssetState.Refunded);
        // the premium timelock should not be expired
        require(block.timestamp <= swaps[secretHash].premiumRefundTimestamp);
        _;
    }

    modifier isAssetRefundable(bytes32 secretHash) {
        require(swaps[secretHash].assetState == AssetState.Filled);
        if(swaps[secretHash].kind == Kind.Initiator) {
            require(swaps[secretHash].initiator == msg.sender);
        } else {
            require(swaps[secretHash].participant == msg.sender);
        }
        require(block.timestamp > swaps[secretHash].assetRefundTimestamp);
        _;
    }

    modifier isAssetRedeemable(bytes32 secretHash, bytes32 secret) {
        require(swaps[secretHash].assetState == AssetState.Filled);
        if(swaps[secretHash].kind == Kind.Initiator) {
            require(swaps[secretHash].participant == msg.sender);
        } else {
            require(swaps[secretHash].initiator == msg.sender);
        }
        require(block.timestamp <= swaps[secretHash].assetRefundTimestamp);
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

    modifier isPremiumFilledState(bytes32 secretHash) {
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

    modifier checkRefundTimestampOverflow(uint256 refundTime) {
        uint256 refundTimestamp = block.timestamp + refundTime;
        require(refundTimestamp > block.timestamp, "calc refundTimestamp overflow");
        require(refundTimestamp > refundTime, "calc refundTimestamp overflow");
        _;
    }

    // both initiator and participant can set up a contract.
    // zero-value premiumValue indicates that the contract in on initiator's chain.
    function setup(bytes32 secretHash,
                    address payable initiator,
                    address payable participant,
                    uint256 assetValue,
                    uint256 assetRefundTime,
                    uint256 premiumValue,
                    uint256 premiumRefundTime)
        public
        payable
        checkRefundTimestampOverflow(assetRefundTime)
        checkRefundTimestampOverflow(premiumRefundTime)
        isAssetEmptyState(secretHash)
        isPremiumEmptyState(secretHash)
    {
        swaps[secretHash].secretHash = secretHash;
        swaps[secretHash].initiator = initiator;
        swaps[secretHash].participant = participant;
        if (premiumValue == 0) {
            swaps[secretHash].kind = Kind.Initiator;
        } else {
            swaps[secretHash].kind = Kind.Participant;
        }
        swaps[secretHash].assetValue = assetValue;
        swaps[secretHash].assetRefundTimestamp = block.timestamp + assetRefundTime;
        swaps[secretHash].assetState = AssetState.Empty;
        swaps[secretHash].premiumValue = premiumValue;
        swaps[secretHash].premiumRefundTimestamp = block.timestamp + premiumRefundTime;
        swaps[secretHash].premiumState = PremiumState.Empty;
        
        emit SetUp(
            secretHash,
            initiator,
            participant,
            assetValue,
            block.timestamp + assetRefundTime,
            premiumValue, 
            block.timestamp + premiumRefundTime
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
            secretHash,
            msg.sender,
            swaps[secretHash].participant,
            swaps[secretHash].assetValue,
            swaps[secretHash].assetRefundTimestamp,
            msg.value,
            swaps[secretHash].premiumRefundTimestamp
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
            secretHash,
            msg.sender,
            swaps[secretHash].participant,
            msg.value,
            swaps[secretHash].assetRefundTimestamp,
            swaps[secretHash].premiumValue,
            swaps[secretHash].premiumRefundTimestamp
        );
    }

    function participate(bytes32 secretHash)
        public
        payable
        isParticipant(secretHash)
        fulfillAssetPayment(secretHash)
        isAssetEmptyState(secretHash)
        isPremiumFilledState(secretHash)
    {
        swaps[secretHash].assetState = AssetState.Filled;
        
        emit Participated(
            block.timestamp,
            secretHash,
            swaps[secretHash].initiator,
            msg.sender,
            msg.value,
            swaps[secretHash].assetRefundTimestamp,
            swaps[secretHash].premiumValue,
            swaps[secretHash].premiumRefundTimestamp
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
