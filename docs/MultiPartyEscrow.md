# MultiPartyEscrow contract

### Introduction

The MultiPartyEscrow contract (hereafter MPE) have two main functionalites:

1. Very simple wallet with deposit and withdrow functions. Everybody can deposit AGI
tokens into MPE, using deposit fuction, and everybody can withdrow
their funds (which are not escrowed at the moment).
2. The set of the simple ("atomic") unidirectional payment channels
between clients and services providers and functions for manipulation
of these channels. 

This documents is organazed as following: 

### deposit/withdraw functions.

Almost nothing to add here (see Introduction).  

### Atomic unidirectional payment channel

You can skip this section if you familiar with it.

 The main logical building block of MPE is a simple ("atomic")
unidirectional payment channel. You can find the implementation of
escrow contract for the simple payment channel in
[SimpleEscrow.sol](https://github.com/astroseger/escrow_contracts/blob/master/contracts/SimpleEscrow.sol).

The main logic is following. 

* The sender creates escrow contract with given expiration date and he funds it with
  desired amount of tokens.
* Each time when the sender needs to send a small amount of tokens to
  the recipent he
  sends (to the reciepent) the signed authorization to close the channel and
  take from the channel the commulative amount of the tokens which are due.
* The recipent must check that authorization is correctly signed and
  the amount is corect, and that amount is not exceed the funds being
  escrowed. 
* The recipient can close the channel at any time by presenting a
  signed amount from the sender.  Of course it is beter for recipent to
  close the channel with the last authorization (with highest amount).
  The recipient will be sent that amount, and the remainder will go back
  to the sender.
* The sender can close the channel after expiration date and take all
  funds back.
* The sender can extend the expiration date add funds to the contract at any monents. 

### The set of channels and useful functions

Each "atomic" payment channel in MPE is represented by the following structure 

```Solidity
       //the full ID of "atomic" payment channel = "[this, channel_id, nonce]"
    struct PaymentChannel {
        address sender;      // The account sending payments.
        address recipient;    // The account receiving the payments.
        uint256 replica_id;  // id of particular service replica
        uint256 value;       // Total amount of tokens deposited to the channel. 
        uint256 nonce;       // "nonce" of the channel (by changing nonce we effectivly close the old channel ([this, channel_id, old_nonce])
                             //  and open the new channel [this, channel_id, new_nonce]) 
        uint256 expiration;  // Timeout in case the recipient never closes.
    }

mapping (uint256 => PaymentChannel) public channels;

```

Comments are selfexplanatory, but few commets are needed. 

* The full ID of "atomic" payment channel is "[MPEContractAddress, channel_id, nonce]", there MPEContractAdress is 
  the address of MPE contract (in order to prevent multi contract attack), channel_id is the index in channels mapping and nonce is 
  a nonce in PaymentChannel struct. 
* by changing nonce we effectivly close the old channel ([MPEContractAddress, channel_id, old_nonce])
  and open the new channel [MPEContractAddress,, channel_id, new_nonce]). It will be explained in more details later.
* The full ID of the recipient is actually [recipient, replica_id]. By doing this we allow service provider to use the
  same ethereum wallet for different replica.




