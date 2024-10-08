// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

/// @dev This interface provides a subset of the functionality of the IUniqueIdentity
/// interface -- namely, the subset of functionality needed by LocaleLending protocol contracts
/// compiled with Solidity version ^0.8.11.
interface IUniqueIdentity0612 {
  function balanceOf(address account, uint256 id) external view returns (uint256);
}
