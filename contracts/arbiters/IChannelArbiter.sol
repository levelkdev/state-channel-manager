pragma solidity ^0.5.0;

interface IChannelArbiter {
    function channelValueForUpdate(bytes32 channelId, uint256 nonce) external view returns (uint256 value);
}
