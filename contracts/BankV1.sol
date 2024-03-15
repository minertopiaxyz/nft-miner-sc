// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BankV1 is Initializable, OwnableUpgradeable {
    uint public VERSION;

    address public ADDRESS_TOKEN;
    address public ADDRESS_UNLOCKER;

    uint public basePrice;

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
        uint amountToken,
        address addrT,
        address addrU
    ) public payable onlyOwner {
        require(VERSION == 0);
        require(msg.value > 0, "no coin amount");
        VERSION = 1;
        ADDRESS_TOKEN = addrT;
        ADDRESS_UNLOCKER = addrU;

        IERC20(ADDRESS_TOKEN).transfer(msg.sender, amountToken);
        updateBasePrice();
    }

    function updateBasePrice() public payable returns (uint) {
        uint supply = IERC20(ADDRESS_TOKEN).totalSupply();
        uint locked = IERC20(ADDRESS_TOKEN).balanceOf(address(this));
        uint onCirculation = supply - locked;
        uint collateral = address(this).balance;
        basePrice = (collateral * 1e18) / onCirculation;
        return basePrice;
    }

    function coinToToken(uint amountCoin) public view returns (uint) {
        uint m = 1050;
        uint mintPrice = (basePrice * m) / 1000;
        uint amountToken = (amountCoin * 1e18) / mintPrice;
        return amountToken;
    }

    function tokenToCoin(uint amountToken) public view returns (uint) {
        uint m = 950;
        uint burnPrice = (basePrice * m) / 1000;
        uint amountCoin = (amountToken * burnPrice) / 1e18;
        return amountCoin;
    }

    function swapCoinToToken(address receiver) public payable returns (uint) {
        uint amountCoin = msg.value;
        require(amountCoin > 0);
        uint amountToken = coinToToken(amountCoin);
        IERC20(ADDRESS_TOKEN).transfer(receiver, amountToken);
        updateBasePrice();
        return (amountToken);
    }

    function swapTokenToCoin(
        uint amountToken,
        address receiver
    ) public returns (uint) {
        require(amountToken > 0);
        uint amountCoin = tokenToCoin(amountToken);
        IERC20(ADDRESS_TOKEN).transferFrom(
            msg.sender,
            address(this),
            amountToken
        );
        (bool success, ) = receiver.call{value: amountCoin}("");
        require(success, "failed to send");
        updateBasePrice();
        return (amountCoin);
    }

    function unlockReward(
        uint amountToken,
        address receiver
    ) public returns (uint) {
        require(msg.sender == ADDRESS_UNLOCKER);
        IERC20(ADDRESS_TOKEN).transfer(receiver, amountToken);
        return (amountToken);
    }
}
