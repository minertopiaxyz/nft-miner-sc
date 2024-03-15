// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTRewardV1 is Initializable, OwnableUpgradeable {
    uint public VERSION;

    address public ADDRESS_NFT;
    address public ADDRESS_REWARD_TOKEN;
    address public ADDRESS_POOL;

    struct RewardData {
        uint reward;
        uint totalBasePower;
        uint rewardPerBP;
        uint totalExtraPower;
        uint rewardPerEP;
        uint createdAt;
    }

    RewardData[] rewardHistory;

    uint public currentTurn;
    uint public totalBasePower;
    uint public totalExtraPower;

    mapping(uint => uint) public nftId2turn;
    mapping(uint => uint) public nftId2basePower;
    mapping(uint => uint) public nftId2extraPower;

    event BasePowerSet(uint indexed nftId, uint ts, uint bp);
    event ExtraPowerSet(uint indexed nftId, uint ts, uint epPrev, uint ep);
    event ClaimReward(
        uint indexed nftId,
        address indexed claimer,
        uint ts,
        uint startTurn,
        uint currentTurn,
        uint totalReward
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
    }

    function setup(
        address addrN,
        address addrRT,
        address addrP
    ) public onlyOwner {
        require(VERSION == 0);
        VERSION = 1;
        ADDRESS_NFT = addrN;
        ADDRESS_REWARD_TOKEN = addrRT;
        ADDRESS_POOL = addrP;
    }

    function getData()
        public
        view
        returns (uint, uint, uint, uint, uint, uint)
    {
        return (
            VERSION,
            rewardHistory.length,
            currentTurn,
            totalBasePower,
            totalExtraPower,
            0
        );
    }

    function getSessionData(
        uint index
    ) public view returns (uint, uint, uint, uint, uint, uint) {
        return (
            rewardHistory[index].reward,
            rewardHistory[index].totalBasePower,
            rewardHistory[index].rewardPerBP,
            rewardHistory[index].totalExtraPower,
            rewardHistory[index].rewardPerEP,
            rewardHistory[index].createdAt
        );
    }

    function setBase(uint nftId, uint stakeAmount) public {
        require(msg.sender == ADDRESS_NFT);

        totalBasePower = totalBasePower + stakeAmount;
        nftId2turn[nftId] = currentTurn;
        nftId2basePower[nftId] = stakeAmount;

        emit BasePowerSet(nftId, block.timestamp, stakeAmount);
    }

    function setExtra(uint nftId, uint stakeAmount) public {
        require(msg.sender == ADDRESS_NFT);
        require(nftId2turn[nftId] == currentTurn, "have reward unclaimed");

        uint prevEP = nftId2extraPower[nftId];
        totalExtraPower = (totalExtraPower - prevEP) + stakeAmount;
        nftId2extraPower[nftId] = stakeAmount;

        emit ExtraPowerSet(nftId, block.timestamp, prevEP, stakeAmount);
    }

    function claimReward(uint nftId) public {
        address nftOwner = IERC721(ADDRESS_NFT).ownerOf(nftId);
        require(msg.sender == nftOwner, "not owner");
        uint startTurn = nftId2turn[nftId];
        require(startTurn < currentTurn, "reward already claimed");

        (uint totalReward, , ) = getUnclaimedReward(nftId);
        nftId2turn[nftId] = currentTurn;

        if (totalReward > 0)
            IERC20(ADDRESS_REWARD_TOKEN).transfer(msg.sender, totalReward);

        emit ClaimReward(
            nftId,
            nftOwner,
            block.timestamp,
            startTurn,
            currentTurn,
            totalReward
        );
    }

    function getUnclaimedReward(
        uint nftId
    ) public view returns (uint, uint, uint) {
        uint startTurn = nftId2turn[nftId];
        uint bp = nftId2basePower[nftId];
        uint ep = nftId2extraPower[nftId];
        uint trBP = 0;
        uint trEP = 0;

        for (uint i = startTurn; i < currentTurn; i++) {
            uint singleReward = rewardHistory[i].rewardPerBP;
            uint reward = (singleReward * bp) / 1e18;
            trBP = trBP + reward;

            if (ep > 0) {
                uint srEP = rewardHistory[i].rewardPerEP;
                uint rEP = (srEP * ep) / 1e18;
                trEP = trEP + rEP;
            }
        }

        return ((trBP + trEP), trBP, trEP);
    }

    function canUpdate() public view returns (bool) {
        return (totalBasePower > 0);
    }

    function updateSession(uint reward) public {
        require(msg.sender == ADDRESS_POOL);
        require(canUpdate());

        uint rewardBP = reward;
        uint rewardEP = 0;
        if (totalExtraPower > 0) {
            rewardEP = (reward * 7) / 10; // 70%
            rewardBP = reward - rewardEP; // 30%
        }

        uint rewardPerBP = (rewardBP * 1e18) / totalBasePower;
        uint rewardPerEP = (rewardEP * 1e18) / totalExtraPower;
        currentTurn = currentTurn + 1;

        rewardHistory.push(
            RewardData(
                reward,
                totalBasePower,
                rewardPerBP,
                totalExtraPower,
                rewardPerEP,
                block.timestamp
            )
        );
    }
}
