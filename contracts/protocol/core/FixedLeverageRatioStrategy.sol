// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;
pragma experimental ABIEncoderV2;

import "./BaseUpgradeablePausable.sol";
import "./ConfigHelper.sol";
import "./LeverageRatioStrategy.sol";
import "../../interfaces/ISeniorPoolStrategy.sol";
import "../../interfaces/ISeniorPool.sol";
import "../../interfaces/ITranchedPool.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

contract FixedLeverageRatioStrategy is LeverageRatioStrategy {
  LocaleLendingConfig public config;
  using ConfigHelper for LocaleLendingConfig;

  event LocaleLendingConfigUpdated(address indexed who, address configAddress);

  function initialize(address owner, LocaleLendingConfig _config) public initializer {
    require(owner != address(0) && address(_config) != address(0), "Owner and config addresses cannot be empty");
    __BaseUpgradeablePausable__init(owner);
    config = _config;
  }

  function updateLocaleLendingConfig() external onlyAdmin {
    config = LocaleLendingConfig(config.configAddress());
    emit LocaleLendingConfigUpdated(msg.sender, address(config));
  }

  function getLeverageRatio(ITranchedPool pool) public view override returns (uint256) {
    return config.getLeverageRatio();
  }
}
