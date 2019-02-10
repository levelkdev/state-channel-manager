function toEthSignedMessageHash (messageHex) {
  const messageBuffer = Buffer.from(messageHex.substring(2), 'hex');
  const prefix = Buffer.from(`\u0019Ethereum Signed Message:\n${messageBuffer.length}`);
  return web3.utils.sha3(Buffer.concat([prefix, messageBuffer]));
}

const soliditySha3 = web3.utils.soliditySha3

const sign = web3.eth.sign;

module.exports = {
  soliditySha3,
  toEthSignedMessageHash,
  sign
}
