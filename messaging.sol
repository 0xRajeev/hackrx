pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

struct Message {
    bytes message;
    uint256 timestamp;
    uint8 priority;
}


contract Messaging is Ownable {

mapping (address => Message[]) public protocolMessages;
mapping (address => address[]) public registeredForProtocols;
mapping (address => bool) registeredProtocols;

event RegisterProtocol(address indexed protocol);
event RegisteredForProtocol(address indexed user, address indexed protocol);

error UnregisteredProtocol();
error UserNotRegisteredForProtocol();


modifier isRegisteredProtocol(address _protocol) {
    if (!registeredProtocols[_protocol]) revert UnregisteredProtocol();
    _;
}

modifier hasUserRegisteredForProtocol(address _user, address _protocol) {
    bool _registered = _isRegisteredForProtocol(_user, _protocol);
    if (!_registered) revert UserNotRegisteredForProtocol();
    _;
}


constructor () Ownable (msg.sender) {}

/** 
*** Owner Functions
**/
  
function registerProtocol(address _protocol) external  onlyOwner {
    registeredProtocols[_protocol] = true;
    emit RegisterProtocol(_protocol);
}


/** 
*** Public Functions
**/

function registerForProtocol(address _protocol) external {
    registeredForProtocols[msg.sender].push(_protocol);
    emit RegisteredForProtocol(msg.sender, _protocol);
}

function sendMessage(Message memory _message) external isRegisteredProtocol(msg.sender) {
    protocolMessages[msg.sender].push(_message);
}


function getMessages(address _protocol) public view hasUserRegisteredForProtocol(msg.sender, _protocol) returns (Message[] memory) {
    uint256 _len = protocolMessages[_protocol].length;
    Message[] memory _userMessages = new Message[](_len);
    for (uint256 i; i < _len; ++i)
    {
        _userMessages[i] = protocolMessages[_protocol][i];
    }
    return _userMessages;
}


function _isRegisteredForProtocol(address _user, address _protocol) private view returns(bool) {
    for (uint i; i < registeredForProtocols[_user].length; ++i) {
        if (registeredForProtocols[_user][i] == _protocol) {
            return true;
        } 
    }
    return false;
}

}