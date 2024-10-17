# Contract Deployment and Verification Guide

## Prerequisites

Ensure you have Node.js and npm installed on your system.

## Installation

Install the required dependencies:

```bash
npm install --save @openzeppelin/contracts
npm install --save erc721a
npm install --save @chainlink/contracts
```

## Deploy contract

```bash
truffle deploy --network arbitrum_blueberry --reset
```

## Verify contract

```bash
truffle run verify LocaleLending --network arbitrum_blueberry
```

## Environment Variables

Environment variables are used to store sensitive information and configuration settings that should not be committed directly to the source code. In this project, we use a `.env` file to manage these variables. Here's an explanation of the variables in our `.env` file:

1. `MNEMONIC`: A 12-word seed phrase used to generate deterministic wallets. This is crucial for deploying contracts and should be kept secret.

2. `MNEMONIC_ANVIL`: Another mnemonic, specifically used for Anvil (a local Ethereum network for testing and development).

3. `ARBI_API_KEY`: API key for interacting with Arbitrum-related services.

To use these environment variables:

1. Create a `.env` file in the root directory of your project.
2. Add your variables to the file in the format `KEY=VALUE`, one per line.
3. Make sure to add `.env` to your `.gitignore` file to prevent accidentally committing sensitive information.