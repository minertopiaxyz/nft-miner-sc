// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
require('dotenv').config();
const { ethers, upgrades } = require("hardhat");
const jsonfile = require('jsonfile');
const path = './config.json';
const MODE = process.env.MODE;
const delayMS = MODE === 'FORK' ? 1000 : 180000;

async function delay(ms) {
  console.log('wait for ' + (ms / 1000) + ' secs...');
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      resolve();
    }, ms);
  })
}

async function main() {
  let config;
  config = await deployProxy('bank', 'BankV0');
  config = await deployToken();
  config = await deployProxy('guard', 'GuardV0');
  config = await deployProxy('nftreward', 'NFTRewardV0');
  config = await deployProxy('nft', 'NFTV0', ['Minertopia Citizen', 'MINERTOPIA']);
  config = await deployProxy('pool', 'PoolV0');
  config = await deployProxy('vault', 'VaultV0');
  console.log(config);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

async function deployProxy(configName, scName, params) {
  const config = await jsonfile.readFile(path);
  if (!params) params = [];
  const SC = await ethers.getContractFactory(scName);
  const sc = await upgrades.deployProxy(SC, params);
  await sc.deployed();
  console.log(scName + ' deployed at: ' + sc.address);
  config[configName] = sc.address;
  await jsonfile.writeFile(path, config);
  await delay(delayMS);
  return config;
}

async function deployToken() {
  const config = await jsonfile.readFile(path);
  const tokenName = "Minertopia Token";
  const tokenSymbol = "MTK";
  const bankAddress = config.bank;
  const Token = await ethers.getContractFactory("Token");
  const token = await Token.deploy(bankAddress, tokenName, tokenSymbol);
  const tokenAddress = token.address;
  config.token = tokenAddress;
  await jsonfile.writeFile(path, config);
  return config;
}

// reset steps:
// 0. rm -rf cache
// 1. rm -rf .openzeppelin
// 2. rm -rf artifacts
// 3. rewrite config.json to {}

// fork
// use nodejs v18
// npx hardhat compile
// npx hardhat run --network cantotest scripts/deploy.js
// npx hardhat run --network cantotest scripts/update.js
// npx hardhat run --network cantotest scripts/setup.js
// copy config.js & json(s)
// node init.js
// node bot.js

// npx hardhat flatten contracts/Token.sol > Token.sol
// notes: nft price & initial liquidity















