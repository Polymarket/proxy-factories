pragma experimental ABIEncoderV2;
pragma solidity ^0.5.0;

contract IGSNModule {
  function acceptRelayedCall(
    address /* relay */,
    address /* from */,
    bytes calldata /* encodedFunction */,
    uint256 /* transactionFee */,
    uint256 /* gasPrice */,
    uint256 /* gasLimit */,
    uint256 /* nonce */,
    bytes calldata /* approvalData */,
    uint256 /* maxPossibleCharge */
  ) external returns (uint256 doCall, bytes memory);
  function preRelayedCall(bytes calldata /* context */) external returns (bytes32) { }
  function postRelayedCall(bytes calldata /* context */, bool /* success */, uint256 /* actualCharge */, bytes32 /* preRetVal */) external;
}
