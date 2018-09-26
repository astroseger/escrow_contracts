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
* The sender can extend the expiration date and add funds to the contract at any monents. 

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

Comments are selfexplanatory, but few clarifications migth be useful. 

* The full ID of "atomic" payment channel is "[MPEContractAddress, channel_id, nonce]". The MPEContractAdress is the address of MPE contract,
   and we need it to prevent multi contracts attacks. channel_id is a index in the channels mapping. And nonce is a part of close/reopen logic.
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
This permission contains the following message signed by the sender [MPEContractAdress, recipient_address, replica_id, value, expiration], 
which recipient should recieve from the sender off-chain. See usercases for details.

By the following function the recipient can claim funds from the channel.
```Solidity
function channel_claim(uint256 channel_id, uint256 amount, bytes memory signature, bool is_sendback) 
```
The recipent should present the following message signed by the sender [MPEContractAdress, channel_id, nonce, amount].
It should be noted that [MPEContractAdress, channel_id, nonce] is the full ID of "atomic" channel. 

The recipient has two possibility:
* (is_sendback==true)  "close" the channel and send remaining funds back to the sender.
* (is_sendback==false) "close/reopen". We transfer the claimed amount to the recipent, but insted of sending remaning funds to the sender we
  simple change the nonce of the channel. By doing this we close the old atomic channel [MPEContractAdress, channel_id, old_nonce] 
  and open the new one [MPEContractAdress, channel_id, new_nonce]


By the following functions the client can extend expiration time and he can funds the channel at any time.
He also can claim all funds from the channel after the expiration time reached.

```Solidity
function channel_extend(uint256 channel_id, uint256 new_expiration);
function channel_add_funds(uint256 channel_id, uint256 amount);
function channel_extend_and_add_funds(uint256 channel_id, uint256 new_expiration, uint256 amount);
function channel_claim_timeout(uint256 channel_id);
```

  
### Usercases 

#### Simple usercase 

Informal description:

* Client deposit tokens to the MPE. We could propose to everybody to use MPE as a wallet for all theirs AGI tokens (I would have proposed to discuss the possibility of creating AGI tokens via MPE, if they hadn't been already created).
* Client select service provider.
* Client open the payment channel with one of replicas from the choosen region. 
* It should be noted that client can send requiests to any of replicas from the selected region, not only to the replica with which he has the channel (after we implement state-sharing between replicas of the same region)
* Client starts to send requiests to the replicas. With each call he send the signed authorization to take the commulative amount of the tokens which are due.
* At some point server can deside to close/reopen channel in order to fix the profit. At the next call from the client, the server should inform the client that the channel was closed/reopen (that "nonce" of the channel have changed). Client can also obtain this information by listening events from the MPE. Of course, the client should reset "the commulative amount".
* At some point the client can decide to extend expiration data or/and escrow more funds.
* It should be noted that becaouse of two previous items the the channal can exist forever.

Formal example:

Let's assume that the price for one call is 1 AGI. Also I assume that server and client each time perform all required validations. 
For example server check that signature is authentic, that amount is correct, that this amount doesn't exceed value of the channel, that expiration data is tolarable etc.



* CLIENT1 call: open_channel(server=SERVER1, replica=REPLICA1, value=1000 AGI, expiration=now + 1day)
* MPE create the PaymentChanel: [channel_id = 0, sender=CLIENT1, recipient=SERVER1, replica_id=REPLICA1, value=5 AGI, nonce=0, expiration=expiration0]
* MPE subscribe 10 AGI from the balance of the CLIENT1 
* CLIENT1 send to SERVER1/REPLICA1 authorization SIGNED_BY_CLIENT1(ContractAdress=MPEAdress, channel_id=0, nonce=0, amount=1)
* CLIENT1 send to SERVER1/REPLICA1 authorization SIGNED_BY_CLIENT1(ContractAdress=MPEAdress, channel_id=0, nonce=0, amount=2)
* CLIENT1 send to SERVER1/REPLICA1 authorization SIGNED_BY_CLIENT1(ContractAdress=MPEAdress, channel_id=0, nonce=0, amount=3)
* CLIENT1 send to SERVER1/REPLICA1 authorization SIGNED_BY_CLIENT1(ContractAdress=MPEAdress, channel_id=0, nonce=0, amount=4)
* CLIENT1 send to SERVER1/REPLICA1 authorization SIGNED_BY_CLIENT1(ContractAdress=MPEAdress, channel_id=0, nonce=0, amount=5)
* Server desides to close/reopen the channel (fix 5 AGI of profit)
* SERVER1 call: channel_claim(channel_id = 0, amount=5, signature = SIGNED_BY_CLIENT1(ContractAdress=MPEAdress, channel_id=0, nonce=0, amount=5), is_sendback=false)
* MPE add 5 AGI to the balance of SERVER1
* MPE change the nonce (nonce +=1) and value (value -= 5) in the PaymentChannel: [channel_id = 0, sender=CLIENT1, recipient=SERVER1, replica_id=REPLICA1, value=5 AGI, nonce=1, expiration=expiration0]  
* Client recieve information that channel have been reopen (either from the server either from listening the events from the blockchain)
* CLIENT1 send to SERVER1/REPLICA1 authorization SIGNED_BY_CLIENT1(ContractAdress=MPEAdress, channel_id=0, nonce=1, amount=1)
* CLIENT1 send to SERVER1/REPLICA1 authorization SIGNED_BY_CLIENT1(ContractAdress=MPEAdress, channel_id=0, nonce=1, amount=2)
* CLIENT1 send to SERVER1/REPLICA1 authorization SIGNED_BY_CLIENT1(ContractAdress=MPEAdress, channel_id=0, nonce=1, amount=3)
* CLIENT1 send to SERVER1/REPLICA1 authorization SIGNED_BY_CLIENT1(ContractAdress=MPEAdress, channel_id=0, nonce=1, amount=4)
* Client decides to put more funds in the channel and extend it expiration datas.
* CLEINT1 calls channel_extend_and_add_funds(channel_id=0, new_expiration = now + 1day, amount=10 AGI)
* MPE change the value and expiration data in the PaymentChannel: [channel_id = 0, sender=CLIENT1, recipient=SERVER1, replica_id=REPLICA1, value=15 AGI, nonce=0, expiration=expiration1]
* MPE subscribe 10 AGI from the balance of the CLIENT1
* CLIENT1 send to SERVER1/REPLICA1 authorization SIGNED_BY_CLIENT1(ContractAdress=MPEAdress, channel_id=0, nonce=1, amount=5)
* CLIENT1 send to SERVER1/REPLICA1 authorization SIGNED_BY_CLIENT1(ContractAdress=MPEAdress, channel_id=0, nonce=1, amount=6)
* .....
* CLIENT1 send to SERVER1/REPLICA1 authorization SIGNED_BY_CLIENT1(ContractAdress=MPEAdress, channel_id=0, nonce=1, amount=10)
* Server desides to close/reopen the channel (fix 10 AGI of profit)
* .....
* Client decides to put more funds in the channel and extend it expiration datas.
* ....
* Server desides to close/reopen the channel 
* .... 
* This can goes forever
* If server decide to stop work with this client he can close the channel with channel_claim(...., is_sendback=true)
* If server fails to claim funds before timeout (for example he goes offline forever), than clien can claim funds after the expiration date






#### Open the channel from the service side





