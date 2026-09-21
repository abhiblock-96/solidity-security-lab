// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BaseContract} from "test/fixed/Access-Control/BaseContract.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AccessControlFixed
 * @notice Tests the mitigated versions of the access-control vulnerabilities.
 *
 * @dev
 * This test contract verifies two different authorization models:
 *
 * 1. Role-based access control:
 *    - The vault is granted `SHOP_ROLE`.
 *    - The vault can mint and burn tokens through authorized operations.
 *    - Unauthorized accounts cannot perform privileged token operations.
 *
 * 2. Ownership-based access control:
 *    - Only the owner can transfer ownership.
 *    - Unauthorized accounts cannot withdraw funds through owner-restricted
 *      functionality.
 */
contract AccessControlFixed is BaseContract {
    /**
     * @notice Verifies that unauthorized accounts cannot perform
     *         role-restricted token operations.
     *
     * @dev
     * The test first grants `SHOP_ROLE` to the vault.
     *
     * Legitimate users can then:
     * - Buy tokens through the vault.
     * - Sell tokens through the vault.
     *
     * The attacker attempts to:
     * - Mint tokens through the attacker contract.
     * - Burn tokens belonging to another user.
     *
     * Both operations must revert because the caller does not possess
     * the required `SHOP_ROLE`.
     */
    function test_roleBasedAccessControl_RevertsUnauthorizedCalls() external {
        // Grant SHOP_ROLE to the vault so it can perform
        // authorized token minting and burning.
        vm.prank(admin);
        token.grantShopRole(address(roleBasedVault));

        vm.prank(user1);
        roleBasedVault.buyToken{value: 1 ether}();

        vm.startPrank(user2);
        roleBasedVault.buyToken{value: 3 ether}();
        roleBasedVault.sellToken(1e18);
        vm.stopPrank();

        assertEq(address(roleBasedVault).balance, 3e18);

        bytes32 role = token.SHOP_ROLE();

        // ---------------------------------------------------------------
        // Unauthorized minting attempt.
        //
        // The attacker contract does not have SHOP_ROLE, so the
        // token contract must reject the privileged operation.
        // ---------------------------------------------------------------

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(roleBasedAttacker), role
            )
        );

        roleBasedAttacker.attack(5e18);

        // ---------------------------------------------------------------
        // Unauthorized burning attempt.
        //
        // The attacker does not have SHOP_ROLE and therefore cannot
        // burn tokens belonging to another account.
        // ---------------------------------------------------------------

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, attacker, role)
        );

        token.burn(user2, 2e18);
    }

    /**
     * @notice Verifies that unauthorized accounts cannot perform
     *         owner-restricted vault operations.
     *
     * @dev
     * The vault is funded by legitimate users before the attacker
     * attempts to exploit the previously vulnerable functions.
     *
     * The attacker attempts to:
     *
     * 1. Transfer ownership to itself.
     * 2. Withdraw the vault funds through the attacker contract.
     *
     * Both operations must revert because the attacker is not the owner.
     */
    function test_ownershipAccessControl_RevertsUnauthorizedCalls() external {
        _deposit(user1, 3 ether);
        _deposit(user2, 5 ether);

        assertEq(address(accessControlVault).balance, 8 ether);

        // ---------------------------------------------------------------
        // Unauthorized ownership transfer.
        // ---------------------------------------------------------------

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));

        accessControlVault.transferOwnership(attacker);

        // ---------------------------------------------------------------
        // Unauthorized withdrawal.
        //
        // The attacker contract is not the owner and therefore cannot
        // drain the vault.
        // ---------------------------------------------------------------

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(accessControlAttacker))
        );

        accessControlAttacker.attack();
    }
}
