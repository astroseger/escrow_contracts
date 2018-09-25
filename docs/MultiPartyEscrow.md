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

### The set of channels and functions to manipalate them

##### PaymentChannel structure

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

Comments are selfexplanatory, but few explanation migth be useful. 

* The full ID of "atomic" payment channel is "[MPEContractAddress, channel_id, nonce]". The MPEContractAdress is the address of MPE contract,
   and we need it prevent multi contracts attacks. channel_id is a index in the channels mapping. And nonce is a part close/reopen logic.
* by changing nonce we effectivly close the old channel [MPEContractAddress, channel_id, old_nonce]
  and open the new channel [MPEContractAddress, channel_id, new_nonce]. How we use it will be explained later.
* The full ID of the recipient is [recipient, replica_id]. By doing this we allow service provider to use the
  same ethereum wallet for different replicas.

##### Functions 

The following function open the new "atomic" channel assuming that the caller is the sender.
```Solidity
function open_channel(address  recipient, uint256 value, uint256 expiration, uint256 replica_id)
```
This function simply create new PaymentChannel structure and add it to the channels list.

The following function open the channel from the recipient side.
```Solidity
function open_channel_by_recipient(address  sender, uint256 value, uint256 expiration, uint256 replica_id, bytes memory signature)
```
The recipient should have the singed permission from the sender to open a channel. 
This permission contains the following signed message [MPEContractAdress, recipient_address, replica_id, value, expiration], 
which should be sended off-chain. See usercases for details.

  

 
### Usercases 

#### Usual useflow

#### Open the channel from the service side





