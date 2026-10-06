// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title Revert-Based Denial-of-Service Fixed Version
/// @notice Demonstrates a pull-payment pattern that prevents a malicious
///         recipient from blocking the distribution of other users' funds.
contract RevertBasedFixed {
    /// @notice List of addresses that have deposited Ether.
    /// @dev An address may appear multiple times if it calls `enter()` multiple
    ///      times.
    address[] public players;

    /// @notice Amount of Ether currently available for each player to withdraw.
    /// @dev The balance is set to the net deposit amount after the protocol fee.
    mapping(address => uint256) public balances;

    /// @notice Thrown when an Ether transfer to the caller fails.
    error TransferFailed();

    /// @notice Thrown when the caller has no Ether available to withdraw.
    error InsufficientBalance();

    /**
     * @notice Deposits Ether into the contract and registers the caller
     *         as a player.
     * @dev A 0.2% fee is deducted from the deposited amount.
     *      The remaining amount is credited to the caller's balance.
     *
     *      This contract uses a pull-payment model. Funds are not pushed
     *      to all players from a single distribution transaction.
     */
    function enter() public payable {
        if (msg.value == 0) {
            revert();
        }

        uint256 feesAmount = msg.value * 20 / 10000;
        uint256 depositAmount = msg.value - feesAmount;

        balances[msg.sender] = depositAmount;
        players.push(msg.sender);
    }

    /**
     * @notice Withdraws the caller's recorded balance.
     * @dev The caller must have a non-zero balance.
     *
     *      The balance is set to zero before making the external Ether call,
     *      following the checks-effects-interactions pattern.
     *
     *      Because each player withdraws independently, a recipient that
     *      rejects Ether cannot prevent other players from withdrawing
     *      their funds.
     */
    function distribute() external {
        uint256 amount = balances[msg.sender];

        if (amount == 0) {
            revert InsufficientBalance();
        }

        balances[msg.sender] = 0;

        (bool success,) = payable(msg.sender).call{value: amount}("");

        if (!success) {
            revert TransferFailed();
        }
    }
}

/// @title Revert-Based Denial-of-Service Attacker
/// @notice Malicious recipient used to demonstrate that the fixed contract
///         isolates a reverting recipient to its own withdrawal attempt.
contract RevertBasedAttacker {
    /// @notice Fixed contract targeted by the attacker.
    RevertBasedFixed internal revertFixed;

    /// @notice Thrown whenever this contract receives Ether directly.
    error NoDirectEther();

    /**
     * @notice Initializes the attacker contract.
     * @param _fixed Address of the fixed `RevertBasedFixed` contract.
     */
    constructor(address _fixed) {
        revertFixed = RevertBasedFixed(_fixed);
    }

    /**
     * @notice Rejects all incoming Ether transfers.
     * @dev Intentionally reverts so that this contract cannot successfully
     *      receive Ether through `distribute()`.
     */
    receive() external payable {
        revert NoDirectEther();
    }

    /**
     * @notice Deposits Ether into the fixed contract on behalf of the attacker.
     * @dev Registers this contract as a player and creates a withdrawable
     *      balance that the attacker will later attempt to claim.
     */
    function deposit() external payable {
        revertFixed.enter{value: msg.value}();
    }

    /**
     * @notice Attempts to withdraw the attacker's recorded balance.
     * @dev The withdrawal reverts because this contract intentionally rejects
     *      incoming Ether.
     *
     *      Unlike the vulnerable implementation, this failed withdrawal
     *      affects only the attacker and does not block other players from
     *      withdrawing their balances.
     */
    function attack() external {
        revertFixed.distribute();
    }
}
