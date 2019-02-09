pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "./IChannelArbiter.sol";
import "../ChannelIdentifier.sol";

contract PaymentChannelArbiter is IChannelArbiter, ChannelIdentifier {
    
    using ECDSA for bytes32;

    // mapping of the channelId to a mapping of the nonce to the channel value
    mapping (bytes32 => mapping(uint256 => uint256)) private updates;

    function updateChannel(
        address sender, 
        address receiver,
        uint256 nonce,
        uint256 value,
        bytes memory signature
    )
        public
    {
        bytes32 messageHash = keccak256(abi.encodePacked(sender, receiver, address(this), nonce, value));
        address signer = messageHash.toEthSignedMessageHash().recover(signature);
        require(signer == msg.sender, "Invalid signer");
        
        bytes32 channelId = getChannelId(sender, receiver, this);
        updates[channelId][nonce] = value;
    }

    function channelValueForUpdate(bytes32 channelId, uint256 nonce) external view returns (uint256 value) {
        return updates[channelId][nonce];
    }

}
