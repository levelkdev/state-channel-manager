pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "./IChannelArbiter.sol";
import "../ChannelIdentifier.sol";

contract GuardianArbiter is IChannelArbiter, ChannelIdentifier {

    using ECDSA for bytes32;

    // mapping of the channelId to a mapping of the nonce to the channel value
    mapping (bytes32 => mapping(uint256 => uint256)) private updates;
    address public guardian;

    /**
     *  Public functions
     */

    constructor (address _guardian) public {
        guardian = _guardian;
    }

    function updateChannel(
        address sender,
        address receiver,
        uint256 nonce,
        uint256 channelValue,
        bytes memory senderSignature,
        bytes memory guardianSignature
    )
        public
    {
        _validateSignature(sender, receiver, nonce, channelValue, sender, senderSignature);
        _validateSignature(sender, receiver, nonce, channelValue, guardian, guardianSignature);

        bytes32 channelId = getChannelId(sender, receiver, this);
        updates[channelId][nonce] = channelValue;
    }

    function channelValueForUpdate(address sender, address receiver, uint256 nonce) external view returns (uint256 channelValue) {
        bytes32 channelId = getChannelId(sender, receiver, this);
        return updates[channelId][nonce];
    }

    /**
     *  Internal functions
     */

    function _validateSignature(
        address sender,
        address receiver,
        uint256 nonce,
        uint256 channelValue,
        address signer,
        bytes memory signature
    )
      public
    {
      bytes32 messageHash = keccak256(abi.encodePacked(sender, receiver, address(this), nonce, channelValue));
      address recoveredSigner = messageHash.toEthSignedMessageHash().recover(signature);
      require(signer == recoveredSigner, "Invalid signature");
    }

}
