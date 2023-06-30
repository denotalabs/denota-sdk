// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;
import {DataTypes} from "../libraries/DataTypes.sol";

// Question: Should the require statements be part of the interface? Would allow people to query canWrite(), canCash(), etc
// Question: Should module return their fee in BPS or actual fee amount?
interface INotaModule {
    function processWrite(
        address caller,
        address owner,
        uint256 notaId,
        address currency,
        uint256 escrowed,
        uint256 instant,
        bytes calldata initData
    ) external returns (uint256);

    /// TODO change to struct
    function processTransfer(
        address caller,
        address approved,
        address owner,
        address from,
        address to,
        uint256 notaId,
        DataTypes.Nota calldata nota,
        bytes calldata data
    ) external returns (uint256);

    function processFund(
        address caller,
        address owner,
        uint256 amount,
        uint256 instant,
        uint256 notaId,
        DataTypes.Nota calldata nota,
        bytes calldata initData
    ) external returns (uint256);

    function processCash(
        address caller,
        address owner,
        address to,
        uint256 amount,
        uint256 notaId,
        DataTypes.Nota calldata nota,
        bytes calldata initData
    ) external returns (uint256);

    function processApproval(
        address caller,
        address owner,
        address to,
        uint256 notaId,
        DataTypes.Nota calldata nota,
        bytes memory initData
    ) external;

    // function processOwnerOf(address owner, uint256 tokenId) external view returns(bool); // TODO settle on what this returns
    // function processBalanceOf() external view returns(uint256);
    function processTokenURI(
        uint256 tokenId
    ) external view returns (string memory, string memory);
}