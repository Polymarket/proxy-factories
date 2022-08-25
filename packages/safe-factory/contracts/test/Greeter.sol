// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

contract Greeter {
  event Greeted(address indexed greeter, string message);

  function greet(string memory message) public payable {
    emit Greeted(msg.sender, message);
  }
}