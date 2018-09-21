"use strict";
var  SimpleEscrow = artifacts.require("./SimpleEscrow.sol");

let Contract = require("truffle-contract");
let TokenAbi = require("singularitynet-token-contracts/abi/SingularityNetToken.json");
let TokenNetworks = require("singularitynet-token-contracts/networks/SingularityNetToken.json");
let TokenBytecode = require("singularitynet-token-contracts/bytecode/SingularityNetToken.json");
let Token = Contract({contractName: "SingularityNetToken", abi: TokenAbi, networks: TokenNetworks, bytecode: TokenBytecode});
Token.setProvider(web3.currentProvider);

var ethereumjsabi  = require('ethereumjs-abi');
var ethereumjsutil = require('ethereumjs-util');
let sign_funs      = require('./sign_funs');

console.log(sign_funs)

  
contract('SimpleEscrow', function(accounts) {

    var escrow;
    var token_address;
    var token;
    

    before(async () => 
        {
            escrow        = await SimpleEscrow.deployed();
            token_address = await escrow.token.call();
            token         = Token.at(token_address);
        });


    it ("Initial openning", async function()
        { 
          
            let balance0 = (await escrow.token_balance.call()).toNumber();
            assert.equal(balance0, 0, "Initial balance should be zero");

            let rez     = await token.transfer(escrow.address, 42000, {from:accounts[0]});
            let balance = (await escrow.token_balance.call()).toNumber();
            
            assert.equal(balance, 42000, "Balance after transfer should be 42000")
        }); 
    it("Fail to Claim timeout ", async function()
        {
           try { await escrow.claimTimeout(); }
            catch(e) {
                assert(e.message.indexOf('revert') >= 0, "error message must contain revert");
            }
        });
    it ("Close with right signature but wrong amount or address", async function()
        {  
            //Right signature
            let sgn = await sign_funs.wait_signed_message(accounts[0], escrow.address, 41000);
            
            //I. Wrong Amount
            try {await escrow.close(40999, sgn.toString("hex"), {from:accounts[4]});}
            catch(e) {
                assert(e.message.indexOf('revert') >= 0, "error message must contain revert");
            }

            //II. Wrong Sender (all except right one should fail)
            for (var i = 0; i < 10 ; i++) 
                if (i != 4)
                {
                    try {await escrow.close(41000, sgn.toString("hex"), {from:accounts[i]});}
                    catch(e) {
                        assert(e.message.indexOf('revert') >= 0, "error message must contain revert");
                    }
                }   
       });
     it ("Close with wrong signature (wrong address)", async function()
        {   
           //I. wrong address

            //sign message by the privet key of accounts[1]
            for (var i = 0; i < 10 ; i++)
                if (i != 0) 
                {

                    var sgn = await sign_funs.wait_signed_message(accounts[i], escrow.address, 41000);
                    try {await escrow.close(41000, sgn.toString("hex"), {from:accounts[4]});}
                    catch(e) {
                        assert(e.message.indexOf('revert') >= 0, "error message must contain revert");
                    }
                }

            //wrong escrow contract address
            var sgn = await sign_funs.wait_signed_message(accounts[0], accounts[4], 41000);
            try {await escrow.close(41000, sgn.toString("hex"), {from:accounts[4]});}
            catch(e) {
                assert(e.message.indexOf('revert') >= 0, "error message must contain revert");
            } 
 
       });



    it ("Check validity of the signature with js-server part", async function()
        {   
            let sgn = await sign_funs.wait_signed_message(accounts[0], escrow.address, 41000);
            assert.equal(sign_funs.isValidSignature(escrow.address, 41000 ,sgn, accounts[0]) , true,  "error signature should be ok")
            assert.equal(sign_funs.isValidSignature(escrow.address, 41000 ,sgn, accounts[1]) , false, "error signature should be false")
            assert.equal(sign_funs.isValidSignature(escrow.address, 41001 ,sgn, accounts[0]) , false, "error signature should be false")
            assert.equal(sign_funs.isValidSignature(accounts[4],    41000 ,sgn, accounts[0]) , false, "error signature should be false")

            let sgn_false = await sign_funs.wait_signed_message(accounts[1], escrow.address, 41000);
            assert.equal(sign_funs.isValidSignature(escrow.address, 41000 ,sgn_false, accounts[0]) , false,  "error signature should be false")
      

        });



    it ("closing transaction", async function()
        {   
           
            //sign message by the privet key of accounts[0]
            let sgn = await sign_funs.wait_signed_message(accounts[0], escrow.address, 41000);
            await escrow.close(41000, sgn.toString("hex"), {from:accounts[4]});
            let balance4 = await token.balanceOf.call(accounts[4]);
            assert.equal(balance4, 41000, "After closure balance of accounts[4] should be 41000");
       });





});

