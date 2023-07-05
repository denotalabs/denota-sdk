// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;

import {OperatorFeeModuleBase} from "../ModuleBase.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {INotaModule} from "../interfaces/INotaModule.sol";
import {INotaRegistrar} from "../interfaces/INotaRegistrar.sol";

/**
 * @notice A simple time release module. The longer the release time, the more in fees you have to pay
 * Escrowed tokens are cashable after the releaseDate
 * Question: Allow nota creator to update the URI?
 */
contract SimpleTimelockFee is OperatorFeeModuleBase {
    mapping(uint256 => uint256) public releaseDate;
    event Timelock(uint256 notaId, uint256 _releaseDate);

    constructor(
        address registrar,
        DataTypes.WTFCFees memory _fees,
        string memory __baseURI
    ) OperatorFeeModuleBase(registrar, _fees) {
        _URI = __baseURI;
    }

    function processWrite(
        address /*caller*/,
        address /*owner*/,
        uint256 notaId,
        address currency,
        uint256 escrowed,
        uint256 instant,
        bytes calldata initData
    ) external override onlyRegistrar returns (uint256) {
        (uint256 _releaseDate, address dappOperator) = abi.decode(
            initData,
            (uint256, address)
        ); // Frontend uploads (encrypted) memo document and the URI is linked to notaId here (URI and content hash are set as the same)
        releaseDate[notaId] = _releaseDate;
        emit Timelock(notaId, _releaseDate);
        return takeReturnFee(currency, escrowed + instant, dappOperator, 0);
    }

    function processTransfer(
        address caller,
        address approved,
        address owner,
        address /*from*/,
        address /*to*/,
        uint256 /*notaId*/,
        DataTypes.Nota calldata nota,
        bytes memory data
    ) external override onlyRegistrar returns (uint256) {
        require(caller == owner || caller == approved, "Not owner or approved");
        return
            takeReturnFee(nota.currency, nota.escrowed, abi.decode(data, (address)), 1);
    }

    function processFund(
        address /*caller*/,
        address /*owner*/,
        uint256 /*amount*/,
        uint256 /*instant*/,
        uint256 /*notaId*/,
        DataTypes.Nota calldata /*nota*/,
        bytes calldata /*initData*/
    ) external view override onlyRegistrar returns (uint256) {
        require(false, "Only sending and cashing");
        return 0;
    }

    function processCash(
        address /*caller*/,
        address /*owner*/,
        address /*to*/,
        uint256 amount,
        uint256 /*notaId*/,
        DataTypes.Nota calldata nota,
        bytes calldata initData
    ) external override onlyRegistrar returns (uint256) {
        require(amount == nota.escrowed, "Must fully cash");
        return
            takeReturnFee(
                nota.currency,
                amount,
                abi.decode(initData, (address)),
                3
            );
    }

    function processApproval(
        address caller,
        address owner,
        address /*to*/,
        uint256 /*notaId*/,
        DataTypes.Nota calldata /*nota*/,
        bytes memory /*initData*/
    ) external view override onlyRegistrar {
        require(caller == owner, "Only owner can approve");
    }

    function processTokenURI(
        uint256 tokenId
    ) external view override returns (string memory, string memory) {
        return ("", string(abi.encodePacked(_URI, tokenId)));
    }
}
