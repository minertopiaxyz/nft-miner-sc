// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "./Interface.sol";

contract NFTV1 is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable
{
    uint public VERSION;

    string public baseURL0;
    string public baseURL1;

    address public ADDRESS_POOL;
    address public ADDRESS_NFTREWARD;

    struct NFTData {
        uint256 id;
        uint256 createdAt;
        uint256 basePower;
        uint256 extraPower;
    }

    NFTData[] nftList;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol
    ) public initializer {
        __ERC721_init(name, symbol);
        __ERC721Enumerable_init();
        __Ownable_init();
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    receive() external payable {}

    fallback() external payable {}

    function setURL(string memory url0, string memory url1) public onlyOwner {
        baseURL0 = url0;
        baseURL1 = url1;
    }

    function tokenURI(
        uint256 nftId
    ) public view override returns (string memory) {
        string memory tokenId = StringsUpgradeable.toString(nftId);
        return string(abi.encodePacked(baseURL0, tokenId, baseURL1));
    }

    function setup(address addrPool, address addrNR) public onlyOwner {
        require(VERSION == 0);
        VERSION = 1;
        ADDRESS_POOL = addrPool;
        ADDRESS_NFTREWARD = addrNR;
        nftList.push(NFTData(0, 0, 0, 0));
    }

    function mint(address receiver) public payable {
        uint amountCoin = 1e18;
        if (msg.sender != owner()) amountCoin = msg.value;
        require(amountCoin == 1e18, "price requirement fail");
        require(nftList.length <= 3333, "maximum 3333 nft");

        transferBalance();

        uint256 nftId = nftList.length;
        nftList.push(NFTData(nftId, block.timestamp, amountCoin, 0));
        _mint(receiver, nftId);
        INFTReward(ADDRESS_NFTREWARD).setBase(nftId, amountCoin);
    }

    function powerUp(uint nftId) public payable {
        uint amountCoin = msg.value;
        require(amountCoin >= 1e18, "minimum is 1 coin");
        require(nftId > 0 && nftId <= nftList.length, "out of index");

        transferBalance();

        uint newExtraPower = nftList[nftId].extraPower + amountCoin;
        nftList[nftId].extraPower = newExtraPower;
        INFTReward(ADDRESS_NFTREWARD).setExtra(nftId, newExtraPower);
    }

    function transferBalance() private {
        uint balance = payable(address(this)).balance;
        (bool success, ) = ADDRESS_POOL.call{value: balance}("");
        require(success, "failed to send");
    }

    function getData()
        public
        view
        returns (uint, uint, uint, uint, uint, uint)
    {
        return (VERSION, nftList.length, 0, 0, 0, 0);
    }

    function getNFTData(
        uint index
    ) public view returns (uint, uint, uint, uint) {
        return (
            nftList[index].id,
            nftList[index].createdAt,
            nftList[index].basePower,
            nftList[index].extraPower
        );
    }
}
