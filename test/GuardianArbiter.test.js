const should = require('chai').should()

const GuardianArbiter = artifacts.require('GuardianArbiter')
const ChannelManager = artifacts.require('ChannelManager')
const { soliditySha3 } = web3.utils
const { sign } = web3.eth

const NONCE = 55
const CHANNEL_VALUE = 100

contract.only('GuardianArbiter', (accounts) => {
  const party1 = accounts[1]
  const party2 = accounts[2]
  const guardian = accounts[3]

  it('should allow party to force withdraw with guardian signature', async () => {
    const channelManager = await ChannelManager.new()
    const arbiter = await GuardianArbiter.new(guardian)
    const party1to2ChannelId = await channelManager.getChannelId(party1, party2, arbiter.address)
    const party2to1ChannelId = await channelManager.getChannelId(party2, party1, arbiter.address)

    // party1 and party2 agree to play TicTacToe using guardian to determine the winner

    // party1 deposits in channel
    await channelManager.deposit(party1, party2, arbiter.address, { from: party1, value: CHANNEL_VALUE })
    // party2 deposits in channel
    await channelManager.deposit(party2, party1, arbiter.address, { from: party2, value: CHANNEL_VALUE })

    // party1 signs a payment to party2
    const party2WinsHash = soliditySha3(
        party2,
        party1,
        arbiter.address,
        NONCE,
        CHANNEL_VALUE
    )
    const outcome1Signature = await sign(party2WinsHash, party1) // Never used if party1 wins

    // party2 signs a payment to party1
    const party1WinsHash = soliditySha3(
        party2,
        party1,
        arbiter.address,
        NONCE,
        CHANNEL_VALUE
    )
    const outcome2Signature = await sign(party1WinsHash, party2) // Never used if party2 wins

    // Check the state of the channel from party1 to party2
    const party1to2channel = await channelManager.channels(party1to2ChannelId)
    party1to2channel[0].toNumber().should.be.equal(CHANNEL_VALUE) // depositValue
    party1to2channel[1].toNumber().should.be.equal(0) // valueWithdrawnByReceiver
    party1to2channel[2].toNumber().should.be.equal(0) // nonceOfLastReceiverWithdrawal

    // Check the state of the channel from party2 to party1
    let party2to1channel = await channelManager.channels(party2to1ChannelId)
    party2to1channel[0].toNumber().should.be.equal(CHANNEL_VALUE) // depositValue
    party2to1channel[1].toNumber().should.be.equal(0) // valueWithdrawnByReceiver
    party2to1channel[2].toNumber().should.be.equal(0) // nonceOfLastReceiverWithdrawal

    // party1 wins the game! ＼(＾O＾)／

    // Guardian signs channel update for payment to party1 (winner) but not to party2
    const guardianSignature = await sign(party1WinsHash, guardian)

    // party1 is now able to force a withdrawal
    await arbiter.updateChannel(party2, party1, NONCE, CHANNEL_VALUE, outcome2Signature, guardianSignature)
    await channelManager.forceWithdrawal(party2, party1, arbiter.address, NONCE)

    // Check the final state of the channel from party2 to party1
    party2to1channel = await channelManager.channels(party2to1ChannelId)
    party2to1channel[0].toNumber().should.be.equal(0) // depositValue
    party2to1channel[1].toNumber().should.be.equal(CHANNEL_VALUE) // valueWithdrawnByReceiver
    party2to1channel[2].toNumber().should.be.equal(NONCE) // nonceOfLastReceiverWithdrawal
  })

})
