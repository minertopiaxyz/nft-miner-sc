// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultV1 is Initializable, OwnableUpgradeable {
    uint public VERSION;

    address public ADDRESS_STAKE_TOKEN;
    address public ADDRESS_REWARD_TOKEN;
    address public ADDRESS_POOL;

    struct RewardData {
        uint reward;
        uint totalStake;
        uint rewardPerStake;
        uint createdAt;
    }

    RewardData[] rewardHistory;

    mapping(address => uint) public user2turn;
    mapping(address => uint) public user2stake;
    mapping(address => uint) public user2allowUnstakeTime;
    mapping(address => uint) public user2allowWithdrawTime;
    mapping(address => uint) public user2pendingWithdraw;

    uint public currentTotalStake;
    uint public currentTurn;
    uint public lockingTime;
    uint public unlockingTime;

    event StakeSet(
        address indexed user,
        uint ts,
        uint prevAmount,
        uint nextAmount,
        uint unstakeTs
    );
    event UnstakeSet(
        address indexed user,
        uint ts,
        uint prevAmount,
        uint nextAmount,
        uint withdrawTs
    );
    event WithdrawSet(address indexed user, uint ts, uint total);
    event ClaimReward(
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
        address addrST,
        address addrRT,
        address addrP,
        uint lockingT,
        uint unlockingT
    ) public onlyOwner {
        require(VERSION == 0);
        VERSION = 1;
        ADDRESS_STAKE_TOKEN = addrST;
        ADDRESS_REWARD_TOKEN = addrRT;
        ADDRESS_POOL = addrP;
        lockingTime = lockingT;
        unlockingTime = unlockingT;
    }

    function getData()
        public
        view
        returns (uint, uint, uint, uint, uint, uint)
    {
        return (
            VERSION,
            rewardHistory.length,
            currentTotalStake,
            currentTurn,
            lockingTime,
            unlockingTime
        );
    }

    function getSessionData(
        uint index
    ) public view returns (uint, uint, uint, uint) {
        return (
            rewardHistory[index].reward,
            rewardHistory[index].totalStake,
            rewardHistory[index].rewardPerStake,
            rewardHistory[index].createdAt
        );
    }

    function getUserData(
        address user
    ) public view returns (uint, uint, uint, uint, uint) {
        return (
            user2turn[user],
            user2stake[user],
            user2allowUnstakeTime[user],
            user2allowWithdrawTime[user],
            user2pendingWithdraw[user]
        );
    }

    function stakeToken(uint stakeAmount) public {
        address user = msg.sender;
        require(stakeAmount > 0, "amount 0");
        uint prevStake = user2stake[user];
        require(
            prevStake == 0 || user2turn[user] == currentTurn,
            "have stake or have reward unclaimed"
        );

        IERC20(ADDRESS_STAKE_TOKEN).transferFrom(
            msg.sender,
            address(this),
            stakeAmount
        );

        uint nextStake = prevStake + stakeAmount;
        currentTotalStake = currentTotalStake + stakeAmount;
        user2turn[user] = currentTurn;
        user2stake[user] = nextStake;
        user2allowUnstakeTime[user] = block.timestamp + lockingTime;

        emit StakeSet(
            user,
            block.timestamp,
            prevStake,
            nextStake,
            user2allowUnstakeTime[user]
        );
    }

    function unstakeToken(uint unstakeAmount) public {
        address user = msg.sender;
        require(block.timestamp > user2allowUnstakeTime[user], "invalid time");

        uint userTurn = user2turn[user];
        require(userTurn == currentTurn, "have reward unclaimed");

        uint prevStake = user2stake[user];
        require(unstakeAmount <= prevStake, "invalid unstake amount");

        uint nextStake = prevStake - unstakeAmount;
        currentTotalStake = currentTotalStake - unstakeAmount;
        user2stake[user] = nextStake;

        uint prevPending = user2pendingWithdraw[msg.sender];
        user2pendingWithdraw[msg.sender] = prevPending + unstakeAmount;
        user2allowWithdrawTime[msg.sender] = block.timestamp + unlockingTime;

        emit UnstakeSet(
            user,
            block.timestamp,
            prevStake,
            nextStake,
            user2allowWithdrawTime[msg.sender]
        );
    }

    function withdrawToken() public {
        require(user2pendingWithdraw[msg.sender] > 0, "no pending withdraw");
        require(
            block.timestamp > user2allowWithdrawTime[msg.sender],
            "invalid time"
        );

        uint amount = user2pendingWithdraw[msg.sender];
        user2pendingWithdraw[msg.sender] = 0;

        IERC20(ADDRESS_STAKE_TOKEN).transfer(msg.sender, amount);

        emit WithdrawSet(msg.sender, block.timestamp, amount);
    }

    function claimReward() public {
        address user = msg.sender;
        uint userStartTurn = user2turn[user];

        require(user2stake[user] > 0, "have not stake");
        require(userStartTurn < currentTurn, "reward already claimed");

        uint totalReward = getUnclaimedReward(user);
        user2turn[user] = currentTurn;

        if (totalReward > 0)
            IERC20(ADDRESS_REWARD_TOKEN).transfer(msg.sender, totalReward);

        emit ClaimReward(
            user,
            block.timestamp,
            userStartTurn,
            currentTurn,
            totalReward
        );
    }

    function getUnclaimedReward(address user) public view returns (uint) {
        uint totalReward;
        uint userStartTurn = user2turn[user];
        uint stake = user2stake[user];

        for (uint i = userStartTurn; i < currentTurn; i++) {
            uint singleReward = rewardHistory[i].rewardPerStake;
            uint reward = (singleReward * stake) / 1e18;
            totalReward = totalReward + reward;
        }

        return (totalReward);
    }

    function canUpdate() public view returns (bool) {
        return (currentTotalStake > 0);
    }

    function updateSession(uint reward) public {
        require(msg.sender == ADDRESS_POOL);
        require(canUpdate());

        uint rewardPerStake = (reward * 1e18) / currentTotalStake;
        currentTurn = currentTurn + 1;

        rewardHistory.push(
            RewardData(
                reward,
                currentTotalStake,
                rewardPerStake,
                block.timestamp
            )
        );
    }
}
