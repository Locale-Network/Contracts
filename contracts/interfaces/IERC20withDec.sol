// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Interface of the ERC20 standard as defined in the EIP, with added decimals function.
 */
interface IERC20withDec is IERC20 {
  /**
   * @dev Returns the number of decimals used for the token
   */
  function decimals() external view returns (uint8);
}