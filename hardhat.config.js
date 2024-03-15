require('dotenv').config();
require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');

const PRIVATEKEY_MAINNET = process.env.PRIVATEKEY_MAINNET;
const PRIVATEKEY_TESTNET = process.env.PRIVATEKEY_MAINNET;
const PRIVATEKEY_DUMMY = process.env.PRIVATEKEY_DUMMY;
const BNB_URL = process.env.BNB_URL;
const ETHERSCAN_APIKEY = process.env.ETHERSCAN_APIKEY;

// example: npx hardhat flatten contracts/Token.sol > flattened.sol
task("flat", "Flattens and prints contracts and their dependencies (Resolves licenses)")
  .addOptionalVariadicPositionalParam("files", "The files to flatten", undefined, types.inputFile)
  .setAction(async ({ files }, hre) => {
    let flattened = await hre.run("flatten:get-flattened-sources", { files });

    // Remove every line started with "// SPDX-License-Identifier:"
    flattened = flattened.replace(/SPDX-License-Identifier:/gm, "License-Identifier:");
    flattened = `// SPDX-License-Identifier: MIXED\n\n${flattened}`;

    // Remove every line started with "pragma experimental ABIEncoderV2;" except the first one
    flattened = flattened.replace(/pragma experimental ABIEncoderV2;\n/gm, ((i) => (m) => (!i++ ? m : ""))(0));
    console.log(flattened);
  });

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.18",
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://bscscan.com/
    apiKey: ETHERSCAN_APIKEY
  },
  settings: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  },
  defaultNetwork: "test",
  networks: {
    test: {
      chainId: 71,
      url: 'https://evmtestnet.confluxrpc.com',
      accounts: [PRIVATEKEY_TESTNET]
    },
    espace: {
      chainId: 1030,
      url: 'https://evm.confluxrpc.com',
      accounts: [PRIVATEKEY_MAINNET]
    },
    // fork: {
    //   chainId: 1030,
    //   url: 'http://127.0.0.1:8545',
    //   accounts: [PRIVATEKEY_MAINNET]
    // },
    fork: {
      chainId: 7700,
      url: 'http://127.0.0.1:8545',
      accounts: [PRIVATEKEY_DUMMY]
    },
    bnb: {
      chainId: 56,
      url: BNB_URL,
      accounts: [PRIVATEKEY_MAINNET]
    },
    sphinx: {
      url: "https://rpc2-sphinx.shardeum.org",
      chainId: 8082,
      accounts: [PRIVATEKEY_MAINNET],
    },
  }
};

