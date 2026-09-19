// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ClassicReentrancyFixedVault
 * @notice ETH vault that protects withdrawals against classic reentrancy attacks.
 * @dev Uses OpenZeppelin's ReentrancyGuard to prevent reentrant calls to
 *      the withdrawal function.
 */
contract ClassicReentrancyFixedVault is ReentrancyGuard {
    mapping(address account => uint256 value) public balanceOf;

    /// @notice Thrown when a zero-value deposit is attempted.
    error AmountMustBeGreaterThanZero();

    /// @notice Thrown when the ETH transfer during withdrawal fails.
    error WithdrawFailed();

    /**
     * @notice Deposits ETH and credits the sender's balance.
     * @return success True if the deposit succeeds.
     */
    function deposit() external payable returns (bool) {
        if (msg.value == 0) revert AmountMustBeGreaterThanZero();

        balanceOf[msg.sender] += msg.value;
        return true;
    }

    /**
     * @notice Withdraws the sender's entire credited balance.
     * @dev Follows the checks-effects-interactions pattern and uses
     *      ReentrancyGuard to prevent recursive withdrawals.
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
}

/**
 * @title FixedVaultAttacker
 * @notice Test contract used to attempt a classic reentrancy attack
 *         against the fixed vault.
 * @dev The contract attempts to reenter the vault during the ETH receive
 *      callback. The attack should fail because the vault is protected
 *      by ReentrancyGuard.
 */
contract FixedVaultAttacker {
    ClassicReentrancyFixedVault internal fixedVault;

    /**
     * @notice Initializes the attacker with the address of the target vault.
     * @param _fixedVault Address of the fixed vault to attack.
     */
    constructor(address _fixedVault) {
        fixedVault = ClassicReentrancyFixedVault(_fixedVault);
    }

    /**
     * @notice Attempts to reenter the vault when receiving ETH.
     * @dev Reentrancy is attempted while the vault still has sufficient
     *      ETH to continue the attack.
     */
    receive() external payable {
        if (address(fixedVault).balance >= 1 ether) {
            fixedVault.withdraw();
        }
    }

    /**
     * @notice Deposits ETH into the target vault on behalf of the attacker.
     * @dev The deposited amount is credited to this contract's vault balance.
     */
    function deposit() external payable {
        fixedVault.deposit{value: msg.value}();
    }

    /**
     * @notice Initiates the reentrancy attack against the target vault.
     * @dev The attack is expected to fail because the target vault prevents
     *      reentrant execution of the withdrawal function.
     */
    function attack() external {
        fixedVault.withdraw();
    }
}
