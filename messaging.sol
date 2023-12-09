// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

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
                        "0", // this represents minimal identity, learn more: https://push.org/docs/notifications/notification-standards/notification-standards-advance/#notification-identity
                        "+", // segregator
                        "3", // define notification type:  https://push.org/docs/notifications/build/types-of-notification (1, 3 or 4) = (Broadcast, targeted or subset)
                        "+", // segregator
                        "Hi", // Message title.
                        "+", // segregator
                        "Body" //  Message body
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

    // Helper function to convert address to string
    function addressToString(
        address _address
    ) internal pure returns (string memory) {
        bytes32 _bytes = bytes32(uint256(uint160(_address)));
        bytes memory HEX = "0123456789abcdef";
        bytes memory _string = new bytes(42);
        _string[0] = "0";
        _string[1] = "x";
        for (uint i = 0; i < 20; i++) {
            _string[2 + i * 2] = HEX[uint8(_bytes[i + 12] >> 4)];
            _string[3 + i * 2] = HEX[uint8(_bytes[i + 12] & 0x0f)];
        }
        return string(_string);
    }

    // Helper function to convert uint to string
    function uint2str(
        uint _i
    ) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = bytes1(uint8(48 + (_i % 10)));
            _i /= 10;
        }
        return string(bstr);
    }
}
