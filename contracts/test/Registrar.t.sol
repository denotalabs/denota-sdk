// // SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./mock/erc20.sol";
import {NotaRegistrar} from "../src/NotaRegistrar.sol";
import {INotaModule} from "../src/interfaces/INotaModule.sol";
import {Nota, WTFCFees} from "../src/libraries/DataTypes.sol";

// TODO ensure failure on 0 escrow but moduleFee (or should module handle that??)
contract RegistrarTest is Test {
    NotaRegistrar public REGISTRAR;
    TestERC20 public DAI;
    TestERC20 public USDC;
    uint256 public immutable TOKENS_CREATED = 1_000_000_000_000e18;

    function setUp() public virtual {
        REGISTRAR = new NotaRegistrar(); 
        DAI = new TestERC20(TOKENS_CREATED, "DAI", "DAI"); 
        USDC = new TestERC20(0, "USDC", "USDC");  // TODO necessary?

        vm.label(msg.sender, "Alice");
        vm.label(address(this), "TestingContract");
        vm.label(address(DAI), "TestDai");
        vm.label(address(USDC), "TestUSDC");
        vm.label(address(REGISTRAR), "NotaRegistrarContract");
    }

    function isContract(address _addr) public view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function safeFeeMult(
        uint256 fee,
        uint256 amount
    ) public pure returns (uint256) {
        if (fee == 0) return 0;
        return (amount * fee) / 10_000;
    }

    function _calcTotalFees(
        INotaModule module,
        uint256 escrowed,
        uint256 instant
    ) internal view returns (uint256) {
        // WTFCFees memory fees = module.getFees(address(0));
        uint256 totalTransfer = instant + escrowed;
        
        uint256 moduleFee = 0; //safeFeeMult(fees.writeBPS, totalTransfer);
        console.log("Module Fee: ", moduleFee);
        uint256 totalWithFees = totalTransfer + moduleFee;
        console.log(totalTransfer, "-->", totalWithFees);
        return totalWithFees;
    }

    function _tokenFundAddressApproveAddress(address caller, TestERC20 token, uint256 escrowed, uint256 instant, INotaModule module, address _toApprove) internal {
        uint256 totalWithFees = _calcTotalFees(  // TODO should this be moved outside of this func?
            module,
            escrowed,
            instant
        );
        
        assertEq(token.balanceOf(caller), 0, "Token Transfer already happened");
        // Give caller enough tokens
        token.transfer(caller, totalWithFees);
        assertEq(token.balanceOf(caller), totalWithFees, "Token Transfer Failed");

        // Caller gives registrar approval
        assertEq(token.allowance(caller, _toApprove), 0);
        vm.prank(caller);
        token.approve(_toApprove, totalWithFees); // Need to get the fee amounts beforehand
        assertEq(token.allowance(caller, _toApprove), totalWithFees);
    }

    function _registrarTokenWhitelistHelper(address token) internal {
        assertFalse(
            REGISTRAR.tokenWhitelisted(token),
            "Already Whitelisted"
        );

        REGISTRAR.whitelistToken(token, true);
        
        assertTrue(
            REGISTRAR.tokenWhitelisted(token),
            "Whitelisting failed"
        );
    }

    function testWhitelistToken() public {
        // Add whitelist
         _registrarTokenWhitelistHelper(address(DAI));
        
        // Remove whitelist
        REGISTRAR.whitelistToken(address(DAI), false);
        assertFalse(
            REGISTRAR.tokenWhitelisted(address(DAI)),
            "Un-whitelisting failed"
        );
    }
   
   function _registrarModuleWhitelistHelper(INotaModule module, bool _address) internal {
        bool addressWhitelist = REGISTRAR.moduleWhitelisted(module);
        assertFalse(addressWhitelist, "Already Whitelisted");

        REGISTRAR.whitelistModule(module, _address);

        addressWhitelist = REGISTRAR.moduleWhitelisted(module);
        assertTrue(addressWhitelist, "Address Not Whitelisted");
    }

    function testWhitelistModule() public {
        // TODO
    }

    function registrarWriteBefore(address caller, address recipient) public {
        assertEq(
            REGISTRAR.balanceOf(caller), 0,
            "Caller already had a nota"
        );
        assertEq(
            REGISTRAR.balanceOf(recipient), 0,
            "Recipient already had a nota"
        );
        assertEq(REGISTRAR.totalSupply(), 0, "Nota supply non-zero");
    }
    
    function registrarWriteAfter(
        uint256 notaId,
        address currency,
        uint256 escrowed,
        address owner,
        INotaModule module
    ) public {
        assertEq(
            REGISTRAR.totalSupply(), 1,
            "Nota supply didn't increment"
        );

        assertEq(
            REGISTRAR.balanceOf(owner), 1,
            "Owner balance didn't increment"
        );

        assertEq(
            REGISTRAR.ownerOf(notaId), owner,
            "`owner` isn't owner of nota"
        );

        assertEq(
            REGISTRAR.notaCurrency(notaId), currency,
            "Incorrect token"
        );

        assertEq(
            REGISTRAR.notaEscrowed(notaId), escrowed,
            "Incorrect escrow"
        );

        assertEq(
            address(REGISTRAR.notaModule(notaId)), address(module),
            "Incorrect module"
        );
    }

    function _registrarWriteHelper(        
        address caller,
        address currency,
        uint256 escrowed,
        uint256 instant,
        address owner,
        INotaModule module,
        bytes memory moduleWriteData) internal returns(uint256 notaId) {

        registrarWriteBefore(caller, owner);
        vm.prank(caller);
        notaId = REGISTRAR.write(
            currency,
            escrowed,
            instant,
            owner,
            module,
            moduleWriteData
        ); 
        registrarWriteAfter(
            notaId,
            currency,
            escrowed,
            owner,
            module
        );
    }

    function registrarTransferBefore(address from, address to, uint256 notaId) public {}

    function registrarTransferAfter(address from, address to, uint256 notaId) public {}

    function _registrarTransferHelper(address from, address to, uint256 notaId) internal {}

    function registrarFundBefore(uint256 notaId, uint256 amount, uint256 instant) public {}

    function registrarFundAfter(uint256 notaId, uint256 amount, uint256 instant) public {}

    function registrarCashBefore(uint256 notaId, uint256 amount, address to) public {}

    function registrarCashAfter(uint256 notaId, uint256 amount, address to) public {}
    
}