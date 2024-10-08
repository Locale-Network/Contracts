# Deploy & Verify contract
## Install packages
 1) npm install --save @openzeppelin/contracts
 2) npm install --save erc721a
 3) npm install --save @chainlink/contracts
## Deploy contract
truffle deploy --network arbitrum_blueberry

## Verify contract
truffle run verify LocaleLending --network arbitrum_blueberry