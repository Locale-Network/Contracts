// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;
pragma experimental ABIEncoderV2;

import "../core/BaseUpgradeablePausable.sol";
import "../core/ConfigHelper.sol";
import "../core/CreditLine.sol";
import "../core/LocaleLendingConfig.sol";
import "../../interfaces/IMigrate.sol";

/**
 * @title V2 Migrator Contract
 * @notice This is a one-time use contract solely for the purpose of migrating from our V1
 *  to our V2 architecture. It will be temporarily granted authority from the LocaleLending governance,
 *  and then revokes it's own authority and transfers it back to governance.
 * @author LocaleLending
 */

contract V2Migrator is BaseUpgradeablePausable {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant GO_LISTER_ROLE = keccak256("GO_LISTER_ROLE");
  using SafeMath for uint256;

  LocaleLendingConfig public config;
  using ConfigHelper for LocaleLendingConfig;

  mapping(address => address) public borrowerContracts;
  event CreditLineMigrated(address indexed owner, address indexed clToMigrate, address newCl, address tranchedPool);

  function initialize(address owner, address _config) external initializer {
    require(owner != address(0) && _config != address(0), "Owner and config addresses cannot be empty");
    __BaseUpgradeablePausable__init(owner);
    config = LocaleLendingConfig(_config);
  }

  function migratePhase1(LocaleLendingConfig newConfig) external onlyAdmin {
    pauseEverything();
    migrateToNewConfig(newConfig);
    migrateToSeniorPool(newConfig);
  }

  function migrateCreditLines(
    LocaleLendingConfig newConfig,
    address[][] calldata creditLinesToMigrate,
    uint256[][] calldata migrationData
  ) external onlyAdmin {
    IMigrate creditDesk = IMigrate(newConfig.creditDeskAddress());
    ILocaleLendingFactory factory = newConfig.getLocaleLendingFactory();
    for (uint256 i = 0; i < creditLinesToMigrate.length; i++) {
      address[] calldata clData = creditLinesToMigrate[i];
      uint256[] calldata data = migrationData[i];
      address clAddress = clData[0];
      address owner = clData[1];
      address borrowerContract = borrowerContracts[owner];
      if (borrowerContract == address(0)) {
        borrowerContract = factory.createBorrower(owner);
        borrowerContracts[owner] = borrowerContract;
      }
      (address newCl, address pool) = creditDesk.migrateV1CreditLine(
        clAddress,
        borrowerContract,
        data[0],
        data[1],
        data[2],
        data[3],
        data[4]
      );
      emit CreditLineMigrated(owner, clAddress, newCl, pool);
    }
  }

  function bulkAddToGoList(LocaleLendingConfig newConfig, address[] calldata members) external onlyAdmin {
    newConfig.bulkAddToGoList(members);
  }

  function pauseEverything() internal {
    IMigrate(config.creditDeskAddress()).pause();
    IMigrate(config.poolAddress()).pause();
    IMigrate(config.llduAddress()).pause();
  }

  function migrateToNewConfig(LocaleLendingConfig newConfig) internal {
    uint256 key = uint256(ConfigOptions.Addresses.LocaleLendingConfig);
    config.setAddress(key, address(newConfig));

    IMigrate(config.creditDeskAddress()).updateLocaleLendingConfig();
    IMigrate(config.poolAddress()).updateLocaleLendingConfig();
    IMigrate(config.llduAddress()).updateLocaleLendingConfig();
    IMigrate(config.localeLendingFactoryAddress()).updateLocaleLendingConfig();

    key = uint256(ConfigOptions.Numbers.DrawdownPeriodInSeconds);
    newConfig.setNumber(key, 24 * 60 * 60);

    key = uint256(ConfigOptions.Numbers.TransferRestrictionPeriodInDays);
    newConfig.setNumber(key, 365);

    key = uint256(ConfigOptions.Numbers.LeverageRatio);
    // 1e18 is the LEVERAGE_RATIO_DECIMALS
    newConfig.setNumber(key, 3 * 1e18);
  }

  function upgradeImplementations(LocaleLendingConfig _config, address[] calldata newDeployments) public {
    address newPoolAddress = newDeployments[0];
    address newCreditDeskAddress = newDeployments[1];
    address newLlduAddress = newDeployments[2];
    address newLocaleLendingFactoryAddress = newDeployments[3];

    bytes memory data;
    IMigrate pool = IMigrate(_config.poolAddress());
    IMigrate creditDesk = IMigrate(_config.creditDeskAddress());
    IMigrate lldu = IMigrate(_config.llduAddress());
    IMigrate localeLendingFactory = IMigrate(_config.localeLendingFactoryAddress());

    // Upgrade implementations
    pool.changeImplementation(newPoolAddress, data);
    creditDesk.changeImplementation(newCreditDeskAddress, data);
    lldu.changeImplementation(newLlduAddress, data);
    localeLendingFactory.changeImplementation(newLocaleLendingFactoryAddress, data);
  }

  function migrateToSeniorPool(LocaleLendingConfig newConfig) internal {
    IMigrate(config.llduAddress()).grantRole(MINTER_ROLE, newConfig.seniorPoolAddress());
    IMigrate(config.poolAddress()).unpause();
    IMigrate(newConfig.poolAddress()).migrateToSeniorPool();
  }

  function closeOutMigration(LocaleLendingConfig newConfig) external onlyAdmin {
    IMigrate lldu = IMigrate(newConfig.llduAddress());
    IMigrate creditDesk = IMigrate(newConfig.creditDeskAddress());
    IMigrate oldPool = IMigrate(newConfig.poolAddress());
    IMigrate localeLendingFactory = IMigrate(newConfig.localeLendingFactoryAddress());

    lldu.unpause();
    lldu.renounceRole(MINTER_ROLE, address(this));
    lldu.renounceRole(OWNER_ROLE, address(this));
    lldu.renounceRole(PAUSER_ROLE, address(this));

    creditDesk.renounceRole(OWNER_ROLE, address(this));
    creditDesk.renounceRole(PAUSER_ROLE, address(this));

    oldPool.renounceRole(OWNER_ROLE, address(this));
    oldPool.renounceRole(PAUSER_ROLE, address(this));

    localeLendingFactory.renounceRole(OWNER_ROLE, address(this));
    localeLendingFactory.renounceRole(PAUSER_ROLE, address(this));

    config.renounceRole(PAUSER_ROLE, address(this));
    config.renounceRole(OWNER_ROLE, address(this));

    newConfig.renounceRole(OWNER_ROLE, address(this));
    newConfig.renounceRole(PAUSER_ROLE, address(this));
    newConfig.renounceRole(GO_LISTER_ROLE, address(this));
  }
}
