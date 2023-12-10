// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// PUSH Comm Contract Interface
interface IPUSHCommInterface {
    function sendNotification(
        address _channel,
        address _recipient,
        bytes calldata _identity
    ) external;
}

struct Protocol {
    address channel;
    bool isRegistered;
}
struct Message {
    uint256 identity;
    uint256 notif;
    string title;
    string body;
}

contract Messaging is Ownable {
    // EPNS COMM ADDRESS ON ETHEREUM Sepolia, CHECK THIS: https://docs.epns.io/developers/developer-tooling/epns-smart-contracts/epns-contract-addresses
    address constant EPNS_COMM_ADDRESS =
        0x0C34d54a09CFe75BCcd878A469206Ae77E0fe6e7;
    mapping(address => Message[]) public protocolMessages;
    mapping(address => address[]) public registeredForProtocols;
    mapping(address => Protocol) public registeredProtocols;

    event RegisterProtocol(address indexed protocol, address indexed channel);
    event RegisteredForProtocol(address indexed user, address indexed protocol);

    error UnregisteredProtocol();
    error UserNotRegisteredForProtocol();

    modifier isRegisteredProtocol(address _protocol) {
        if (!registeredProtocols[_protocol].isRegistered)
            revert UnregisteredProtocol();
        _;
    }

    modifier hasUserRegisteredForProtocol(address _user, address _protocol) {
        bool _registered = _isRegisteredForProtocol(_user, _protocol);
        if (!_registered) revert UserNotRegisteredForProtocol();
        _;
    }

    constructor() Ownable(msg.sender) {}

    /**
     *** Owner Functions
     **/

    function registerProtocol(
        address _protocol,
        address _channel
    ) external onlyOwner {
        registeredProtocols[_protocol].isRegistered = true;
        registeredProtocols[_protocol].channel = _channel;
        emit RegisterProtocol(_protocol, _channel);
    }

    /**
     *** Public Functions
     **/

    function registerForProtocol(address _protocol) external {
        registeredForProtocols[msg.sender].push(_protocol);
        emit RegisteredForProtocol(msg.sender, _protocol);
    }

    function sendMessage(
        Message memory _message,
        address _to
    ) external isRegisteredProtocol(msg.sender) returns (bool success) {
        protocolMessages[msg.sender].push(_message);
        _to = _message.notif == 1
            ? registeredProtocols[msg.sender].channel
            : _to;

        IPUSHCommInterface(EPNS_COMM_ADDRESS).sendNotification(
            registeredProtocols[msg.sender].channel, // from channel
            _to, // to recipient, put address(this) in case you want Broadcast or Subset. For Targeted put the address to which you want to send
            bytes(
                string(
                    // We are passing identity here: https://docs.epns.io/developers/developer-guides/sending-notifications/advanced/notification-payload-types/identity/payload-identity-implementations
                    abi.encodePacked(
                        Strings.toString(_message.identity), // this represents minimal identity, learn more: https://push.org/docs/notifications/notification-standards/notification-standards-advance/#notification-identity
                        "+", // segregator
                        Strings.toString(_message.notif), // define notification type:  https://push.org/docs/notifications/build/types-of-notification (1, 3 or 4) = (Broadcast, targeted or subset)
                        "+", // segregator
                        _message.title, // Message title.
                        "+", // segregator
                        _message.body //  Message body
                    )
                )
            )
        );
        return true;
    }

    function getMessages(
        address _protocol
    )
        public
        view
        hasUserRegisteredForProtocol(msg.sender, _protocol)
        returns (Message[] memory)
    {
        uint256 _len = protocolMessages[_protocol].length;
        Message[] memory _userMessages = new Message[](_len);
        for (uint256 i; i < _len; ++i) {
            _userMessages[i] = protocolMessages[_protocol][i];
        }
        return _userMessages;
    }

    function _isRegisteredForProtocol(
        address _user,
        address _protocol
    ) private view returns (bool) {
        for (uint i; i < registeredForProtocols[_user].length; ++i) {
            if (registeredForProtocols[_user][i] == _protocol) {
                return true;
            }
        }
        return false;
    }
}
