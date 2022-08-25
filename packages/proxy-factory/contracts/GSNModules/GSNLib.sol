pragma solidity ^0.5.0;

import { SliceLib } from "../libraries/SliceLib.sol";

library GSNLib {
  bytes32 constant SIGNATURE_MASK = 0xffffffff00000000000000000000000000000000000000000000000000000000;
  function toSignature(bytes memory input) internal pure returns (bytes4 signature) {
    bytes32 local = SIGNATURE_MASK;
    assembly {
      signature := and(mload(add(0x20, input)), local)
    }
  }
  function splitPayload(bytes memory payload) internal pure returns (bytes4 signature, bytes memory args) {
    signature = toSignature(payload);
    args = SliceLib.copy(SliceLib.toSlice(payload, 4));
  }
}
