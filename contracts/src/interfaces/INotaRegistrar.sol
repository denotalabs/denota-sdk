// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;
import "openzeppelin/token/ERC20/IERC20.sol";
import {IHooks} from "../interfaces/IHooks.sol";

/**
 * @notice NotaRegistrar handles: Escrowing funds, and Storing nota data
 * @title  The Nota Registrar
 * @notice The main contract where users can WTFCA notas
 * @author Alejandro Almaraz
 * @dev    Tracks ownership of notas' data + escrow, and collects revenue.
 */
interface INotaRegistrar {
    struct Nota {
        uint256 escrowed; // Slot1
        address currency; // Slot2
        /* 96 bits free */
        IHooks hooks; // Slot3
        /* 96 bits free */
    }

    event Written (
        address indexed writer,
        uint256 indexed notaId,
        address currency,
        uint256 escrowed,
        IHooks indexed hook,
        uint256 instant,
        uint256 hookFee,
        bytes hookData
    );
    event Transferred(
        address indexed transferer,
        uint256 indexed notaId,
        uint256 hookFee,
        bytes hookData
    );
    event Funded(
        address indexed funder,
        uint256 indexed notaId,
        uint256 amount,
        uint256 instant,
        uint256 hookFee,
        bytes hookData
    );
    event Cashed(
        address indexed casher,
        uint256 indexed notaId,
        address indexed to,
        uint256 amount,
        uint256 hookFee,
        bytes hookData
    );
    event Approved(
        address indexed approver,
        uint256 indexed notaId,
        uint256 hookFee
    );

    error NonExistent();
    error InvalidWrite(IHooks, address);

    /**
     * @notice Mints a Nota and transfers tokens
     * @dev Requires hook & currency whitelisted and `owner` != address(0). Transfers instant/escrow tokens from msg.sender, sends instant tokens to `owner`
     */
    function write(
        address currency,
        uint256 escrowed,
        uint256 instant,
        address owner,
        IHooks hook,
        bytes calldata hookData
    ) external payable returns (uint256);

    /**
     * @notice Transfers a Nota
     * @dev Enforces the transfer requirements (isApprovedOrOwner) before transferHook is called
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Enforces the transfer requirements (isApprovedOrOwner) before transferHook is called
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory hookData
    ) external;

    /**
     * @notice Adds to the escrowed amount of a Nota
     * @dev No requirements except what the hook enforces
     */
    function fund(
        uint256 notaId,
        uint256 amount,
        uint256 instant,
        bytes calldata hookData
    ) external payable;

    /**
     * @notice Removes from the escrowed amount of a Nota
     * @dev No requirements except what the hook enforces
     */
    function cash(
        uint256 notaId,
        uint256 amount,
        address to,
        bytes calldata hookData
    ) external payable;

    /**
     * @notice Approves a Nota for transfer
     * @dev Caller must be the owner of the Nota or operator for the owner
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @notice Burns the Nota's ownership, deletes notaInfo, and moves remaining escrowed funds to the hook's revenue
     * @dev Caller must be approved or the owner of the Nota
     */
    function burn(uint256 notaId) external;

    /**
     * @notice Updates the metadata of a Nota
     * @dev Caller must be the Nota's hook
     */
    function metadataUpdate(uint256 notaId) external;

    function notaInfo(uint256 notaId) external view returns (Nota memory);
    
    function notaCurrency(uint256 notaId) external view returns (address);

    function notaEscrowed(uint256 notaId) external view returns (uint256);

    function notaHook(uint256 notaId) external view returns (IHooks);
}
