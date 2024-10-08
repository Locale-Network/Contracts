// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;
pragma experimental ABIEncoderV2;

import "./LocaleLendingConfig.sol";
import "../../interfaces/IPool.sol";
import "../../interfaces/ILldu.sol";
import "../../interfaces/ISeniorPool.sol";
import "../../interfaces/ISeniorPoolStrategy.sol";
import "../../interfaces/ICreditDesk.sol";
import "../../interfaces/IERC20withDec.sol";
import "../../interfaces/ICUSDCContract.sol";
import "../../interfaces/IPoolTokens.sol";
import "../../interfaces/IBackerRewards.sol";
import "../../interfaces/ILocaleLendingFactory.sol";
import "../../interfaces/IGo.sol";

/**
 * @title ConfigHelper
 * @notice A convenience library for getting easy access to other contracts and constants within the
 *  protocol, through the use of the LocaleLendingConfig contract
 * @author LocaleLending
 */

library ConfigHelper {
  function getPool(LocaleLendingConfig config) internal view returns (IPool) {
    return IPool(poolAddress(config));
  }

  function getSeniorPool(LocaleLendingConfig config) internal view returns (ISeniorPool) {
    return ISeniorPool(seniorPoolAddress(config));
  }

  function getSeniorPoolStrategy(LocaleLendingConfig config) internal view returns (ISeniorPoolStrategy) {
    return ISeniorPoolStrategy(seniorPoolStrategyAddress(config));
  }

  function getUSDC(LocaleLendingConfig config) internal view returns (IERC20withDec) {
    return IERC20withDec(usdcAddress(config));
  }

  function getCreditDesk(LocaleLendingConfig config) internal view returns (ICreditDesk) {
    return ICreditDesk(creditDeskAddress(config));
  }

  function getLldu(LocaleLendingConfig config) internal view returns (ILldu) {
    return ILldu(llduAddress(config));
  }

  function getCUSDCContract(LocaleLendingConfig config) internal view returns (ICUSDCContract) {
    return ICUSDCContract(cusdcContractAddress(config));
  }

  function getPoolTokens(LocaleLendingConfig config) internal view returns (IPoolTokens) {
    return IPoolTokens(poolTokensAddress(config));
  }

  function getBackerRewards(LocaleLendingConfig config) internal view returns (IBackerRewards) {
    return IBackerRewards(backerRewardsAddress(config));
  }

  function getLocaleLendingFactory(LocaleLendingConfig config) internal view returns (ILocaleLendingFactory) {
    return ILocaleLendingFactory(localeLendingFactoryAddress(config));
  }

  function getLLP(LocaleLendingConfig config) internal view returns (IERC20withDec) {
    return IERC20withDec(gfiAddress(config));
  }

  function getGo(LocaleLendingConfig config) internal view returns (IGo) {
    return IGo(goAddress(config));
  }

  function oneInchAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.OneInch));
  }

  function creditLineImplementationAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.CreditLineImplementation));
  }

  function trustedForwarderAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.TrustedForwarder));
  }

  function configAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.LocaleLendingConfig));
  }

  function poolAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.Pool));
  }

  function poolTokensAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.PoolTokens));
  }

  function backerRewardsAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.BackerRewards));
  }

  function seniorPoolAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.SeniorPool));
  }

  function seniorPoolStrategyAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.SeniorPoolStrategy));
  }

  function creditDeskAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.CreditDesk));
  }

  function localeLendingFactoryAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.LocaleLendingFactory));
  }

  function gfiAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.LLP));
  }

  function llduAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.Lldu));
  }

  function cusdcContractAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.CUSDCContract));
  }

  function usdcAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.USDC));
  }

  function tranchedPoolAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.TranchedPoolImplementation));
  }

  function migratedTranchedPoolAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.MigratedTranchedPoolImplementation));
  }

  function reserveAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.TreasuryReserve));
  }

  function protocolAdminAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.ProtocolAdmin));
  }

  function borrowerImplementationAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.BorrowerImplementation));
  }

  function goAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.Go));
  }

  function stakingRewardsAddress(LocaleLendingConfig config) internal view returns (address) {
    return config.getAddress(uint256(ConfigOptions.Addresses.StakingRewards));
  }

  function getReserveDenominator(LocaleLendingConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(ConfigOptions.Numbers.ReserveDenominator));
  }

  function getWithdrawFeeDenominator(LocaleLendingConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(ConfigOptions.Numbers.WithdrawFeeDenominator));
  }

  function getLatenessGracePeriodInDays(LocaleLendingConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(ConfigOptions.Numbers.LatenessGracePeriodInDays));
  }

  function getLatenessMaxDays(LocaleLendingConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(ConfigOptions.Numbers.LatenessMaxDays));
  }

  function getDrawdownPeriodInSeconds(LocaleLendingConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(ConfigOptions.Numbers.DrawdownPeriodInSeconds));
  }

  function getTransferRestrictionPeriodInDays(LocaleLendingConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(ConfigOptions.Numbers.TransferRestrictionPeriodInDays));
  }

  function getLeverageRatio(LocaleLendingConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(ConfigOptions.Numbers.LeverageRatio));
  }
}
