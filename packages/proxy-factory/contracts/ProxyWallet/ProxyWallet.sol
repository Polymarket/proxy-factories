pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import { ProxyWalletLib } from "./ProxyWalletLib.sol";
import { GSNRecipient } from "@openzeppelin/contracts/GSN/GSNRecipient.sol";
import { MemcpyLib } from "../libraries/MemcpyLib.sol";
import { RevertCaptureLib } from "../libraries/RevertCaptureLib.sol";
import { IRelayHub } from "@openzeppelin/contracts/GSN/IRelayHub.sol";

contract ProxyWallet {
  using ProxyWalletLib for *;
  function initialize() public {
    require(ProxyWalletLib.getOwner() == address(0x0), "already initialized");
    ProxyWalletLib.setOwner(msg.sender);
  }
  modifier onlyOwner {
    require(ProxyWalletLib.getOwner() == msg.sender, "must be called be owner");
    _;
  }
  function onERC1155BatchReceived(
    address /* operator */,
    address /* from */,
    uint256[] memory /* ids */,
    uint256[] memory /* values */,
    bytes memory /* data */
  ) public pure returns (bytes4) {
    return this.onERC1155BatchReceived.selector;
  }
  function onERC1155Received(
    address /* operator */,
    address /* from */,
    uint256 /* id */,
    uint256 /* value */,
    bytes memory /* data */
  ) public pure returns (bytes4) {
    return this.onERC1155Received.selector;
  }

  /**
    * @notice Receives an array of contract calls from ProxyWalletFactory to be executed.
    * @dev Access control for this function is handled on ProxyWalletFactory
    *
    * @param calls - array of ProxyCalls to be executed.
    */
  function proxy(ProxyWalletLib.ProxyCall[] memory calls) public payable onlyOwner returns (bytes[] memory returnValues) {
    returnValues = new bytes[](calls.length);
    for (uint256 i = 0; i < calls.length; i++) {
      (bool success, bytes memory returnData) = calls[i].proxyCall();
      if (!success) revert(RevertCaptureLib.decodeError(returnData));
      returnValues[i] = returnData;
    }
  }
}
