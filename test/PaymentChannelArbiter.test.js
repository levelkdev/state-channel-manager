const should = require('chai').should()

const PaymentChannelArbiter = artifacts.require('PaymentChannelArbiter')
const { soliditySha3 } = web3.utils
const { sign } = web3.eth

const NONCE = 55
const CHANNEL_VALUE = 600

contract('PaymentChannelArbiter', (accounts) => {
  const sender = accounts[1]
  const receiver = accounts[2]

  it('should store valid channel update', async () => {
    const arbiter = await PaymentChannelArbiter.new()

    const messageHash = soliditySha3(
      sender,
      receiver,
      arbiter.address,
      NONCE,
      CHANNEL_VALUE)
    const signature = await sign(messageHash, sender)

    await arbiter.updateChannel(sender, receiver, NONCE, CHANNEL_VALUE, signature)
    const channelValue = await arbiter.channelValueForUpdate(sender, receiver, NONCE)
    channelValue.toNumber().should.be.equal(CHANNEL_VALUE)
  })

})
