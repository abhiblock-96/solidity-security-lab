//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BaseContract} from "test/fixed/DoS/BaseContract.t.sol";
import {RevertBasedFixed, RevertBasedAttacker} from "src/fixed/DoS/RevertBasedFixed.sol";

contract DoSFixedTest is BaseContract {
    /**
     * @notice Verifies that player registration remains available after a large
     *         number of players have already been registered.
     * @dev Adds 5,000 players and then verifies that a new player can still
     *      successfully enter.
     *
     *      This test demonstrates that `enter()` does not iterate over the
     *      unbounded `players` array and therefore avoids the gas-based
     *      denial-of-service vulnerability present in the vulnerable version.
     */
    function test_GasBasedFixed_EnterRemainsAvailableAfterManyPlayers() external {
        // Add initial player
        vm.prank(user);
        gasBased.enter();

        // Add 5,000 players
        for (uint256 i = 1; i <= 5000; i++) {
            vm.prank(address(uint160(i)));
            gasBased.enter();
        }

        // A new player should still be able to enter
        vm.prank(user2);
        gasBased.enter();

        assertTrue(gasBased.isEntered(user2));
        assertEq(gasBased.getNumberOfPlayers(), 5002);
    }

    /**
     * @notice Verifies that a malicious recipient cannot prevent other users
     *         from withdrawing their funds.
     * @dev The attacker contract intentionally reverts when receiving Ether.
     *      Its withdrawal should fail, but a legitimate user's withdrawal
     *      must remain successful.
     */
    function test_RevertBasedFixed_MaliciousRecipientCannotBlockOtherWithdrawals() external {
        // Legitimate user deposits
        _enter(user);

        // Attacker deposits and becomes a registered recipient
        vm.prank(attacker);
        revertAttacker.deposit{value: 5e17}();

        // Another legitimate user deposits
        _enter(user2);

        // Attacker's withdrawal must fail because it rejects Ether
        vm.prank(attacker);

        vm.expectRevert(RevertBasedFixed.TransferFailed.selector);
        revertAttacker.attack();

        // user2 must still be able to withdraw successfully
        vm.prank(user2);
        revertBased.distribute();

        // Verify user2's balance has been cleared
        assertEq(revertBased.balances(user2), 0);
    }

    /// @notice Verifies that forced ETH does not prevent the owner from withdrawing recorded deposits.
    /// @dev Two users deposit ETH, then the attacker forces additional ETH into the vault.
    ///      The owner must still be able to withdraw all recorded deposits despite the balance mismatch.
    ///      The forced ETH remains in the vault after the withdrawal.
    function test_EthMishandlingFixed_ForcedEtherDoesNotBlockWithdrawal() external {
        vm.prank(user);
        mishandlingVault.deposit{value: 1 ether}();

        vm.prank(user2);
        mishandlingVault.deposit{value: 1 ether}();

        // Attacker forces ETH into the vault without using deposit().
        vm.deal(attacker, 0.1 ether);
        vm.prank(attacker);
        mishandlingAttacker.attack{value: 0.1 ether}();

        // Owner can withdraw recorded deposits despite the balance mismatch.
        vm.prank(owner);
        mishandlingVault.withdraw();

        assertEq(address(mishandlingVault).balance, 0.1 ether);
    }
}
