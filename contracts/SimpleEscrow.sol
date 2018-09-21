pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract SimpleEscrow {
    address public sender;      // The account sending payments.
    address public recipient;   // The account receiving the payments.
    uint256 public expiration;  // Timeout in case the recipient never closes.
    
    ERC20 public token; // Address of token contract

    constructor (address _token, address  _recipient, address _sender, uint256 duration)
    public
    {
        token      = ERC20(_token);
        sender     = _sender;
        recipient  = _recipient;
        expiration = now + duration;
    }

    //balance of contract
    function token_balance()
    public
	view
	returns(uint256)
    {
        return token.balanceOf(this); 
    }
    
    function transfer_all_tokens_back_and_selfdestruct()
    public
    {
        token.transfer(sender, token.balanceOf(this));
        selfdestruct(sender);
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

    // the recipient can close the channel at any time by presenting a
    // signed amount from the sender. the recipient will be sent that amount,
    // and the remainder will go back to the sender
    function close(uint256 amount, bytes memory signature) 
    public 
    {
        require(msg.sender == recipient);
        require(isValidSignature(amount, signature));
        token.transfer(msg.sender, amount);
        transfer_all_tokens_back_and_selfdestruct();
    }

    /// the sender can extend the expiration at any time
    function extend(uint256 newExpiration) 
    public 
    {
        require(msg.sender == sender);
        require(newExpiration > expiration);

        expiration = newExpiration;
    }

    /// if the timeout is reached without the recipient closing the channel,
    /// then the Ether is released back to the sender.
    function claimTimeout() 
    public 
    {
        require(now >= expiration);
        transfer_all_tokens_back_and_selfdestruct();
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
