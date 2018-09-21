var ethereumjsabi  = require('ethereumjs-abi');
var ethereumjsutil = require('ethereumjs-util');


function sleep(ms) 
{
  return new Promise(resolve => setTimeout(resolve, ms));
}


function constructPaymentMessage(contractAddress, amount) 
{
    return ethereumjsabi.soliditySHA3(
        ["address", "uint256"],
        [contractAddress, amount]
    );
}

function signMessage(from_account, message, callback) 
{
    web3.eth.sign(from_account, "0x" + message.toString("hex"), callback)
}


function signPayment(from_account, contractAddress, amount, callback) 
{
    var message = constructPaymentMessage(contractAddress, amount);
    signMessage(from_account, message, callback);
}


// this mimics the prefixing behavior of the eth_sign JSON-RPC method.
function prefixed(hash) {
    return ethereumjsabi.soliditySHA3(
        ["string", "bytes32"],
        ["\x19Ethereum Signed Message:\n32", hash]
    );
}

function recoverSigner(message, signature) {
    var split = ethereumjsutil.fromRpcSig(signature);
    var publicKey = ethereumjsutil.ecrecover(message, split.v, split.r, split.s);

    var signer = ethereumjsutil.pubToAddress(publicKey).toString("hex");
    return signer;
}

function isValidSignature(contractAddress, amount, signature, expectedSigner) {
    var message = prefixed(constructPaymentMessage(contractAddress, amount));
    var signer = recoverSigner(message, signature);
    return signer.toLowerCase() ==
        ethereumjsutil.stripHexPrefix(expectedSigner).toLowerCase();
}



async function wait_signed_message(from_account, contractAddress, amount)
{
    let det_wait = true;
    let rez_sign;
    signPayment(from_account, contractAddress, amount, function(err,sgn)
        {   
            det_wait = false;
            rez_sign = sgn
        });
    while(det_wait)
    {
        await sleep(1)
    }
    return rez_sign;
} 

module.exports.wait_signed_message = wait_signed_message;
module.exports.isValidSignature    = isValidSignature;
