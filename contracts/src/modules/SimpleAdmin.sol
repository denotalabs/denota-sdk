// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;

import "openzeppelin/security/Pausable.sol";
import {ModuleBase} from "../ModuleBase.sol";
import {Nota, WTFCFees} from "../libraries/DataTypes.sol";
import {INotaModule} from "../interfaces/INotaModule.sol";
import {INotaRegistrar} from "../interfaces/INotaRegistrar.sol";

/// @notice allows the module owner to pause functionalities
abstract contract SimpleAdmin is Pausable, ModuleBase {

}

/// @notice allows the nota creator to set an admin that can pause WTFC for that particular nota
abstract contract SetAdmin is ModuleBase {

}
