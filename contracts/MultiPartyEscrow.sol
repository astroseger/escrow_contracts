pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract MultiPartyEscrow {
    using SafeMath for uint256;
    

    struct PaymentChannel {
        address sender;      // The account sending payments.
        address receiver;    //The account receiving the payments.
        uint32  replica_id;   //this is effectivly part of the reciver ID
        uint256 value;       // Total amount of tokens deposited to the channel. 
        uint32  nonce;       // "id" of the channel (after parly closed channel) 
        uint256 expiration;  // Timeout in case the recipient never closes.
    }


    mapping (uint256 => PaymentChannel) public channels;
    mapping (address => uint256)        public balances; //tokens which have been deposit but haven't been escrowed in the channels
    
    uint256 next_channel; //id of the next channel
 
    ERC20 public token; // Address of token contract


    constructor (address _token)
    public
    {
        token = ERC20(_token);
    }

    
    function deposit(uint256 value) 
    public 
    {
        require(token.transferFrom(msg.sender, this, value), "Unable to transfer token to the contract"));
        balances[msg.sender] += value;
    }
    
    function withdraw(uint256 value)
    public
    {
        require(balances[msg.sender] >= value)
        require(token.transfer(msg.sender, value))
        balances[msg.sender] -= value
    }
    
    //open a channel, tokan should be already being deposit
    function open_channel(address  _recipient, uint256 value, uint256 _expiration, uint256 _replica_id) 
    public 
    {
        require(balances[msg.sender] >= value)
        channels[next_channel++] = PaymentChannel({
            sender       : msg.sender,
            recipient    : _recipient,
            value        : value,
            replica_id   : _replica_id,
            nonce        : 0,
            expiration   : _expiration,
        });
        balances[msg.sender] -= value
//        emit DidOpen(channelId, msg.sender, receiver, value, tokenContract);
    }
    
    function deposit_and_open_channel(address  _recipient, uint256 value, uint256 _expiration, uint256 _replica_id)
    public
    {
        require(deposit(value));
        open_channel(_recipient, value, _expiration, _replica_id);
    }


    function channel_refund_and_reopen(uint256 channel_id)
    private
    {
        PaymentChannel storage channel = channels[channel_id];
        balances[channel.sender]      += channel.value 
        channel.value                  = 0
        channel.nonce                 += 1
        channel.expiration             = 0
    }

    // the recipient can close the channel at any time by presenting a
    // signed amount from the sender. the recipient will be sent that amount,
    // and the remainder will go back to the sender
    function channel_claim(uint256 channel_id, uint256 amount, bytes memory signature) 
    public 
    {
        PaymentChannel storage channel = channels[channel_id];
        
        require(amount <= channel.value)
        
        require(msg.sender == channel.recipient);
        require(isValidSignature(amount, channel.replica_id, channel.nonce, signature));
        
        balances[msg.sender] += amount;
        channels[channel_id] -= amount;

        channel_refund_and_reopen(channel_id);
    }

    function channel_claim_and_reopen(uint256 channel_id, uint256 amount, bytes memory signature) 
    public 
    {
        PaymentChannel storage channel = channels[channel_id];
        
        require(amount <= channel.value)
        
        require(msg.sender == channel.recipient);
        require(isValidSignature(amount, channel.replica_id, channel.nonce, signature));
        
        balances[msg.sender] += amount;
        channels[channel_id] -= amount;
        
        channels[channel_id].nonce += 1
    }


    /// the sender can extend the expiration at any time
    function channel_extend(uint256 channel_id, uint256 new_expiration) 
    public 
    {
        PaymentChannel storage channel = channels[channel_id];

        require(msg.sender == channel.sender);
        require(new_expiration > channel.expiration);

        channels[channel_id] = new_expiration;
    }

    // sender can claim refund if the timeout is reached 
    function channel_claim_timeout(uint256 channel_id) 
    public 
    {
        require(msg.sender == channel[channel_id].sender)
        require(now >= channel[channel_id].expiration);
        channel_refund_and_reopen();
    }


    function isValidSignature(uint256 amount, bytes memory signature)
    internal
    view
	returns (bool)
    {
        bytes32 message = prefixed(keccak256(abi.encodePacked(this, amount)));

        // check that the signature is from the payment sender
        return recoverSigner(message, signature) == sender;
    }

    function splitSignature(bytes memory sig)
    internal
    pure
    returns (uint8 v, bytes32 r, bytes32 s)
    {
        require(sig.length == 65);

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte
            v := and(mload(add(sig, 65)), 255)
        }
        
        if (v < 27) v += 27;

        return (v, r, s);
    }

    function recoverSigner(bytes32 message, bytes memory sig)
    internal
    pure
    returns (address)
    {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    /// builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) 
    {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}
