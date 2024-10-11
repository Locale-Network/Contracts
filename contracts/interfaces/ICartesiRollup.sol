// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface ICartesiRollup {
  /**
    * @notice Sends a request to the Cartesi Rollup node to perform off-chain computation.
    * @param requestId The unique ID of the request.
    * @param data The data payload for the off-chain computation.
    */
  function sendRequest(uint256 requestId, bytes calldata data) external;

  /**
    * @notice Called by the Cartesi Rollup node to complete an off-chain computation.
    * @param requestId The unique ID of the completed request.
    * @param result The result of the off-chain computation.
    */
  function completeRequest(uint256 requestId, bytes calldata result) external;
}