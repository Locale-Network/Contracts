// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "./BaseUpgradeablePausable.sol";
import "./ConfigHelper.sol";
import "../../interfaces/IGo.sol";
import "../../interfaces/IUniqueIdentity0612.sol";

contract Go is IGo, BaseUpgradeablePausable {
  address public override uniqueIdentity;

  using SafeMath for uint256;

  LocaleLendingConfig public config;
  using ConfigHelper for LocaleLendingConfig;

  LocaleLendingConfig public legacyGoList;
  uint256[11] public allIdTypes;
  event LocaleLendingConfigUpdated(address indexed who, address configAddress);

  function initialize(
    address owner,
    LocaleLendingConfig _config,
    address _uniqueIdentity
  ) public initializer {
    require(
      owner != address(0) && address(_config) != address(0) && _uniqueIdentity != address(0),
      "Owner and config and UniqueIdentity addresses cannot be empty"
    );
    __BaseUpgradeablePausable__init(owner);
    _performUpgrade();
    config = _config;
    uniqueIdentity = _uniqueIdentity;
  }

  function updateLocaleLendingConfig() external override onlyAdmin {
    config = LocaleLendingConfig(config.configAddress());
    emit LocaleLendingConfigUpdated(msg.sender, address(config));
  }

  function performUpgrade() external onlyAdmin {
    return _performUpgrade();
  }

  function _performUpgrade() internal {
    allIdTypes[0] = ID_TYPE_0;
    allIdTypes[1] = ID_TYPE_1;
    allIdTypes[2] = ID_TYPE_2;
    allIdTypes[3] = ID_TYPE_3;
    allIdTypes[4] = ID_TYPE_4;
    allIdTypes[5] = ID_TYPE_5;
    allIdTypes[6] = ID_TYPE_6;
    allIdTypes[7] = ID_TYPE_7;
    allIdTypes[8] = ID_TYPE_8;
    allIdTypes[9] = ID_TYPE_9;
    allIdTypes[10] = ID_TYPE_10;
  }

  /**
   * @notice sets the config that will be used as the source of truth for the go
   * list instead of the config currently associated. To use the associated config for to list, set the override
   * to the null address.
   */
  function setLegacyGoList(LocaleLendingConfig _legacyGoList) external onlyAdmin {
    legacyGoList = _legacyGoList;
  }

  /**
   * @notice Returns whether the provided account is go-listed for use of the LocaleLending protocol
   * for any of the UID token types.
   * This status is defined as: whether `balanceOf(account, id)` on the UniqueIdentity
   * contract is non-zero (where `id` is a supported token id on UniqueIdentity), falling back to the
   * account's status on the legacy go-list maintained on LocaleLendingConfig.
   * @param account The account whose go status to obtain
   * @return The account's go status
   */
  function go(address account) public view override returns (bool) {
    require(account != address(0), "Zero address is not go-listed");

    if (_getLegacyGoList().goList(account) || IUniqueIdentity0612(uniqueIdentity).balanceOf(account, ID_TYPE_0) > 0) {
      return true;
    }

    // start loop at index 1 because we checked index 0 above
    for (uint256 i = 1; i < allIdTypes.length; ++i) {
      uint256 idTypeBalance = IUniqueIdentity0612(uniqueIdentity).balanceOf(account, allIdTypes[i]);
      if (idTypeBalance > 0) {
        return true;
      }
    }
    return false;
  }

  /**
   * @notice Returns whether the provided account is go-listed for use of the LocaleLending protocol
   * for defined UID token types
   * @param account The account whose go status to obtain
   * @param onlyIdTypes Array of id types to check balances
   * @return The account's go status
   */
  function goOnlyIdTypes(address account, uint256[] memory onlyIdTypes) public view override returns (bool) {
    require(account != address(0), "Zero address is not go-listed");
    LocaleLendingConfig goListSource = _getLegacyGoList();
    for (uint256 i = 0; i < onlyIdTypes.length; ++i) {
      if (onlyIdTypes[i] == ID_TYPE_0 && goListSource.goList(account)) {
        return true;
      }
      uint256 idTypeBalance = IUniqueIdentity0612(uniqueIdentity).balanceOf(account, onlyIdTypes[i]);
      if (idTypeBalance > 0) {
        return true;
      }
    }
    return false;
  }

  /**
   * @notice Returns whether the provided account is go-listed for use of the SeniorPool on the LocaleLending protocol.
   * @param account The account whose go status to obtain
   * @return The account's go status
   */
  function goSeniorPool(address account) public view override returns (bool) {
    require(account != address(0), "Zero address is not go-listed");
    if (account == config.stakingRewardsAddress() || _getLegacyGoList().goList(account)) {
      return true;
    }
    uint256[2] memory seniorPoolIdTypes = [ID_TYPE_0, ID_TYPE_1];
    for (uint256 i = 0; i < seniorPoolIdTypes.length; ++i) {
      uint256 idTypeBalance = IUniqueIdentity0612(uniqueIdentity).balanceOf(account, seniorPoolIdTypes[i]);
      if (idTypeBalance > 0) {
        return true;
      }
    }
    return false;
  }

  function _getLegacyGoList() internal view returns (LocaleLendingConfig) {
    return address(legacyGoList) == address(0) ? config : legacyGoList;
  }
}
