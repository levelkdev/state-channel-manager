# State Channel Manager

An extensible state channel manager for Ethereum.

The goals of this state channel implementation are to:
 - Minimize the marginal gas cost of using a state channel
 - Handle generalized state channels and counterfactual instantiation



A single `ChannelManager` contract manages all unidirectional state channels. For simplicity, there is no "opening" or "closing" channels. Each channel lives for the entire life of the `ChannelManager` contract and can be deposited into and withdrawn from.

The `ChannelManager` contract does not directly handle any dispute resolution or signed messages, just the state channel deposits. Each channel references an external arbiter contract that will return the correct channel value in case of a dispute. State channels are identified by their sender, receiver, and the arbiter contract address.

Arbiter contracts must implement the `IChannelArbiter` interface:

```solidity
interface IChannelArbiter {
  function channelValueForUpdate(address sender, address receiver, uint256 nonce) external view returns (uint256 value);
}
```

Arbiter contracts can be used for a single state channel or multiple channels. If a channel does not have a previously deployed arbiter contract, the arbiter contract can be deployed counterfactually and only used in case of a dispute.

### Contracts

__ChannelManager.sol__

Central contract that manages all deposits. Each deposit is tied to a unidirectional state channel.


### Get started
```bash
$ npm install
```
After pulling down the repo for the first time, run `chmod +x scripts/**` to make scripts executable.

### Compile contracts
```bash
$ npm run compile
```

### Run tests
```bash
$ npm test
```

Todo: Write README
