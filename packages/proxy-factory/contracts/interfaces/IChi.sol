pragma solidity ^0.5.0;

interface IChi {
  function freeUpTo(uint256) external returns (uint256);
  function mint(uint256) external;
  function transfer(address, uint256) external returns (bool);
}
