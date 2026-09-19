// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "forge-std/Test.sol";

import {ClassicReentrancyFixedVault, FixedVaultAttacker} from "src/fixed/Reentrancy/ClassicReentrancyFixed.sol";

import {
    CrossFunctionFixedVault,
    CrossFunctionFixedAttacker
} from "src/fixed/Reentrancy/Cross-FunctionReentrancyFixed.sol";

import {
    MyToken,
    CrossContractFixedVault,
    CrossContractFixedAttacker
} from "src/fixed/Reentrancy/Cross-ContractReentrancyFixed.sol";

contract BaseContract is Test {
    ClassicReentrancyFixedVault internal classicFixedVault;
    FixedVaultAttacker internal fixedAttacker;

    CrossFunctionFixedVault internal crossFunctionFixedVault;
    CrossFunctionFixedAttacker internal crossFunctionFixedAttacker;

    MyToken internal token;
    CrossContractFixedVault internal crossContractFixedVault;
    CrossContractFixedAttacker internal crossContractAttacker;

    address internal user1 = makeAddr("user1");
    address internal user2 = makeAddr("user2");
    address internal attacker = makeAddr("attacker");

    function setUp() external {
        classicFixedVault = new ClassicReentrancyFixedVault();
        fixedAttacker = new FixedVaultAttacker(address(classicFixedVault));

        crossFunctionFixedVault = new CrossFunctionFixedVault();
        crossFunctionFixedAttacker = new CrossFunctionFixedAttacker(address(crossFunctionFixedVault));

        token = new MyToken();
        crossContractFixedVault = new CrossContractFixedVault(address(token));
        crossContractAttacker = new CrossContractFixedAttacker(address(crossContractFixedVault), address(token));

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(attacker, 2 ether);
    }
}
