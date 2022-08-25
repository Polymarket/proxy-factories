pragma solidity ^0.5.0;

interface IRootChain {
  function depositFor(address user, address rootToken, bytes calldata depositData) external;
  function exit(bytes calldata inputData) external;
}
