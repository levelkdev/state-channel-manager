pragma solidity ^0.5.0;

interface IChannelArbiter {
    function channelValueForUpdate(address sender, address receiver, uint256 nonce) external view returns (uint256 value);
}
