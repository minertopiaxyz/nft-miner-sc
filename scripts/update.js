
const { ethers, upgrades } = require("hardhat");
const jsonfile = require('jsonfile');
const path = './config.json';
const addr = jsonfile.readFileSync(path);
const MODE = process.env.MODE;
const delayMS = MODE === 'FORK' ? 1000 : 180000;

async function main() {
  async function upgrade(scName, scAddress) {
    const SC = await ethers.getContractFactory(scName, scAddress);
    const sc = await upgrades.upgradeProxy(scAddress, SC);
    console.log(scName);
    console.log("upgraded to:", sc.address);
    console.log('done');
    await delay(delayMS);
  }

  const rows = [
    { name: 'BankV1', address: addr.bank },
    // { name: 'GuardV3', address: addr.guard },
    { name: 'NFTRewardV1', address: addr.nftreward },
    { name: 'NFTV1', address: addr.nft },
    { name: 'PoolV1', address: addr.pool },
    { name: 'VaultV1', address: addr.vault }
  ];

  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    await upgrade(row.name, row.address);
  }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

// npx hardhat run --network fork scripts/update.js

async function delay(ms) {
  console.log('wait for ' + (ms / 1000) + ' secs...');
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      resolve();
    }, ms);
  })
}
