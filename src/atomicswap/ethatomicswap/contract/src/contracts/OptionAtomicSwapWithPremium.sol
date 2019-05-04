// Copyright (c) 2017 Altcoin Exchange, Inc

// Copyright (c) 2018 BetterToken BVBA
// Use of this source code is governed by an MIT
// license that can be found at https://github.com/rivine/rivine/blob/master/LICENSE.

// Copyright (c) 2019 Chris Haoyu LIN, Runchao HAN, Jiangshan YU

pragma solidity ^0.5.0;

// Notes on security warnings:
//  + block.timestamp is safe to use,
//    given that our timestamp can tolerate a 30-second drift in time;

contract AtomicSwapWithPremium {
    enum AssetState { Empty, Filled, Redeemed, Refunded }
    enum PremiumState { Empty, Filled, Redeemed, Refunded }

    struct Swap {
        uint256 refundTimestamp;
        bytes32 secretHash;
        bytes32 secret;
        address payable initiator;
        address payable participant;
        address payable redeemer;
        address payable refunder;
        uint256 value;
        AssetState assetState;
        uint256 premiumValue;
        PremiumState premiumState;
    }

    mapping(bytes32 => Swap) public swaps;

    event Refunded(
        uint256 refundTimestamp,
        bytes32 secretHash,
        address refunder,
        uint256 value,
        uint256 premiumValue
    );

    event Redeemed(
        uint256 redeemTime,
        bytes32 secretHash,
        bytes32 secret,
        address redeemer,
        uint256 value,
        uint256 premiumValue
    );

    event Participated(
        uint256 participateTimestamp,
        uint256 refundTimestamp,
        bytes32 secretHash,
        address initiator,
        address participant,
        address redeemer,
        address refunder,
        uint256 value,
        uint256 premiumValue
    );

    event Initiated(
        uint256 initiateTimestamp,
        uint256 refundTimestamp,
        bytes32 secretHash,
        address initiator,
        address participant,
        address redeemer,
        address refunder,
        uint256 value,
        uint256 premiumValue
    );

    event PremiumFilled(
        uint256 fillPremiumTimestamp,
        uint256 refundTimestamp,
        bytes32 secretHash,
        address initiator,
        address participant,
        address redeemer,
        address refunder,
        uint256 value,
        uint256 premiumValue
    );

    event SetUp(
        uint256 setupTimestamp,
        uint256 refundTimestamp,
        bytes32 secretHash,
        address initiator,
        address participant,
        address redeemer,
        address refunder,
        uint256 value,
        uint256 premiumValue
    );

    constructor() public {}

    modifier isRefundable(bytes32 secretHash) {
        require(swaps[secretHash].assetState == AssetState.Filled);
        require(swaps[secretHash].refunder == msg.sender);
        require(block.timestamp > swaps[secretHash].refundTimestamp);
        _;
    }

    modifier isRedeemable(bytes32 secretHash, bytes32 secret) {
        require(swaps[secretHash].assetState == AssetState.Filled);
        require(swaps[secretHash].redeemer == msg.sender);
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

    modifier isEmptyState(bytes32 secretHash) {
        require(swaps[secretHash].assetState == AssetState.Empty);
        _;
    }

    modifier isEmptyPremiumState(bytes32 secretHash) {
        require(swaps[secretHash].premiumState == PremiumState.Empty);
        _;
    }

    modifier fulfillPayment(bytes32 secretHash) {
        require(swaps[secretHash].value == msg.value);
        _;
    }

    modifier fulfillPremiumPayment(bytes32 secretHash) {
        require(swaps[secretHash].premiumValue == msg.value);
        _;
    }

    // overflow check for refundTimestamp 
    modifier checkRefundTimestampOverflow(uint256 refundTime) {
        uint256 setupTimestamp = block.timestamp;
        uint256 refundTimestamp = block.timestamp + refundTime;
        require(refundTimestamp > block.timestamp, "calc refundTimestamp overflow");
        require(refundTimestamp > refundTime, "calc refundTimestamp overflow");
        _;
    }

    // setup sets up a contract
    // 1. setuper doesn't has to be the initiator,
    // 2. initiator should only initiate on blockchian1 after a contrat is set up
    //    on blockchain2 and audit it if necessary.
    function setup(uint256 refundTime,
                    bytes32 secretHash,
                    address payable initiator,
                    address payable participant,
                    address payable redeemer,
                    address payable refunder,
                    uint256 value,
                    uint256 premiumValue)
        public
        payable
        checkRefundTimestampOverflow(refundTime)
        isEmptyState(secretHash)
    {
        swaps[secretHash].refundTimestamp = block.timestamp + refundTime;
        swaps[secretHash].secretHash = secretHash;
        swaps[secretHash].initiator = initiator;
        swaps[secretHash].participant = participant;
        swaps[secretHash].redeemer = redeemer;
        swaps[secretHash].refunder = refunder;
        swaps[secretHash].value = value;
        swaps[secretHash].premiumValue = premiumValue;
        swaps[secretHash].assetState = AssetState.Empty;
        swaps[secretHash].premiumState = PremiumState.Empty;
        
        emit SetUp(
            block.timestamp,
            refundTime,
            secretHash,
            initiator,
            participant,
            redeemer,
            refunder,
            value,
            premiumValue 
        );
    }

    // Initiator needs to pay for the premium with premiumValue
    function fillPremium(bytes32 secretHash)
        public
        payable
        isInitiator(secretHash)
        fulfillPremiumPayment(secretHash)
        isEmptyPremiumState(secretHash)
    {   
        swaps[secretHash].premiumState = PremiumState.Filled;
        
        emit PremiumFilled(
            block.timestamp,
            swaps[secretHash].refundTimestamp,
            secretHash,
            msg.sender,
            swaps[secretHash].participant,
            swaps[secretHash].redeemer,
            swaps[secretHash].refunder,
            swaps[secretHash].value,
            msg.value
        );
    }

    function initiate(bytes32 secretHash)
        public
        payable
        isInitiator(secretHash)
        fulfillPayment(secretHash)
        isEmptyState(secretHash)
    {
        swaps[secretHash].assetState = AssetState.Filled;
        
        emit Initiated(
            block.timestamp,
            swaps[secretHash].refundTimestamp,
            secretHash,
            msg.sender,
            swaps[secretHash].participant,
            swaps[secretHash].redeemer,
            swaps[secretHash].refunder,
            msg.value,
            swaps[secretHash].premiumValue
        );
    }

    // Participant should only participate after premium is paid by the initiator.
    // Once the participant participate, the premium is redeemed immediately by the participant.
    function participate(bytes32 secretHash)
        public
        payable
        isParticipant(secretHash)
        fulfillPayment(secretHash)
        isEmptyState(secretHash)
        isPremiumFilled(secretHash)
    {
        swaps[secretHash].assetState = AssetState.Filled;
        msg.sender.transfer(swaps[secretHash].premiumValue);
        swaps[secretHash].premiumState = PremiumState.Redeemed;
        
        emit Participated(
            block.timestamp,
            swaps[secretHash].refundTimestamp,
            secretHash,
            swaps[secretHash].initiator,
            msg.sender,
            swaps[secretHash].redeemer,
            swaps[secretHash].refunder,
            msg.value,
            swaps[secretHash].premiumValue
        );
    }

    function redeem(bytes32 secret, bytes32 secretHash)
        public
        isRedeemable(secretHash, secret)
    {
        msg.sender.transfer(swaps[secretHash].value);

        swaps[secretHash].assetState = AssetState.Redeemed;
        swaps[secretHash].secret = secret;

        emit Redeemed(
            block.timestamp,
            secretHash,
            secret,
            msg.sender,
            swaps[secretHash].value,
            swaps[secretHash].premiumValue
        );
    }

    // refund refunds the value back to the refunder..
    // the premium goes back to the initiator if the contract is obsolete.
    function refund(bytes32 secretHash)
        public
        isPremiumFilled(secretHash)
        isRefundable(secretHash)
    {
        msg.sender.transfer(swaps[secretHash].value);
        swaps[secretHash].initiator.transfer(swaps[secretHash].premiumValue);

        swaps[secretHash].assetState = AssetState.Refunded;
        swaps[secretHash].premiumState = PremiumState.Refunded;

        emit Refunded(
            block.timestamp,
            swaps[secretHash].secretHash,
            msg.sender,
            swaps[secretHash].value,
            swaps[secretHash].premiumValue
        );
    }
}
