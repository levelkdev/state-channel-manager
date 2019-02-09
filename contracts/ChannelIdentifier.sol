pragma solidity ^0.5.0;

import "./arbiters/IChannelArbiter.sol";

contract ChannelIdentifier {
    function getChannelId(address sender, address receiver, IChannelArbiter arbiter) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(sender, receiver, address(arbiter)));
    }
}
