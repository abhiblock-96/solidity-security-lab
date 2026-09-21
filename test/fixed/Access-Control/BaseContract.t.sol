// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "forge-std/Test.sol";

import {MyToken, RoleBasedFixedVault, FixedRoleBasedAttacker} from "src/fixed/Access-Control/RoleBasedFixed.sol";

import {AccessControlFixedVault, FixedAccessControlAttacker} from "src/fixed/Access-Control/AccessControlFixed.sol";

contract BaseContract is Test {
    MyToken internal token;
    RoleBasedFixedVault internal roleBasedVault;
    FixedRoleBasedAttacker internal roleBasedAttacker;

    AccessControlFixedVault internal accessControlVault;
    FixedAccessControlAttacker internal accessControlAttacker;

    address internal admin = makeAddr("admin");

    address internal attacker = makeAddr("attacker");

    address internal user1 = makeAddr("user1");

    address internal user2 = makeAddr("user2");

    function setUp() external {
        vm.deal(admin, 30 ether);
        vm.deal(attacker, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        vm.startPrank(admin);
        token = new MyToken();
        roleBasedVault = new RoleBasedFixedVault(address(token));
        vm.stopPrank();

        roleBasedAttacker = new FixedRoleBasedAttacker(address(roleBasedVault), address(token));

        accessControlVault = new AccessControlFixedVault(admin);
        accessControlAttacker = new FixedAccessControlAttacker(address(accessControlVault));
    }

    function _deposit(address account, uint256 amount) internal {
        vm.prank(account);
        accessControlVault.deposit{value: amount}();
    }
}
