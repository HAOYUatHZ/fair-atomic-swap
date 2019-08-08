# [bitcoin-dev] OP_LOOKUP_OUTPUT proposal

Hi everybody!

Here is a BIP draft brought up by Runchao(CC'ed) and I to enable OP_LOOKUP_OUTPUT and thus to mitigate the arbitrage risk during an Atomic Swap using HTLC.

The problem can be simply decribed as that, the initiator can abort the deal, i.e., have optionality, without receiving any penalty. See https://lists.linuxfoundation.org/pipermail/lightning-dev/2018-May/001292.html and https://lists.linuxfoundation.org/pipermail/lightning-dev/2018-December/001752.html for detail.

We have done some research, including fetching cryptocurrency market history in the last year, and analyzing how profitable the arbitrage can be, given the default timelock setting (24/48 hrs) . Our result shows that the profit can be approximately 1% ~ 2.3%, which is non-negligible compared with 0.3% for stock market, and can be attractive considering it's risk-free. We formalize these into a paper: https://eprint.iacr.org/2019/896, and the related codes lie in https://github.com/HAOYUatHZ/fair-atomic-swap.

To understand it better, you may also like to refer to: 

+ https://en.bitcoin.it/wiki/Atomic_swap#Financial_optionality
+ https://blog.bitmex.com/atomic-swaps-and-distributed-exchanges-the-inadvertent-call-option/

A few studies have been put into efforts, e.g., http://diyhpl.us/wiki/transcripts/scalingbitcoin/tokyo-2018/atomic-swaps/ and https://coblox.tech/docs/financial_crypto19.pdf, using the premium mechanism as the collateral. The basic idea is that, the transaction for the premium needs to be locked with the same secret hash but with a flipped payout, i.e. when redeemed with the secret, the money goes back to Alice and after timelock, the premium goes to Bob as a compensation for Alice not revealing the secret. However, this introduces a new problem: Bob can get the premium without paying anything, by never participating in.

To solve this, we need to know the status of a related transaction. Unfortunately, Bitcoin does not support the stateful transaction functionalities. 

Therefore, we propose the new opcode: OP_LOOKUP_OUTPUT. It takes the id of an output, and produces the address of the output’s owner. With OP_LOOKUP_OUTPUT, the Bitcoin script can decide whether Alice or Bob should take the premium by “<output> OP_LOOKUP_OUTPUT <pubkeyhash> OP_EQUALVERIFY”.

Assume that Alice and Bob exchange asset1 and asset2, and using premium (same asset type as asset2) as the collateral.

A sample premium transaction implementation of Atmoic Swap for Spot based on this opcode is:
```
ScriptSig:
    Redeem: <Bob_sig> <Bob_pubkey> 1
    Refund: <Alice_sig> <Alice_pubkey> 0
ScriptPubKey:
    OP_IF // Normal redeem path
        // the owner of <asset2_output> should be Alice
        // which means Alice has redeemed asset2
        <asset2_output> OP_LOOKUP_OUTPUT <Alice_pubkeyhash> OP_EQUALVERIFY 
        OP_DUP OP_HASH160 <Bob_pubkeyhash>
    OP_ELSE // Refund path
        // the premium timelock should be expired
        <locktime> OP_CHECKLOCKTIMEVERIFY OP_DROP
        OP_DUP OP_HASH160 <Alice pubkey hash>
    OP_ENDIF
    OP_EQUALVERIFY
    OP_CHECKSIG
```

We also explore the Atomic Swaps in American Call Options scenario, which is different from the Spot scenario. Alice should pay for the premium besides the underlying asset, regardless of whether the swap is successful or not. In reality, the option sellers are trustworthy - the option sellers never abort the contract. However, in Atomic Swaps, Bob can abort the contracts like Alice. To keep the Atomic Swap consistent with the American Call Options, the premium should follow that: Alice pays the premium to Bob if 1) Alice redeems Bob’s asset before Bob’s timelock, or 2) Bob refunds his asset after Bob’s timelock but before Alice’s timelock. If Alice’s timelock expires, Alice can refund her premium back.

A sample premium transaction implementation of Atmoic Swap for Option based on this opcode is:
```
ScriptSig:
    Redeem: <Bob_sig> <Bob_pubkey> 1
    Refund: <Alice_sig> <Alice_pubkey> 0
ScriptPubKey:
    OP_IF // Normal redeem path
        // the owner of the asset2 should not be the contract
        // it should be either (redeemde by) Alice or (refunded by) Bob
        // which means Alice has redeemed asset2
        <asset2_output> OP_LOOKUP_OUTPUT <Alice_pubkeyhash> OP_NUMEQUAL
        <asset2_output> OP_LOOKUP_OUTPUT <Bob_pubkeyhash> OP_NUMEQUAL
        OP_ADD 1 OP_NUMEQUALVERIFY
        OP_DUP OP_HASH160 <Bob_pubkeyhash>
    OP_ELSE // Refund path
        // the premium timelock should be expired
        <locktime> OP_CHECKLOCKTIMEVERIFY OP_DROP
        OP_DUP OP_HASH160 <Alice pubkey hash>
    OP_ENDIF
    OP_EQUALVERIFY
    OP_CHECKSIG
```

The BIP draft can be found here:
https://github.com/HAOYUatHZ/bips/blob/bip-lookup_output/bip-lookup_output.mediawiki

To conclude, in order to avoid the risk-free optionality in Atomic Swap, we propose a new opcode OP_LOOKUP_OUTPUT, using premium to mitigate the risk of Atomic Swap both in Spot and in Option.