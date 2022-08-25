pragma solidity ^0.5.0;

import { IProxyWalletFactory } from "../interfaces/IProxyWalletFactory.sol";
import { GSNLib } from "./GSNLib.sol";
import { RevertCaptureLib } from "../libraries/RevertCaptureLib.sol";
import { ProxyWalletLib } from "../ProxyWallet/ProxyWalletLib.sol";

contract GSNModule01 {
  using GSNLib for *;
  function acceptRelayedCall(
    address /* relay */,
    address /* from */,
    bytes memory encodedFunction,
    uint256 /* transactionFee */,
    uint256 /* gasPrice */,
    uint256 /* gasLimit */,
    uint256 /* nonce */,
    bytes memory /* approvalData */,
    uint256 /* maxPossibleCharge */
  ) public pure returns (uint256 doCall, bytes memory) {
    bytes4 signature = encodedFunction.toSignature();
    if (signature == IProxyWalletFactory(0).proxy.selector) doCall = 0;
    else doCall = 1;
  }
  function preRelayedCall(bytes memory /* context */) public returns (bytes32) { }
  function postRelayedCall(bytes memory /* context */, bool /* success */, uint256 /* actualCharge */, bytes32 /* preRetVal */) public {}
}
