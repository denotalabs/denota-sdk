// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;

import {ModuleBase} from "../ModuleBase.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {INotaRegistrar} from "../interfaces/INotaRegistrar.sol";
import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract Coverage is Ownable, ModuleBase {
    using SafeERC20 for IERC20;

    struct CoverageInfo {
        uint256 coverageAmount; // Face value of the payment
        address coverageHolder;
        bool wasRedeemed;
    }

    mapping(uint256 => CoverageInfo) public coverageInfo;
    mapping(address => bool) public isWhitelisted;

    address public usdc;

    constructor(
        address registrar,
        DataTypes.WTFCFees memory _fees,
        string memory __baseURI,
        address _usdc
    ) ModuleBase(registrar, _fees) {
        _URI = __baseURI;
        usdc = _usdc;
    }

    // Admin can add an address to the whitelist
    function addToWhitelist(address _address) external onlyOwner {
        isWhitelisted[_address] = true;
    }

    // Admin can remove an address from the whitelist
    function removeFromWhitelist(address _address) external onlyOwner {
        isWhitelisted[_address] = false;
    }

    function fundPool(uint256 fundingAmount) public {
        IERC20(usdc).safeTransferFrom(_msgSender(), address(this), fundingAmount);

        // LPs receive pool tokens in return
        // TODO: figure out token issuance and redemption
    }

    function processWrite(
        address caller,
        address _owner,
        uint256 notaId,
        address currency,
        uint256 /*escrowed*/,
        uint256 instant,
        bytes calldata initData
    ) public override onlyRegistrar returns (uint256) {
        require(isWhitelisted[caller], "Not whitelisted");

        (address holder, uint256 amount, uint256 riskScore) = abi.decode(
            initData,
            (address, uint256, uint256)
        );

        require(instant == (amount / 10000) * riskScore, "Risk fee not paid");
        // TODO: maybe onramp should own nota? (currently the registrar assumes that the owner is the one being paid)
        require(_owner == address(this), "Risk fee not paid to pool");
        require(currency == usdc, "Incorrect currency");

        coverageInfo[notaId].coverageHolder = holder;
        coverageInfo[notaId].coverageAmount = amount;
        coverageInfo[notaId].wasRedeemed = false;
        return 0;
    }

    function recoverFunds(uint256 notaId) public {
        CoverageInfo storage coverage = coverageInfo[notaId];

        require(!coverage.wasRedeemed);
        require(_msgSender() == coverage.coverageHolder);

        // MVP: just send funds to the holder (doesn't scale but makes the demo easier)
        IERC20(usdc).safeTransfer(
            coverage.coverageHolder,
            coverage.coverageAmount
        );

        coverage.wasRedeemed = true;
    }

    function processTransfer(
        address caller,
        address approved,
        address owner,
        address /*from*/,
        address /*to*/,
        uint256 /*notaId*/,
        address currency,
        uint256 escrowed,
        uint256 /*createdAt*/,
        bytes memory data
    ) public override onlyRegistrar returns (uint256) {
        return 0;
    }

    function processFund(
        address /*caller*/,
        address owner,
        uint256 amount,
        uint256 instant,
        uint256 notaId,
        DataTypes.Nota calldata nota,
        bytes calldata initData
    ) public override onlyRegistrar returns (uint256) {
        return 0;
    }

    function processCash(
        address /*caller*/,
        address /*owner*/,
        address /*to*/,
        uint256 /*amount*/,
        uint256 /*notaId*/,
        DataTypes.Nota calldata /*nota*/,
        bytes calldata /*initData*/
    ) public view override onlyRegistrar returns (uint256) {
        return 0;
    }

    function processApproval(
        address caller,
        address owner,
        address /*to*/,
        uint256 /*notaId*/,
        DataTypes.Nota calldata /*nota*/,
        bytes memory /*initData*/
    ) public view override onlyRegistrar {
        // if (caller != owner) revert;
    }

    function processTokenURI(
        uint256 tokenId
    ) external view override returns (string memory) {
        return "";
    }
}
