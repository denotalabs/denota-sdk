// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;
import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IRegistrarGov} from "./interfaces/IRegistrarGov.sol";
import {INotaModule} from "./interfaces/INotaModule.sol";

// Idea Registrar could take different fees from different modules. Business related ones would be charged but not social ones?
contract RegistrarGov is Ownable, IRegistrarGov {
    using SafeERC20 for IERC20;
    mapping(INotaModule => mapping(address => uint256)) internal _moduleRevenue; // Could collapse this into a single mapping
    mapping(address => bool) internal _addressWhitelist;
    mapping(address => bool) internal _tokenWhitelist;

    function whitelistModule(
        address module,
        bool addressAccepted
    ) external onlyOwner {
        _addressWhitelist[module] = addressAccepted;

        emit ModuleWhitelisted(
            _msgSender(),
            module,
            addressAccepted,
            block.timestamp
        );
    }

    function whitelistToken(
        address _token,
        bool accepted
    ) external onlyOwner {
        // Whitelist for safety, modules can be more restrictive
        _tokenWhitelist[_token] = accepted;
        emit TokenWhitelisted(
            _msgSender(),
            _token,
            accepted,
            block.timestamp
        );
    }

    function validModule(address module) public view returns (bool) {
        return
            _addressWhitelist[module];
    }

    function tokenWhitelisted(address token) public view returns (bool) {
        return _tokenWhitelist[token];
    }

    function validWrite(
        address module,
        address token
    ) public view returns (bool) {
        return validModule(module) && tokenWhitelisted(token); // Valid module and whitelisted currency
    }

    function moduleWhitelisted(
        address module
    ) public view returns (bool) {
        return (
            _addressWhitelist[module]
        );
    }
}
