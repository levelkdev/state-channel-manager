pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/utils/address.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./ChannelIdentifier.sol";
import "./arbiters/IChannelArbiter.sol";

contract ChannelManager is ChannelIdentifier {

    using Address for address;
    using SafeMath for uint256;

    uint256 constant DISPUTE_PERIOD = 1 days;

    // Error messages
    string constant INVALID_PARTICIPANT = "Invalid channel participant address";
    string constant INVALID_ARBITER = "Invalid arbiter address";
    string constant WITHDRAWAL_COMPLETE = "Withdrawal has already been completed";
    string constant WITHDRAWAL_BLOCKED = "Withdrawal has been blocked by the sender";
    string constant INSUFFICIENT_VALUE = "Insufficient value in channel";
    string constant INVALID_NONCE = "Can not withdraw with past nonce";

    struct Channel {
        uint256 depositValue;
        uint256 valueWithdrawnByReceiver;
        uint256 nonceOfLastReceiverWithdrawal;
    }

    struct Withdrawal {
        uint256 value;
        bool complete;
        bool blocked;
        uint256 openedTime;
        address counterparty;
    }

    mapping (bytes32 => Channel) public channels;
    mapping(bytes32 => Withdrawal) public withdrawals;

    modifier onlyParticipant(address sender, address receiver) {
        require(sender != address(0), INVALID_PARTICIPANT);
        require(receiver != address(0), INVALID_PARTICIPANT);
        require(msg.sender == sender || msg.sender == receiver, "Only channel participants can access this function");
        _;
    }

    /**
     *  Public functions
     */

    function deposit(address sender, address receiver, IChannelArbiter arbiter) public payable {
        bytes32 channelId = getChannelId(sender, receiver, arbiter);
        channels[channelId].depositValue += msg.value;
    }

    function requestWithdrawal(
        address sender,
        address receiver,
        IChannelArbiter arbiter,
        uint256 nonce,              // Not used if msg.sender is sender
        uint256 value
    )
        public
        onlyParticipant(sender, receiver)
    {
        require(address(arbiter) != address(0), INVALID_ARBITER); 
        bytes32 channelId = getChannelId(sender, receiver, arbiter);
        if (msg.sender == receiver) {
            require(nonce > channels[channelId].nonceOfLastReceiverWithdrawal, INVALID_NONCE);
        }
        Withdrawal storage withdrawal = withdrawals[getWithdrawalId(channelId, nonce, msg.sender)];
        require(!withdrawal.complete, WITHDRAWAL_COMPLETE);
        require(!withdrawal.blocked, WITHDRAWAL_BLOCKED);
        
        withdrawal.value = value;
        withdrawal.openedTime = now;
        // Set counterparty to the participant that is not msg.sender
        withdrawal.counterparty = msg.sender == receiver ? sender : receiver;
    }

    function completeWithdrawal(
        address payable sender,
        address payable receiver,
        IChannelArbiter arbiter,
        uint256 nonce,
        uint256 value
    )
        public
        onlyParticipant(sender, receiver)
    {
        require(address(arbiter) != address(0), INVALID_ARBITER);
        bytes32 channelId = getChannelId(sender, receiver, arbiter);
        Channel storage channel = channels[channelId];
        
        // Set requester to the channel participant that is not msg.sender
        address payable requester = msg.sender == receiver ? sender : receiver;
        Withdrawal storage withdrawal = withdrawals[getWithdrawalId(channelId, nonce, requester)];
        require(!withdrawal.complete, WITHDRAWAL_COMPLETE);
        require(!withdrawal.blocked, WITHDRAWAL_BLOCKED);
        
        // If sender does not agree with the withdrawal's value, withdrawal is blocked and receiver must force withdraw
        if (msg.sender == sender && value != withdrawal.value) {
            withdrawal.blocked = true;
            return;
        }
        
        require(value == withdrawal.value, "Withdrawal must be completed with same value");
        // Either msg.sender is the counterparty or the dispute period is past to complete the withdrawal
        require(
            msg.sender == withdrawal.counterparty || withdrawal.openedTime + DISPUTE_PERIOD < now, 
            "Invalid caller or withdrawal dispute period has not passed"
        );
        
        // Complete the withdrawal
        withdrawal.complete = true;
        
        if (requester == sender) {
            _senderWithdrawal(channel, sender, value);
        } else {
            _receiverWithdrawal(channel, receiver, nonce, value);
        }
    }

    function forceWithdrawal(
        address sender,
        address payable receiver,
        IChannelArbiter arbiter,
        uint256 nonce
    ) 
        public
    {
        require(sender != address(0), INVALID_PARTICIPANT);
        require(receiver != address(0), INVALID_PARTICIPANT);
        require(address(arbiter).isContract(), "Arbiter contract has not been deployed");
        
        bytes32 channelId = getChannelId(sender, receiver, arbiter);
        Channel storage channel = channels[channelId];
        
        uint256 channelValue = arbiter.channelValueForUpdate(channelId, nonce);
        uint256 valueAvailable = channelValue.sub(channel.valueWithdrawnByReceiver);
        _receiverWithdrawal(channel, receiver, nonce, valueAvailable);
    }

    function getWithdrawalId(bytes32 channelId, uint256 nonce, address requester) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(channelId, nonce, requester));
    }

    /**
     *  Private functions
     */

    function _senderWithdrawal(Channel storage channel, address payable sender, uint256 value) private {
        require(value <= channel.depositValue, INSUFFICIENT_VALUE);
        channel.depositValue -= value;
        sender.transfer(value);
    }

    function _receiverWithdrawal(Channel storage channel, address payable receiver, uint256 nonce, uint256 value) private {
        require(value <= channel.depositValue, INSUFFICIENT_VALUE);
        require(nonce > channel.nonceOfLastReceiverWithdrawal, INVALID_NONCE);
        channel.nonceOfLastReceiverWithdrawal = nonce;
        
        channel.depositValue -= value;
        channel.valueWithdrawnByReceiver += value;
        receiver.transfer(value);
    }
}
