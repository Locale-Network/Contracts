// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract LocaleLending {
  struct Loan {
    uint256 amount;
    uint256 interestRate;
    uint256 dueDate;
    bool repaid;
    bool approved;
    bool activeLoan;
  }

  mapping(address => Loan) public loans;

  struct Stake {
    uint256 amount;
    uint256 stakeTime;
  }

  mapping(address => Stake) public stakes;

  uint256 public totalLoansRepaid;
  uint256 public totalLoanedAmount;
  uint256 public totalLossRate;

  event LoanCreated(
    address borrower,
    uint256 amount,
    uint256 interestRate,
    uint256 dueDate
  );

  event LoanApproved(
    address borrower,
    uint256 amount,
    uint256 interestRate,
    uint256 dueDate
  );

  event LoanRepaid(address borrower, uint256 amount);

  event Staked(address staker, uint256 amount);

  event Unstaked(address staker, uint256 amount);

  modifier onlyApprovedLoan(address borrower) {
    require(loans[borrower].approved, "Loan not approved");
    _;
  }

  function submitLoanRequest(
    uint256 _amount,
    uint256 _interestRate,
    uint256 _dueDate
  ) external {
    require(
      !loans[msg.sender].activeLoan,
      "Loan already exists for borrower"
    );

    loans[msg.sender] = Loan({
      amount: _amount,
      interestRate: _interestRate,
      dueDate: _dueDate,
      repaid: false,
      approved: false,
      activeLoan: true
    });

    emit LoanCreated(msg.sender, _amount, _interestRate, _dueDate);
  }

  function approveLoanRequest(address _borrower) external {
    Loan storage loan = loans[_borrower];
    require(loan.amount > 0, "No loan request found");
    require(!loan.approved, "Loan already approved");

    loan.approved = true;
    totalLoanedAmount += loan.amount;

    emit LoanApproved(
      _borrower,
      loan.amount,
      loan.interestRate,
      loan.dueDate
    );
  }

  function repayLoan() external payable onlyApprovedLoan(msg.sender) {
    Loan storage loan = loans[msg.sender];
    require(loan.amount > 0, "No loan exists for borrower");
    require(!loan.repaid, "Loan already repaid");
    require(block.timestamp <= loan.dueDate, "Loan is past due");
    require(
      msg.value >= loan.amount + (loan.amount * loan.interestRate) / 100,
      "Insufficient repayment amount"
    );

    loan.repaid = true;
    totalLoansRepaid += loan.amount;

    emit LoanRepaid(msg.sender, loan.amount);
  }

  function stake() external payable {
    require(msg.value > 0, "Must send ETH to stake");

    stakes[msg.sender].amount += msg.value;
    stakes[msg.sender].stakeTime = block.timestamp;

    emit Staked(msg.sender, msg.value);
  }

  function unstake() external {
    Stake storage stakeInfo = stakes[msg.sender];
    require(stakeInfo.amount > 0, "No stake found");

    uint256 amountToUnstake = stakeInfo.amount;
    stakeInfo.amount = 0;

    payable(msg.sender).transfer(amountToUnstake);

    emit Unstaked(msg.sender, amountToUnstake);
  }

  function isLoanRepaid(address _borrower) external view returns (bool) {
    return loans[_borrower].repaid;
  }

  function getStakeAmount(address _staker) external view returns (uint256) {
    return stakes[_staker].amount;
  }

  function getActiveLoans() external view returns (uint256) {
    uint256 activeLoans = 0;

    for (uint i = 0; i < totalLoanedAmount; i++) {
      if (!loans[msg.sender].repaid) {
        activeLoans += loans[msg.sender].amount;
      }
    }

    return activeLoans;
  }

  function getTotalLossRate() external view returns (uint256) {
    if (totalLoanedAmount == 0) return 0;
    uint256 losses = totalLoanedAmount - totalLoansRepaid;
    return (losses * 100) / totalLoanedAmount;
  }

  function getTotalLoansRepaid() external view returns (uint256) {
    return totalLoansRepaid;
  }
}