// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title CrossFunctionFixedVault
 * @notice ETH vault that supports deposits, withdrawals, and internal balance transfers.
 * @dev Protects the withdrawal flow against cross-function reentrancy by updating
 *      the shared balance state before making the external ETH transfer.
 *      ReentrancyGuard provides an additional protection for withdraw().
 */
contract CrossFunctionFixedVault is ReentrancyGuard {
    /// @notice ETH balance credited to each depositor.
    mapping(address account => uint256 value) public balanceOf;

    /// @notice Thrown when a zero-value deposit or transfer is attempted.
    error AmountMustBeGreaterThanZero();

    /// @notice Thrown when the ETH transfer during withdrawal fails.
    error WithdrawFailed();

    /**
     * @notice Deposits ETH and credits the sender's vault balance.
     * @return success True if the deposit succeeds.
     */
    function deposit() external payable returns (bool) {
        if (msg.value == 0) revert AmountMustBeGreaterThanZero();

        balanceOf[msg.sender] += msg.value;
        return true;
    }

    /**
     * @notice Withdraws the sender's entire credited ETH balance.
     * @dev The sender's balance is set to zero before the external ETH transfer.
     *      This prevents a reentrant call to another function, such as transfer(),
     *      from exploiting stale shared balance state.
     */
    function withdraw() external nonReentrant {
        // CHECK
        uint256 amount = balanceOf[msg.sender];

        // EFFECT
        balanceOf[msg.sender] = 0;

        // INTERACTION
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert WithdrawFailed();
    }

    /**
     * @notice Transfers part of the caller's credited balance to another account.
     * @param to Address receiving the transferred balance.
     * @param amount Amount of ETH balance units to transfer.
     * @dev This function shares the same balance mapping used by withdraw().
     *      Clearing the withdrawal balance before the external call prevents
     *      this function from exploiting stale balance state during reentrancy.
     */
    function transfer(address to, uint256 amount) external {
        if (amount == 0) revert AmountMustBeGreaterThanZero();

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
    }
}

/**
 * @title CrossFunctionFixedAttacker
 * @notice Test contract that attempts to exploit cross-function reentrancy
 *         against the fixed vault.
 * @dev During the ETH transfer callback, the attacker attempts to call
 *      transfer() using the shared balance mapping. The attack should not
 *      result in unauthorized balance manipulation because withdraw() clears
 *      the attacker's balance before the callback.
 */
contract CrossFunctionFixedAttacker {
    /// @notice Reference to the fixed vault contract.
    CrossFunctionFixedVault internal bank;

    /// @notice Address intended to receive the attempted transferred balance.
    address public immutable owner = address(1);

    /**
     * @notice Initializes the attacker contract.
     * @param _fixedContract Address of the fixed vault contract.
     */
    constructor(address _fixedContract) {
        bank = CrossFunctionFixedVault(_fixedContract);
    }

    /**
     * @notice Attempts to exploit cross-function reentrancy during the ETH callback.
     * @dev Calls transfer() using the attacker's vault balance. The balance should
     *      already be zero because withdraw() updates it before the callback.
     */
    receive() external payable {
        uint256 amount = bank.balanceOf(address(this));
        bank.transfer(owner, amount);
    }

    /**
     * @notice Deposits ETH into the fixed vault on behalf of this attacker contract.
     */
    function deposit() external payable {
        bank.deposit{value: msg.value}();
    }

    /**
     * @notice Initiates the cross-function reentrancy attack attempt.
     */
    function attack() external {
        bank.withdraw();
    }
}
