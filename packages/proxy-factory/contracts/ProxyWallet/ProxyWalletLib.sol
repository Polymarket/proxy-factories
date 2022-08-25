pragma solidity ^0.5.0;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { MemcpyLib } from "../libraries/MemcpyLib.sol";

library ProxyWalletLib {
  bytes32 constant _OWNER_SLOT = 0x734a2a5caf82146a5ddd5263d9af379f9f72724959f0567ddc9df2c40cf2cc20; // keccak256("owner")
  bytes32 constant _WALLET_FACTORY_SALT = 0x154d67e25bcc1ea1986fa661b5b80b8facf3a90be6159e155e199e54a74fcb4d; // keccak256("wallet-factory")
  bytes32 constant _IMPLEMENTATION_SLOT = 0x8ba0ed1f62da1d3048614c2c1feb566f041c8467eb00fb8294776a9179dc1643; // keccak256("implementation")
  bytes32 constant _GSN_MODULE_SLOT = 0x73c1ac149a67e4e6e228d78c3a8df342639f43de1a2480627ae6fad35761d9af; // keccak256("gsn-module")
  function WALLET_FACTORY_SALT() internal pure returns (bytes32 salt) {
    salt = _WALLET_FACTORY_SALT;
  }
  function getImplementation() internal view returns (address implementation) {
     bytes32 local = _IMPLEMENTATION_SLOT;
     assembly {
       implementation := sload(local)
     }
  }
  function setImplementation(address implementation) internal {
    bytes32 local = _IMPLEMENTATION_SLOT;
    assembly {
      sstore(local, implementation)
    }
  }
  function setGSNModule(address gsnModule) internal {
    bytes32 local = _GSN_MODULE_SLOT;
    assembly {
      sstore(local, gsnModule)
    }
  }
  function getGSNModule() internal view returns (address gsnModule) {
    bytes32 local = _GSN_MODULE_SLOT;
    assembly {
      gsnModule := sload(local)
    }
  }
  function getOwner() internal view returns (address owner) {
    bytes32 OWNER_SLOT = _OWNER_SLOT;
    assembly {
      owner := sload(OWNER_SLOT)
    }
  }
  enum CallType {
    INVALID,
    CALL,
    DELEGATECALL
  }
  struct ProxyCall {
    CallType typeCode;
    address payable to;
    uint256 value;
    bytes data;
  }
  function setOwner(address owner) internal {
    bytes32 local = _OWNER_SLOT;
    assembly {
      sstore(local, owner)
    }
  }
  function proxyCall(ProxyCall memory callDetails) internal returns (bool success, bytes memory returnData) {
    if (callDetails.typeCode == CallType.DELEGATECALL) {
      (success, returnData) = callDetails.to.delegatecall(callDetails.data);
    } else if (callDetails.typeCode == CallType.CALL) {
      (success, returnData) = callDetails.to.call.value(callDetails.value)(callDetails.data);
    }
  }
  function computeCreationCode(address target) internal view returns (bytes memory clone) {
    clone = computeCreationCode(address(this), target);
  }
  function computeCreationCode(address deployer, address target) internal pure returns (bytes memory clone) {
      bytes memory consData = abi.encodeWithSignature("cloneConstructor(bytes)", new bytes(0));
      clone = new bytes(99 + consData.length);
      assembly {
        mstore(add(clone, 0x20),
           0x3d3d606380380380913d393d73bebebebebebebebebebebebebebebebebebebe)
        mstore(add(clone, 0x2d),
           mul(deployer, 0x01000000000000000000000000))
        mstore(add(clone, 0x41),
           0x5af4602a57600080fd5b602d8060366000396000f3363d3d373d3d3d363d73be)
           mstore(add(clone, 0x60),
           mul(target, 0x01000000000000000000000000))
        mstore(add(clone, 116),
           0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
      }
      for (uint256 i = 0; i < consData.length; i++) {
        clone[i + 99] = consData[i];
      }
  }
  function deriveInstanceAddress(address target, bytes32 salt) internal view returns (address) {
    return Create2.computeAddress(salt, computeCreationCode(target));
  }
  function deriveInstanceAddress(address from, address target, bytes32 salt) internal pure returns (address) {
     return Create2.computeAddress(salt, computeCreationCode(from, target), from);
  }
}
