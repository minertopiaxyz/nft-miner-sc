
const { ethers, upgrades } = require("hardhat");
const jsonfile = require('jsonfile');
const path = './config.json';
const addr = jsonfile.readFileSync(path);
const MODE = process.env.MODE;
const delayMS = MODE === 'FORK' ? 1000 : 180000;

function wei2eth(wei) {
  return ethers.utils.formatUnits(wei, "ether");
}

function eth2wei(eth) {
  return ethers.utils.parseEther(eth);
}

async function delay(ms) {
  console.log('wait for ' + (ms / 1000) + ' secs...');
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      resolve();
    }, ms);
  })
}

async function getSC(scName, scAddr) {
  const SC = await ethers.getContractFactory(scName);
  const sc = await SC.attach(scAddr);
  return sc;
}

async function setupBank() {
  const bank = await getSC("BankV1", addr.bank);
  const amountCoin = eth2wei('0.0001');
  const amountToken = eth2wei('10000');
  const tx = await bank.setup(amountToken, addr.token, addr.pool, { value: amountCoin });
  console.log(tx.hash);
  await tx.wait();
  console.log('bank.setup done');
}

async function setupNFTReward() {
  const nftReward = await getSC("NFTRewardV1", addr.nftreward);
  const tx = await nftReward.setup(
    addr.nft,
    addr.token,
    addr.pool
  );
  console.log(tx.hash);
  await tx.wait();
  console.log('nftReward.setup done');
}

async function setupNFT() {
  const price = eth2wei('0.0001');
  const maxSupply = '3333';
  const nft = await getSC("NFTV1", addr.nft);
  const tx = await nft.setup(
    addr.pool,
    addr.nftreward,
    price,
    maxSupply
  );
  console.log(tx.hash);
  await tx.wait();
  console.log('nft.setup done');
}

async function setupPool() {
  const pool = await getSC("PoolV1", addr.pool);
  const tx = await pool.setup(
    addr.token,
    addr.bank,
    addr.nftreward,
    addr.vault
  );
  console.log(tx.hash);
  await tx.wait();
  console.log('pool.setup done');
}

async function setupVault() {
  const oneDay = 3600 * 24;
  const vault = await getSC("VaultV1", addr.vault);
  const tx = await vault.setup(
    addr.token,
    addr.token,
    addr.pool,
    oneDay,
    oneDay
  );
  console.log(tx.hash);
  await tx.wait();
  console.log('vault.setup done');
}

async function main() {
  await setupBank();
  await delay(delayMS);
  await setupNFTReward();
  await delay(delayMS);
  await setupNFT();
  await delay(delayMS);
  await setupPool();
  await delay(delayMS);
  await setupVault();
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

// npx hardhat run --network test scripts/setup.js

