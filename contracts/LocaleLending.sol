// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract LoanContract {
  struct Loan {
    uint256 principal;
    uint256 interestRate;
    uint256 loanTerm;
    uint256 noi;
  }

  mapping(address => Loan) public loans;
  address public cartesiBackend;
  address public owner;

  event LoanCreated(
    address borrower,
    uint256 principal,
    uint256 interestRate,
    uint256 loanTerm
  );
  event RateAdjusted(address borrower, uint256 newInterestRate);

  modifier onlyCartesiBackend() {
    require(
      msg.sender == cartesiBackend,
      "Only Cartesi Backend can call this"
    );
    _;
  }

  constructor(address _cartesiBackend) {
    cartesiBackend = _cartesiBackend;
    owner = msg.sender;
  }

  function createLoan(
    uint256 _principal,
    uint256 _interestRate,
    uint256 _loanTerm,
    uint256 _noi
  ) public {
    loans[msg.sender] = Loan(_principal, _interestRate, _loanTerm, _noi);
    emit LoanCreated(msg.sender, _principal, _interestRate, _loanTerm);
  }

  function requestRateAdjustment() public {
    Loan storage loan = loans[msg.sender];
    CartesiRollup(cartesiBackend).requestRateAdjustment(
      msg.sender,
      loan.principal,
      loan.interestRate,
      loan.loanTerm,
      loan.noi
    );
  }

  function adjustRate(uint256 _newInterestRate) external onlyCartesiBackend {
    loans[msg.sender].interestRate = _newInterestRate;
    emit RateAdjusted(msg.sender, _newInterestRate);
  }
}

interface CartesiRollup {
  function requestRateAdjustment(
    address borrower,
    uint256 principal,
    uint256 interestRate,
    uint256 loanTerm,
    uint256 noi
  ) external;
}