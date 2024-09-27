require('dotenv').config();
const { MNEMONIC, ARBI_API_KEY } = process.env;
const HDWalletProvider = require('@truffle/hdwallet-provider');

module.exports = {
  api_keys: {
    arbiscan: ARBI_API_KEY
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  networks: {
    arbitrum_blueberry: {
      provider: () => new HDWalletProvider({
        mnemonic: MNEMONIC,
        providerOrUrl: 'https://rpc.arb-blueberry.gelato.digital'
      }),
      network_id: 88153591557,
      gas: 6000000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    arbitrum_sepolia: {
      provider: () => new HDWalletProvider({
        mnemonic: MNEMONIC,
        providerOrUrl: 'https://arb-sepolia.g.alchemy.com/v2/Ndodys40XWZ2qIZxb_CS6kp2NYv2rHhk'
      }),
      network_id: 421614,
      gas: 6000000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },
  },
  compilers: {
    solc: {
      version: "0.8.11",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
};