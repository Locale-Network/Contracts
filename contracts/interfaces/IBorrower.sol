// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;
pragma experimental ABIEncoderV2;

interface IBorrower {
  function initialize(address owner, address _config) external;
}
