pragma solidity ^0.5.0;

import { Create2 } from "openzeppelin-solidity/contracts/utils/Create2.sol";
import { MemcpyLib } from "./MemcpyLib.sol";

library RStoreLib {
  bytes32 constant ZERO_SALT = 0x0000000000000000000000000000000000000000000000000000000000000000;
  function store(bytes memory data) internal returns (address) {
    bytes memory segment = hex"7f000000000000000000000000000000000000000000000000000000000000000080602a6000396000f3";
    uint256 length = data.length;
    bytes32 dest;
    bytes32 src;
    assembly {
      mstore(add(segment, 0x21), length)
      mstore(segment, add(0x2a, length))
      dest := add(segment, 0x4a)
      src := add(data, 0x20)
    }
    MemcpyLib.memcpy(dest, src, length);
    return Create2.deploy(ZERO_SALT, segment);
  }
}
