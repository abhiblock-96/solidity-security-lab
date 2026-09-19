// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BaseContract} from "test/fixed/Reentrancy/BaseContract.t.sol";
import {ClassicReentrancyFixedVault} from "src/fixed/Reentrancy/ClassicReentrancyFixed.sol";
import {CrossFunctionFixedVault} from "src/fixed/Reentrancy/Cross-FunctionReentrancyFixed.sol";
import {CrossContractFixedVault} from "src/fixed/Reentrancy/Cross-ContractReentrancyFixed.sol";

/// @title ReentrancyMitigationTest
/// @notice Tests that the fixed vault implementations prevent different
///         forms of reentrancy attacks.
/// @dev Verifies classic, cross-function, and cross-contract reentrancy
///      mitigations using attacker contracts.
contract ReentrancyMitigationTest is BaseContract {
    /// @notice Verifies that classic reentrancy cannot drain funds from the vault.
    /// @dev The attack must revert and the attacker's recorded balance must
    ///      remain unchanged.
    function test_classicReentrancy_isMitigated() external {
        vm.prank(user1);
        classicFixedVault.deposit{value: 5 ether}();

        vm.prank(user2);
        classicFixedVault.deposit{value: 9 ether}();

        vm.prank(attacker);
        fixedAttacker.deposit{value: 1 ether}();

        uint256 initialVaultBalance = address(classicFixedVault).balance;

        assertEq(initialVaultBalance, 15 ether);

        assertEq(classicFixedVault.balanceOf(address(fixedAttacker)), 1 ether);

        assertEq(address(fixedAttacker).balance, 0);

        vm.prank(attacker);
        vm.expectRevert(ClassicReentrancyFixedVault.WithdrawFailed.selector);
        fixedAttacker.attack();
    }

    /// @notice Verifies that cross-function reentrancy cannot exploit shared
    ///         balance accounting.
    /// @dev The attack must revert and the attacker's recorded vault balance
    ///      must remain unchanged.
    function test_crossFunctionReentrancy_isMitigated() external {
        vm.prank(user1);
        crossFunctionFixedVault.deposit{value: 5 ether}();

        vm.prank(user2);
        crossFunctionFixedVault.deposit{value: 9 ether}();

        vm.prank(attacker);
        crossFunctionFixedAttacker.deposit{value: 1 ether}();

        uint256 initialAttackerBalance = crossFunctionFixedVault.balanceOf(address(crossFunctionFixedAttacker));

        uint256 attackerContractBalanceBefore = address(crossFunctionFixedAttacker).balance;

        assertEq(initialAttackerBalance, 1 ether);
        assertEq(attackerContractBalanceBefore, 0);

        vm.prank(attacker);
        vm.expectRevert(CrossFunctionFixedVault.WithdrawFailed.selector);
        crossFunctionFixedAttacker.attack();

        uint256 attackerBalance = crossFunctionFixedVault.balanceOf(address(crossFunctionFixedAttacker));
        assertEq(attackerBalance, 1 ether);
    }

    /// @notice Verifies that cross-contract reentrancy cannot manipulate
    ///         token balances.
    /// @dev The attack must not result in unauthorized token extraction from
    ///      the vault or the attacker's account.
    function test_crossContractReentrancy_isMitigated() external {
        vm.prank(user1);
        crossContractFixedVault.deposit{value: 8 ether}();

        vm.prank(user2);
        crossContractFixedVault.deposit{value: 5 ether}();

        vm.prank(attacker);
        crossContractAttacker.deposit{value: 1 ether}();

        uint256 initialVaultBalance = address(crossContractFixedVault).balance;

        uint256 attackerContractInitialToken = token.balanceOf(address(crossContractAttacker));

        address attacker = crossContractAttacker.attacker();
        uint256 attackerInitialToken = token.balanceOf(attacker);

        assertEq(initialVaultBalance, 14 ether);
        assertEq(attackerContractInitialToken, 1e18);
        assertEq(attackerInitialToken, 0);

        vm.prank(attacker);
        crossContractAttacker.attack();

        uint256 attackerContractTokenBalance = token.balanceOf(address(crossContractAttacker));
        assertEq(attackerContractTokenBalance, 0);

        uint256 attackerBalance = token.balanceOf(attacker);
        assertEq(attackerBalance, 0);
    }
}
