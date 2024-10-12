// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./BaseUpgradeablePausable.sol";
import "./ConfigHelper.sol";
import "../../interfaces/ICartesiRollup.sol";
import "../../interfaces/IERC20withDec.sol";

/**
 * @title LocaleLending's Pool contract
 * @notice Main entry point for LP's (a.k.a. capital providers)
 *  Handles key logic for depositing and withdrawing funds from the Pool
 *  Integrated with Cartesi Rollups for off-chain computations
 * @author LocaleLending
 */

contract Pool is BaseUpgradeablePausable, IPool {
  LocaleLendingConfig public immutable config;
  using ConfigHelper for LocaleLendingConfig;

  ICartesiRollup public cartesiRollup;

  uint256 public compoundBalance;
  uint256 private constant LLDU_MANTISSA = 1e18;
  uint256 private constant USDC_MANTISSA = 1e6;

  event DepositMade(address indexed capitalProvider, uint256 amount, uint256 shares);
  event WithdrawalMade(address indexed capitalProvider, uint256 userAmount, uint256 reserveAmount);
  event TransferMade(address indexed from, address indexed to, uint256 amount);
  event InterestCollected(address indexed payer, uint256 poolAmount, uint256 reserveAmount);
  event PrincipalCollected(address indexed payer, uint256 amount);
  event ReserveFundsCollected(address indexed user, uint256 amount);
  event PrincipalWrittendown(address indexed creditline, int256 amount);
  event LocaleLendingConfigUpdated(address indexed who, address configAddress);
  event OffChainComputationRequested(uint256 requestId, string computationType, bytes data);
  event OffChainComputationCompleted(uint256 requestId, bytes result);

  // Update the constructor to use initializer pattern
  function initialize(address owner, LocaleLendingConfig _config, address _cartesiRollup) public initializer {
    require(owner != address(0) && address(_config) != address(0) && _cartesiRollup != address(0), "Invalid addresses");
    __BaseUpgradeablePausable__init(owner);
    config = _config;
    cartesiRollup = ICartesiRollup(_cartesiRollup);
    sharePrice = LLDU_MANTISSA;

    IERC20withDec usdc = config.getUSDC();
    usdc.totalSupply(); // Sanity check
    require(usdc.approve(address(this), type(uint256).max), "USDC approval failed");
  }

  /**
   * @notice Deposits `amount` USDC from msg.sender into the Pool, and returns you the equivalent value of LLDU tokens
   * @param amount The amount of USDC to deposit
   */
  function deposit(uint256 amount) external override whenNotPaused withinTransactionLimit(amount) nonReentrant {
    require(amount > 0, "Must deposit more than zero");

    // Move off-chain computation request to a separate function
    _requestOffChainComputation("UpdateMetrics", abi.encode(msg.sender, amount));

    uint256 depositShares = getNumShares(amount);
    uint256 potentialNewTotalShares = totalShares().add(depositShares);
    require(poolWithinLimit(potentialNewTotalShares), "Deposit would put the Pool over the total limit.");
    emit DepositMade(msg.sender, amount, depositShares);
    bool success = doUSDCTransfer(msg.sender, address(this), amount);
    require(success, "Failed to transfer for deposit");

    config.getLldu().mintTo(msg.sender, depositShares);
  }

  function completeOffChainComputation(uint256 requestId, bytes calldata result) external {
    require(msg.sender == address(cartesiRollup), "Only Cartesi Rollup can call this function");
    emit OffChainComputationCompleted(requestId, result);
    // Implement logic to handle the result
  }

  /**
   * @notice Withdraws USDC from the Pool to msg.sender, and burns the equivalent value of LLDU tokens
   * @param usdcAmount The amount of USDC to withdraw
   */
  function withdraw(uint256 usdcAmount) external override whenNotPaused nonReentrant {
    require(usdcAmount > 0, "Must withdraw more than zero");
    // This MUST happen before calculating withdrawShares, otherwise the share price
    // changes between calculation and burning of Lldu, which creates a asset/liability mismatch
    if (compoundBalance > 0) {
      _sweepFromCompound();
    }
    uint256 withdrawShares = getNumShares(usdcAmount);
    _withdraw(usdcAmount, withdrawShares);
  }

  /**
   * @notice Withdraws USDC (denominated in LLDU terms) from the Pool to msg.sender
   * @param llduAmount The amount of USDC to withdraw in terms of lldu shares
   */
  function withdrawInLldu(uint256 llduAmount) external override whenNotPaused nonReentrant {
    require(llduAmount > 0, "Must withdraw more than zero");
    if (compoundBalance > 0) {
      _sweepFromCompound();
    }
    uint256 usdcAmount = getUSDCAmountFromShares(llduAmount);
    uint256 withdrawShares = llduAmount;
    _withdraw(usdcAmount, withdrawShares);
  }

  /**
   * @notice Collects `interest` USDC in interest and `principal` in principal from `from` and sends it to the Pool.
   *  This also increases the share price accordingly. A portion is sent to the LocaleLending Reserve address
   * @param from The address to take the USDC from. Implicitly, the Pool
   *  must be authorized to move USDC on behalf of `from`.
   * @param interest the interest amount of USDC to move to the Pool
   * @param principal the principal amount of USDC to move to the Pool
   *
   * Requirements:
   *  - The caller must be the Credit Desk. Not even the owner can call this function.
   */
  function collectInterestAndPrincipal(
    address from,
    uint256 interest,
    uint256 principal
  ) public override onlyCreditDesk whenNotPaused {
    _collectInterestAndPrincipal(from, interest, principal);
    _requestOffChainComputation("CollectInterest", abi.encode(from, interest, principal));
  }

  function distributeLosses(address creditlineAddress, int256 writedownDelta)
    external
    override
    onlyCreditDesk
    whenNotPaused
  {
    if (writedownDelta > 0) {
      uint256 delta = usdcToSharePrice(uint256(writedownDelta));
      sharePrice = sharePrice.add(delta);
    } else {
      // If delta is negative, convert to positive uint, and sub from sharePrice
      uint256 delta = usdcToSharePrice(uint256(writedownDelta * -1));
      sharePrice = sharePrice.sub(delta);
    }
    emit PrincipalWrittendown(creditlineAddress, writedownDelta);
  }

  /**
   * @notice Moves `amount` USDC from `from`, to `to`.
   * @param from The address to take the USDC from. Implicitly, the Pool
   *  must be authorized to move USDC on behalf of `from`.
   * @param to The address that the USDC should be moved to
   * @param amount the amount of USDC to move to the Pool
   *
   * Requirements:
   *  - The caller must be the Credit Desk. Not even the owner can call this function.
   */
  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public override onlyCreditDesk whenNotPaused returns (bool) {
    bool result = doUSDCTransfer(from, to, amount);
    require(result, "USDC Transfer failed");
    emit TransferMade(from, to, amount);
    return result;
  }

  /**
   * @notice Moves `amount` USDC from the pool, to `to`. This is similar to transferFrom except we sweep any
   * balance we have from compound first and recognize interest. Meant to be called only by the credit desk on drawdown
   * @param to The address that the USDC should be moved to
   * @param amount the amount of USDC to move to the Pool
   *
   * Requirements:
   *  - The caller must be the Credit Desk. Not even the owner can call this function.
   */
  function drawdown(address to, uint256 amount) public override onlyCreditDesk whenNotPaused returns (bool) {
    if (compoundBalance > 0) {
      _sweepFromCompound();
    }
    return transferFrom(address(this), to, amount);
  }

  function assets() public view override returns (uint256) {
    ICreditDesk creditDesk = config.getCreditDesk();
    return
      compoundBalance.add(config.getUSDC().balanceOf(address(this))).add(creditDesk.totalLoansOutstanding()).sub(
        creditDesk.totalWritedowns()
      );
  }

  function migrateToSeniorPool() external onlyAdmin {
    // Bring back all USDC
    if (compoundBalance > 0) {
      sweepFromCompound();
    }

    // Pause deposits/withdrawals
    if (!paused()) {
      pause();
    }

    // Remove special priveldges from Lldu
    bytes32 minterRole = keccak256("MINTER_ROLE");
    bytes32 pauserRole = keccak256("PAUSER_ROLE");
    config.getLldu().renounceRole(minterRole, address(this));
    config.getLldu().renounceRole(pauserRole, address(this));

    // Move all USDC to the SeniorPool
    address seniorPoolAddress = config.seniorPoolAddress();
    uint256 balance = config.getUSDC().balanceOf(address(this));
    bool success = doUSDCTransfer(address(this), seniorPoolAddress, balance);
    require(success, "Failed to transfer USDC balance to the senior pool");

    // Claim our COMP!
    address compoundController = address(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    bytes memory data = abi.encodeWithSignature("claimComp(address)", address(this));
    bytes memory _res;
    // solhint-disable-next-line avoid-low-level-calls
    (success, _res) = compoundController.call(data);
    require(success, "Failed to claim COMP");

    // Use a more gas-efficient way to transfer COMP
    IERC20 compToken = IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    uint256 compBalance = compToken.balanceOf(address(this));
    require(compToken.transfer(seniorPoolAddress, compBalance), "Failed to transfer COMP");

    // Add an event to log the migration
    emit MigratedToSeniorPool(seniorPoolAddress, balance, compBalance);
  }

  /// @notice Converts bytes to uint256
  /// @dev Uses assembly for gas efficiency when handling return data from external calls
  /// @param _bytes The bytes to convert
  /// @return value The resulting uint256 value
  function toUint256(bytes memory _bytes) internal pure returns (uint256 value) {
    assembly {
      value := mload(add(_bytes, 0x20))
    }
  }

  /**
   * @notice Moves any USDC still in the Pool to Compound, and tracks the amount internally.
   * This is done to earn interest on latent funds until we have other borrowers who can use it.
   *
   * Requirements:
   *  - The caller must be an admin.
   */
  function sweepToCompound() public override onlyAdmin whenNotPaused {
    IERC20 usdc = config.getUSDC();
    uint256 usdcBalance = usdc.balanceOf(address(this));

    ICUSDCContract cUSDC = config.getCUSDCContract();
    // Approve compound to the exact amount
    bool success = usdc.approve(address(cUSDC), usdcBalance);
    require(success, "Failed to approve USDC for compound");

    sweepToCompound(cUSDC, usdcBalance);

    // Remove compound approval to be extra safe
    success = config.getUSDC().approve(address(cUSDC), 0);
    require(success, "Failed to approve USDC for compound");
  }

  /**
   * @notice Moves any USDC from Compound back to the Pool, and recognizes interest earned.
   * This is done automatically on drawdown or withdraw, but can be called manually if necessary.
   *
   * Requirements:
   *  - The caller must be an admin.
   */
  function sweepFromCompound() public override onlyAdmin whenNotPaused {
    _sweepFromCompound();
  }

  /* Internal Functions */

  function _withdraw(uint256 usdcAmount, uint256 withdrawShares) internal {
    ILldu lldu = config.getLldu();
    require(withdrawShares <= lldu.balanceOf(msg.sender), "Insufficient balance");

    uint256 reserveAmount = usdcAmount / config.getWithdrawFeeDenominator();
    uint256 userAmount = usdcAmount - reserveAmount;

    emit WithdrawalMade(msg.sender, userAmount, reserveAmount);
    
    require(doUSDCTransfer(address(this), msg.sender, userAmount), "Withdrawal transfer failed");
    sendToReserve(address(this), reserveAmount, msg.sender);

    lldu.burnFrom(msg.sender, withdrawShares);
  }

  function sweepToCompound(ICUSDCContract cUSDC, uint256 usdcAmount) internal {
    // Our current design requires we re-normalize by withdrawing everything and recognizing interest gains
    // before we can add additional capital to Compound
    require(compoundBalance == 0, "Cannot sweep when we already have a compound balance");
    require(usdcAmount != 0, "Amount to sweep cannot be zero");
    uint256 error = cUSDC.mint(usdcAmount);
    require(error == 0, "Sweep to compound failed");
    compoundBalance = usdcAmount;
  }

  function sweepFromCompound(ICUSDCContract cUSDC, uint256 cUSDCAmount) internal {
    uint256 cBalance = compoundBalance;
    require(cBalance != 0, "No funds on compound");
    require(cUSDCAmount != 0, "Amount to sweep cannot be zero");

    IERC20 usdc = config.getUSDC();
    uint256 preRedeemUSDCBalance = usdc.balanceOf(address(this));
    uint256 cUSDCExchangeRate = cUSDC.exchangeRateCurrent();
    uint256 redeemedUSDC = cUSDCToUSDC(cUSDCExchangeRate, cUSDCAmount);

    uint256 error = cUSDC.redeem(cUSDCAmount);
    uint256 postRedeemUSDCBalance = usdc.balanceOf(address(this));
    require(error == 0, "Sweep from compound failed");
    require(postRedeemUSDCBalance.sub(preRedeemUSDCBalance) == redeemedUSDC, "Unexpected redeem amount");

    uint256 interestAccrued = redeemedUSDC.sub(cBalance);
    _collectInterestAndPrincipal(address(this), interestAccrued, 0);
    compoundBalance = 0;
  }

  function _collectInterestAndPrincipal(
    address from,
    uint256 interest,
    uint256 principal
  ) internal {
    uint256 reserveAmount = interest.div(config.getReserveDenominator());
    uint256 poolAmount = interest.sub(reserveAmount);
    uint256 increment = usdcToSharePrice(poolAmount);
    sharePrice = sharePrice.add(increment);

    if (poolAmount > 0) {
      emit InterestCollected(from, poolAmount, reserveAmount);
    }
    if (principal > 0) {
      emit PrincipalCollected(from, principal);
    }
    if (reserveAmount > 0) {
      sendToReserve(from, reserveAmount, from);
    }
    // Gas savings: No need to transfer to yourself, which happens in sweepFromCompound
    if (from != address(this)) {
      bool success = doUSDCTransfer(from, address(this), principal.add(poolAmount));
      require(success, "Failed to collect principal repayment");
    }
  }

  function _sweepFromCompound() internal {
    ICUSDCContract cUSDC = config.getCUSDCContract();
    sweepFromCompound(cUSDC, cUSDC.balanceOf(address(this)));
  }

  function updateLocaleLendingConfig() external onlyAdmin {
    config = LocaleLendingConfig(config.configAddress());
    emit LocaleLendingConfigUpdated(msg.sender, address(config));
  }

  function usdcToLldu(uint256 amount) internal pure returns (uint256) {
    return amount * LLDU_MANTISSA / USDC_MANTISSA;
  }

  function llduToUSDC(uint256 amount) internal pure returns (uint256) {
    return amount * USDC_MANTISSA / LLDU_MANTISSA;
  }

  function usdcToSharePrice(uint256 usdcAmount) internal view returns (uint256) {
    return usdcToLldu(usdcAmount).mul(LLDU_MANTISSA).div(totalShares());
  }

  function poolWithinLimit(uint256 _totalShares) internal view returns (bool) {
    return
      _totalShares.mul(sharePrice).div(LLDU_MANTISSA) <=
      usdcToLldu(config.getNumber(uint256(ConfigOptions.Numbers.TotalFundsLimit)));
  }

  function transactionWithinLimit(uint256 amount) internal view returns (bool) {
    return amount <= config.getNumber(uint256(ConfigOptions.Numbers.TransactionLimit));
  }

  function getNumShares(uint256 amount) internal view returns (uint256) {
    return usdcToLldu(amount).mul(LLDU_MANTISSA).div(sharePrice);
  }

  function getUSDCAmountFromShares(uint256 llduAmount) internal view returns (uint256) {
    return llduToUSDC(llduAmount.mul(sharePrice).div(LLDU_MANTISSA));
  }

  function sendToReserve(
    address from,
    uint256 amount,
    address userForEvent
  ) internal {
    emit ReserveFundsCollected(userForEvent, amount);
    bool success = doUSDCTransfer(from, config.reserveAddress(), amount);
    require(success, "Reserve transfer was not successful");
  }

  function doUSDCTransfer(
    address from,
    address to,
    uint256 amount
  ) internal returns (bool) {
    require(to != address(0), "Can't send to zero address");
    IERC20withDec usdc = config.getUSDC();
    return usdc.transferFrom(from, to, amount);
  }

  modifier withinTransactionLimit(uint256 amount) {
    require(transactionWithinLimit(amount), "Amount is over the per-transaction limit");
    _;
  }

  modifier onlyCreditDesk() {
    require(msg.sender == config.creditDeskAddress(), "Only the credit desk is allowed to call this function");
    _;
  }

  // Add a new event
  event MigratedToSeniorPool(address indexed seniorPool, uint256 usdcAmount, uint256 compAmount);

  function _requestOffChainComputation(string memory computationType, bytes memory data) internal {
    uint256 requestId = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender)));
    cartesiRollup.sendRequest(requestId, abi.encode(computationType, data));
    emit OffChainComputationRequested(requestId, computationType, data);
  }
}