let test1 = artifacts.require("./SimpleEscrow.sol");
let Contract = require("truffle-contract");
let TokenAbi = require("singularitynet-token-contracts/abi/SingularityNetToken.json");
let TokenNetworks = require("singularitynet-token-contracts/networks/SingularityNetToken.json");
let TokenBytecode = require("singularitynet-token-contracts/bytecode/SingularityNetToken.json");
let Token = Contract({contractName: "SingularityNetToken", abi: TokenAbi, networks: TokenNetworks, bytecode: TokenBytecode});

module.exports = function(deployer, network, accounts) {
    Token.setProvider(web3.currentProvider);
    Token.defaults({from: accounts[0], gas: 4000000});
    const recipient = web3.eth.accounts[4];
    const sender    = web3.eth.accounts[0];
    deployer.deploy(Token, {overwrite: false})
     	     .then((TokenInstance) => deployer.deploy(test1, TokenInstance.address, recipient,  sender, 10000));
};
