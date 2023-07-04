// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.2) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "openzeppelin-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "openzeppelin-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "openzeppelin-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import "openzeppelin-upgradeable/utils/AddressUpgradeable.sol";
import "openzeppelin-upgradeable/utils/ContextUpgradeable.sol";
import "openzeppelin-upgradeable/utils/StringsUpgradeable.sol";
import "openzeppelin-upgradeable/utils/introspection/ERC165Upgradeable.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 *
 * @custom:denota remove operators, remove approval owner/operator check, remove _before/_after hooks from mint/transfer/burn. Changed requires to reverts
 */
contract ERC721Upgradeable is ContextUpgradeable, ERC165Upgradeable, IERC721Upgradeable, IERC721MetadataUpgradeable {
    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;

    // Token name
    string private _name;
    // Token symbol
    string private _symbol;
    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;
    // Mapping owner address to token count
    mapping(address => uint256) private _balances;
    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // // Mapping from owner to operator approvals
    // mapping(address => mapping(address => bool)) private _operatorApprovals;  // Changed: removed
    error NotMinted();
    error Disallowed();
    error AddressZero();
    error SelfApproval();
    error AlreadyMinted();
    error NonERC721Receiver();

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __ERC721_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC721_init_unchained(name_, symbol_);
    }

    function __ERC721_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC721Upgradeable).interfaceId ||
            interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(
        address owner
    ) public view virtual override returns (uint256) {
        if (owner == address(0)) revert AddressZero();
        // require( // Changed: removed
        //     owner != address(0),
        //     "ERC721: address zero is not a valid owner"
        // );
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     * @custom:alex why shouldn't address(0) be shown as the owner? Maybe will show non-minted as having an owner?
     */
    function ownerOf(
        uint256 tokenId
    ) public view virtual override returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) revert AddressZero();
        // require(owner != address(0), "ERC721: invalid token ID"); // Changed: removed
        return owner;
        // return _ownerOf(tokenId);  // Changed
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        // require(to != owner, "ERC721: approval to current owner");  // Changed: removed
        if (to == owner) revert SelfApproval();

        // require( // Changed: removed
        //     _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
        //     "ERC721: approve caller is not token owner or approved for all"
        // );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(
        uint256 tokenId
    ) public view virtual override returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    // /**
    //  * @dev See {IERC721-setApprovalForAll}.
    //  */
    function setApprovalForAll(
        address /*operator*/,
        bool /*approved*/
    ) public virtual override {
        revert Disallowed(); // Question: Does OS require operators?
        //     _setApprovalForAll(_msgSender(), operator, approved); // Changed: removed
    }

    // /**
    //  * @dev See {IERC721-isApprovedForAll}.
    //  */
    function isApprovedForAll(
        address /*owner*/,
        address /*operator*/
    ) public view virtual override returns (bool) {
        /// @custom:alex should this revert instead?
        //     return _operatorApprovals[owner][operator]; // Changed: removed
        return false;
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        // require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved"); // Changed: removed
        // _transfer(from, to, tokenId);
        revert();
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        // require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");  // Changed: removed
        // _safeTransfer(from, to, tokenId, data);
        revert();
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        if (!_checkOnERC721Received(from, to, tokenId, data))
            revert NonERC721Receiver();
        // require(  // Changed: to revert
        //     _checkOnERC721Received(from, to, tokenId, data),
        //     "ERC721: transfer to non ERC721Receiver implementer"
        // );
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        // Changed: removed the beforeTokenTransfer hook and check, and afterTokenTransfer hook
        require(
            ERC721Upgradeable.ownerOf(tokenId) == from,
            "ERC721: transfer from incorrect owner"
        );
        require(to != address(0), "ERC721: transfer to the zero address");

        // _beforeTokenTransfer(from, to, tokenId, 1);

        // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
        // require(
        //     ERC721.ownerOf(tokenId) == from,
        //     "ERC721: transfer from incorrect owner"
        // );

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId];

        unchecked {
            // `_balances[from]` cannot overflow for the same reason as described in `_burn`:
            // `from`'s balance is the number of token held, which is at least one before the current
            // transfer.
            // `_balances[to]` could overflow in the conditions described in `_mint`. That would require
            // all 2**256 token ids to be minted, which in practice is impossible.
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        // _afterTokenTransfer(from, to, tokenId, 1);
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    // /**
    //  * @dev Returns whether `spender` is allowed to manage `tokenId`.
    //  *
    //  * Requirements:
    //  *
    //  * - `tokenId` must exist.
    //  */
    // function _isApprovedOrOwner(
    //     address spender,
    //     uint256 tokenId
    // ) internal view virtual returns (bool) {
    //     address owner = ERC721.ownerOf(tokenId);
    //     return (spender == owner ||
    //         isApprovedForAll(owner, spender) ||
    //         getApproved(tokenId) == spender);
    // }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        if (!_checkOnERC721Received(address(0), to, tokenId, data))
            revert NonERC721Receiver();
        // require(  // Changed: to revert
        //     _checkOnERC721Received(address(0), to, tokenId, data),
        //     "ERC721: transfer to non ERC721Receiver implementer"
        // );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        //require(to != address(0), "ERC721: mint to the zero address");  // Changed: removed check
        //require(!_exists(tokenId), "ERC721: token already minted");  // Changed: to revert
        if (_exists(tokenId)) revert AlreadyMinted();

        // _beforeTokenTransfer(address(0), to, tokenId, 1);  // Changed: removed pre-hook

        // Check that tokenId was not minted by `_beforeTokenTransfer` hook
        // require(!_exists(tokenId), "ERC721: token already minted");  // Changed: removed pre-hook check

        unchecked {
            // Will not overflow unless all 2**256 token ids are minted to the same owner.
            // Given that tokens are minted one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch minting.
            // The ERC fails to describe this case.
            _balances[to] += 1;
        }

        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        // _afterTokenTransfer(address(0), to, tokenId, 1);  // Changed: removed post-hook
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721Upgradeable.ownerOf(tokenId);

        // _beforeTokenTransfer(owner, address(0), tokenId, 1);  // Changed: removed

        // // Update ownership in case tokenId was transferred by `_beforeTokenTransfer` hook
        // owner = ERC721.ownerOf(tokenId);  // Changed: removed

        // Clear approvals
        delete _tokenApprovals[tokenId];

        unchecked {
            // Cannot overflow, as that would require more tokens to be burned/transferred
            // out than the owner initially received through minting and transferring in.
            _balances[owner] -= 1;
        }
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        // _afterTokenTransfer(owner, address(0), tokenId, 1);  // Changed: removed
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721Upgradeable.ownerOf(tokenId), to, tokenId);
    }

    // /**
    //  * @dev Approve `operator` to operate on all of `owner` tokens
    //  *
    //  * Emits an {ApprovalForAll} event.
    //  */
    // function _setApprovalForAll(  // Changed: removed completely
    //     address owner,
    //     address operator,
    //     bool approved
    // ) internal virtual {
    //     require(owner != operator, "ERC721: approve to caller");
    //     _operatorApprovals[owner][operator] = approved;
    //     emit ApprovalForAll(owner, operator, approved);
    // }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        if (!_exists(tokenId)) revert NotMinted(); // Changed: to revert
        // require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try
                IERC721ReceiverUpgradeable(to).onERC721Received(
                    _msgSender(),
                    from,
                    tokenId,
                    data
                )
            returns (bytes4 retval) {
                return retval == IERC721ReceiverUpgradeable.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    // /**
    //  * @dev Hook that is called before any token transfer. This includes minting and burning. If {ERC721Consecutive} is
    //  * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
    //  *
    //  * Calling conditions:
    //  *
    //  * - When `from` and `to` are both non-zero, ``from``'s tokens will be transferred to `to`.
    //  * - When `from` is zero, the tokens will be minted for `to`.
    //  * - When `to` is zero, ``from``'s tokens will be burned.
    //  * - `from` and `to` are never both zero.
    //  * - `batchSize` is non-zero.
    //  *
    //  * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
    //  */
    // function _beforeTokenTransfer(  // Changed: removed completely
    //     address from,
    //     address to,
    //     uint256 firstTokenId,
    //     uint256 batchSize
    // ) internal virtual {}

    // /**
    //  * @dev Hook that is called after any token transfer. This includes minting and burning. If {ERC721Consecutive} is
    //  * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
    //  *
    //  * Calling conditions:
    //  *
    //  * - When `from` and `to` are both non-zero, ``from``'s tokens were transferred to `to`.
    //  * - When `from` is zero, the tokens were minted for `to`.
    //  * - When `to` is zero, ``from``'s tokens were burned.
    //  * - `from` and `to` are never both zero.
    //  * - `batchSize` is non-zero.
    //  *
    //  * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
    //  */
    // function _afterTokenTransfer(  // Changed: removed completely
    //     address from,
    //     address to,
    //     uint256 firstTokenId,
    //     uint256 batchSize
    // ) internal virtual {}

    // /**
    //  * @dev Unsafe write access to the balances, used by extensions that "mint" tokens using an {ownerOf} override.
    //  *
    //  * WARNING: Anyone calling this MUST ensure that the balances remain consistent with the ownership. The invariant
    //  * being that for any address `a` the value returned by `balanceOf(a)` must be equal to the number of tokens such
    //  * that `ownerOf(tokenId)` is `a`.
    //  */
    // // solhint-disable-next-line func-name-mixedcase
    // function __unsafe_increaseBalance(  // Changed: removed completely
    //     address account,
    //     uint256 amount
    // ) internal {
    //     _balances[account] += amount;
    // }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[44] private __gap;
}
