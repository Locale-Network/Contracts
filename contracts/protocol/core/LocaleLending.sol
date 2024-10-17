// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LocaleLending is Ownable {
  struct Loan {
    uint256 amount;
    uint256 interestRate;
    uint256 term;
    address borrower;
    uint256 startTime;
    bool isApproved;
    bool isRepaid;
  }

  struct LenderShare {
    uint256 amount;
    uint256 lastUpdateTime;
  }

  IERC20 public usdcToken;
  uint256 public totalLoans;
  uint256 public totalPoolShares;
  uint256 public totalPoolFunds;
  mapping(uint256 => Loan) public loans;
  mapping(address => uint256[]) public borrowerLoans;
  mapping(address => LenderShare) public lenderShares;

  event LoanRequested(uint256 loanId, address borrower, uint256 amount, uint256 interestRate, uint256 term);
  event LoanApproved(uint256 loanId, address borrower);
  event LoanRepaid(uint256 loanId, address borrower);
  event Deposited(address lender, uint256 amount);
  event Withdrawn(address lender, uint256 amount);

  constructor(address _usdcToken) Ownable() {
    require(_usdcToken != address(0), "Invalid USDC token address");
    usdcToken = IERC20(_usdcToken);
  }

  function requestLoan(uint256 amount, uint256 interestRate, uint256 term) external {
    require(amount > 0, "Loan amount must be greater than zero");
    require(term > 0, "Loan term must be greater than zero");

    uint256 loanId = totalLoans++;
    loans[loanId] = Loan({
      amount: amount,
      interestRate: interestRate,
      term: term,
      borrower: msg.sender,
      startTime: 0,
      isApproved: false,
      isRepaid: false
    });

    borrowerLoans[msg.sender].push(loanId);
    emit LoanRequested(loanId, msg.sender, amount, interestRate, term);
  }

  function depositToPool(uint256 amount) external {
    require(amount > 0, "Deposit amount must be greater than zero");
    usdcToken.transferFrom(msg.sender, address(this), amount);
    
    updateLenderShare(msg.sender);
    lenderShares[msg.sender].amount += amount;
    totalPoolShares += amount;
    totalPoolFunds += amount;

    emit Deposited(msg.sender, amount);
  }

  function withdrawFromPool(uint256 amount) external {
    updateLenderShare(msg.sender);
    require(lenderShares[msg.sender].amount >= amount, "Insufficient balance");
    
    lenderShares[msg.sender].amount -= amount;
    totalPoolShares -= amount;
    totalPoolFunds -= amount;
    
    usdcToken.transfer(msg.sender, amount);
    emit Withdrawn(msg.sender, amount);
  }

  function updateLenderShare(address lender) internal {
    uint256 elapsedTime = block.timestamp - lenderShares[lender].lastUpdateTime;
    if (elapsedTime > 0 && totalPoolShares > 0) {
      uint256 interestEarned = (totalPoolFunds * elapsedTime) / (365 days);
      uint256 lenderInterest = (interestEarned * lenderShares[lender].amount) / totalPoolShares;
      lenderShares[lender].amount += lenderInterest;
      totalPoolShares += lenderInterest;
      totalPoolFunds += lenderInterest;
    }
    lenderShares[lender].lastUpdateTime = block.timestamp;
  }

  function approveLoan(uint256 loanId) external onlyOwner {
    Loan storage loan = loans[loanId];
    require(!loan.isApproved, "Loan is already approved");
    require(totalPoolFunds >= loan.amount, "Insufficient funds in the pool");

    loan.isApproved = true;
    loan.startTime = block.timestamp;

    totalPoolFunds -= loan.amount;
    usdcToken.transfer(loan.borrower, loan.amount);
    emit LoanApproved(loanId, loan.borrower);
  }

  function repayLoan(uint256 loanId) external {
    Loan storage loan = loans[loanId];
    require(loan.isApproved, "Loan is not approved");
    require(!loan.isRepaid, "Loan is already repaid");
    require(msg.sender == loan.borrower, "Only borrower can repay the loan");

    uint256 interest = (loan.amount * loan.interestRate * loan.term) / (100 * 365 * 24 * 3600);
    uint256 totalRepayment = loan.amount + interest;

    usdcToken.transferFrom(msg.sender, address(this), totalRepayment);
    loan.isRepaid = true;
    totalPoolFunds += totalRepayment;
    emit LoanRepaid(loanId, msg.sender);
  }

  function getTotalActiveLoans() external view returns (uint256) {
    if (totalLoans == 0) {
      return 0;
    }

    uint256 totalActiveAmount = 0;
    for (uint256 i = 0; i < totalLoans; i++) {
      if (loans[i].isApproved && !loans[i].isRepaid) {
        totalActiveAmount += loans[i].amount;
      }
    }
    return totalActiveAmount;
  }

  function getTotalLossRate() external view returns (uint256) {
    if (totalLoans == 0) {
      return 0;
    }

    uint256 totalRepaid;
    uint256 totalApproved;
    for (uint256 i = 0; i < totalLoans; i++) {
      if (loans[i].isApproved) {
        totalApproved += loans[i].amount;
        if (loans[i].isRepaid) {
          totalRepaid += loans[i].amount;
        }
      }
    }
    if (totalApproved == 0) {
      return 0;
    }
    return ((totalApproved - totalRepaid) * 100) / totalApproved;
  }

  function getTotalLoansRepaid() external view returns (uint256) {
    if (totalLoans == 0) {
      return 0;
    }

    uint256 totalRepaid;
    for (uint256 i = 0; i < totalLoans; i++) {
      if (loans[i].isRepaid) {
        totalRepaid += loans[i].amount;
      }
    }
    return totalRepaid;
  }

  function getLenderBalance(address lender) external view returns (uint256) {
    return lenderShares[lender].amount;
  }
}
