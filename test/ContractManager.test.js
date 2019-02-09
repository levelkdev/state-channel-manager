const { toWei } = web3.utils
const should = require('chai').should();

const ContractManager = artifacts.require('ChannelManager')
const PaymentChannelArbiter = artifacts.require('PaymentChannelArbiter')

const FINAL_NONCE = 55
const INITIAL_DEPOSIT = 1000
const FINAL_CHANNEL_VALUE = 600

contract('ContractManager', (accounts) => {
  const sender = accounts[1]
  const receiver = accounts[2]

  it('should allow cooperative withdrawal from state channel', async () => {
    const contractManager = await ContractManager.new()
    const arbiter = await PaymentChannelArbiter.new()
    const participants = [sender, receiver, arbiter.address]
    let channel

    const channelId = await contractManager.getChannelId(...participants)

    // Make deposit into the channel for sender, receiver, arbiter.address
    await contractManager.deposit(...participants, { from: sender, value: INITIAL_DEPOSIT })

    // Channel {
    //     depositValue: 1000
    //     valueWithdrawnByReceiver: 0
    //     nonceOfLastReceiverWithdrawal: 0
    // }
    channel = await contractManager.channels(channelId)
    channel[0].toNumber().should.be.equal(INITIAL_DEPOSIT)
    channel[1].toNumber().should.be.equal(0)
    channel[2].toNumber().should.be.equal(0)

    // 55 channel updates are signed and sent to receiver with the final update:
    // { nonce: 55, channelValue: 1000 }

    // Receiver requests withdrawal
    await contractManager.requestWithdrawal(...participants, FINAL_NONCE, FINAL_CHANNEL_VALUE, { from: receiver })
    // Sender approves withdrawal
    await contractManager.completeWithdrawal(...participants, FINAL_NONCE, FINAL_CHANNEL_VALUE, { from: sender })

    // Channel {
    //     depositValue: 400
    //     valueWithdrawnByReceiver: 600
    //     nonceOfLastReceiverWithdrawal: 55
    // }
    channel = await contractManager.channels(channelId)
    channel[0].toNumber().should.be.equal(INITIAL_DEPOSIT - FINAL_CHANNEL_VALUE)
    channel[1].toNumber().should.be.equal(FINAL_CHANNEL_VALUE)
    channel[2].toNumber().should.be.equal(FINAL_NONCE)

    const remainingDeposit = INITIAL_DEPOSIT - FINAL_CHANNEL_VALUE
    // Sender requests withdrawal
    await contractManager.requestWithdrawal(...participants, FINAL_NONCE, remainingDeposit, { from: sender })
    // Receiver approves withdrawal
    await contractManager.completeWithdrawal(...participants, FINAL_NONCE, remainingDeposit, { from: receiver })

    // Channel {
    //     depositValue: 0
    //     valueWithdrawnByReceiver: 600
    //     nonceOfLastReceiverWithdrawal: 55
    // }
    channel = await contractManager.channels(channelId)
    channel[0].toNumber().should.be.equal(0)
    channel[1].toNumber().should.be.equal(FINAL_CHANNEL_VALUE)
    channel[2].toNumber().should.be.equal(FINAL_NONCE)
  })
})
