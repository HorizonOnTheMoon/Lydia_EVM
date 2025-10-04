require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

const PRIVATE_KEY = process.env.PRIVATE_KEY || "";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY || "";
const INFURA_PROJECT_ID = process.env.INFURA_PROJECT_ID || "";

module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  networks: {
    hardhat: {
      chainId: 1337,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 1337,
    },
    ethereum: {
      url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
      accounts: PRIVATE_KEY && PRIVATE_KEY.length === 64 ? [PRIVATE_KEY] : [],
      chainId: 1,
      gasPrice: "auto",
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${INFURA_PROJECT_ID}`,
      accounts: PRIVATE_KEY && PRIVATE_KEY.length === 64 ? [PRIVATE_KEY] : [],
      chainId: 5,
      gasPrice: "auto",
    },
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_PROJECT_ID}`,
      accounts: PRIVATE_KEY && PRIVATE_KEY.length === 64 ? [PRIVATE_KEY] : [],
      chainId: 11155111,
      gasPrice: "auto",
    },
    arbitrum: {
      url: "https://arb1.arbitrum.io/rpc",
      accounts: PRIVATE_KEY && PRIVATE_KEY.length === 64 ? [PRIVATE_KEY] : [],
      chainId: 42161,
      gasPrice: "auto",
    },
    arbitrumGoerli: {
      url: "https://goerli-rollup.arbitrum.io/rpc",
      accounts: PRIVATE_KEY && PRIVATE_KEY.length === 64 ? [PRIVATE_KEY] : [],
      chainId: 421613,
      gasPrice: "auto",
    },
    polygon: {
      url: "https://polygon-rpc.com/",
      accounts: PRIVATE_KEY && PRIVATE_KEY.length === 64 ? [PRIVATE_KEY] : [],
      chainId: 137,
      gasPrice: "auto",
    },
    mumbai: {
      url: "https://matic-mumbai.chainstacklabs.com",
      accounts: PRIVATE_KEY && PRIVATE_KEY.length === 64 ? [PRIVATE_KEY] : [],
      chainId: 80001,
      gasPrice: "auto",
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org/",
      accounts: PRIVATE_KEY && PRIVATE_KEY.length === 64 ? [PRIVATE_KEY] : [],
      chainId: 56,
      gasPrice: "auto",
    },
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      accounts: PRIVATE_KEY && PRIVATE_KEY.length === 64 ? [PRIVATE_KEY] : [],
      chainId: 97,
      gasPrice: "auto",
    },
  },
  etherscan: {
    apiKey: {
      mainnet: ETHERSCAN_API_KEY,
      goerli: ETHERSCAN_API_KEY,
      sepolia: ETHERSCAN_API_KEY,
      arbitrumOne: process.env.ARBISCAN_API_KEY || "",
      arbitrumGoerli: process.env.ARBISCAN_API_KEY || "",
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || "",
      bsc: process.env.BSCSCAN_API_KEY || "",
      bscTestnet: process.env.BSCSCAN_API_KEY || "",
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};