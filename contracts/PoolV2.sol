// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interface.sol";

contract PoolV2 is Initializable, OwnableUpgradeable {
    uint public VERSION;

    address public ADDRESS_TOKEN;
    address public ADDRESS_BANK;
    address public ADDRESS_NFTREWARD;
    address public ADDRESS_TREWARD;

    uint public lastUpdateTime;
    uint public lastPumpPriceTime;
    uint public divider;

    event PumpPrice(uint ts, uint interest);
    event UpdateReward(uint ts, uint totalReward);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
    }

    receive() external payable {}

    fallback() external payable {}

    function setup(
        address addrToken,
        address addrBank,
        address addrNR,
        address addrTR
    ) public onlyOwner {
        require(VERSION == 0);
        VERSION = 1;
        ADDRESS_TOKEN = addrToken;
        ADDRESS_BANK = addrBank;
        ADDRESS_NFTREWARD = addrNR;
        ADDRESS_TREWARD = addrTR;

        lastUpdateTime = block.timestamp;
        lastPumpPriceTime = block.timestamp;

        divider = 24 * 365;
        // pump price every 1 hour, 24 times daily
    }

    function pumpPrice() public payable returns (uint) {
        require((block.timestamp - lastPumpPriceTime) >= 3600, "invalid time");
        address ADDRESS_ROUTER = address(0); // address of uniswap v2 router

        // claim yield
        uint interest = msg.value;
        if (interest == 0) {
            // claim yield here
        }

        // buy back token & remove it from circulation
        if (interest > 0) {
            address[] memory path = new address[](2);
            path[0] = IUniswapV2Router02(ADDRESS_ROUTER).WETH();
            path[1] = ADDRESS_TOKEN;

            // uint256[] memory amounts = IUniswapV2Router02(ADDRESS_ROUTER)
            IUniswapV2Router02(ADDRESS_ROUTER)
                .swapExactETHForTokens{value: interest}(
                1,
                path,
                ADDRESS_BANK,
                block.timestamp
            );
            // uint numToken = (amounts[1]);
        }

        return (interest);
    }

    function update() public returns (uint) {
        bool byPassTimeCheck = (msg.sender == owner());
        uint dt = block.timestamp - lastUpdateTime;

        require(dt >= 86400 || byPassTimeCheck, "invalid time");
        lastUpdateTime = block.timestamp;

        uint supply = IERC20(ADDRESS_TOKEN).totalSupply();
        uint locked = IERC20(ADDRESS_TOKEN).balanceOf(ADDRESS_BANK);
        uint unlocked = supply - locked;

        uint pctg = (unlocked * 1 * dt) / 3153600000; // 31536000 = 1Y, 1%
        uint reward1 = pctg * 10;
        uint reward2 = pctg * 5;

        uint totalReward = 0;

        if (IRewardReceiver(ADDRESS_NFTREWARD).canUpdate()) {
            IBank(ADDRESS_BANK).unlockReward(reward1, ADDRESS_NFTREWARD);
            IRewardReceiver(ADDRESS_NFTREWARD).updateSession(reward1);
            totalReward = totalReward + reward1;
        }

        if (IRewardReceiver(ADDRESS_TREWARD).canUpdate()) {
            IBank(ADDRESS_BANK).unlockReward(reward2, ADDRESS_TREWARD);
            IRewardReceiver(ADDRESS_TREWARD).updateSession(reward2);
            totalReward = totalReward + reward2;
        }

        emit UpdateReward(block.timestamp, totalReward);
        return (totalReward);
    }

    function stake() public payable returns (uint) {
        uint balance = address(this).balance;
        // invest pool's native assets to staking or defi
        return (balance);
    }
}
