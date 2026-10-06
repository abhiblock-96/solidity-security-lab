// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title Gas-Based Denial-of-Service Fixed Version
/// @notice Prevents gas-based denial of service by using a mapping for
///         constant-time duplicate-player checks instead of iterating over
///         the entire player array.
contract GasBasedFixed {
    /// @notice List of addresses that have successfully entered.
    /// @dev This array is used only for storing the player list and is not
    ///      iterated over during player registration.
    address[] public players;

    /// @notice Tracks whether an address has already entered.
    /// @dev Provides constant-time duplicate-entry checks.
    mapping(address => bool) public isEntered;

    /// @notice Thrown when an address attempts to enter more than once.
    error AlreadyEntered();

    /**
     * @notice Registers the caller as a player.
     * @dev Uses `isEntered` to check for duplicate entries without iterating
     *      over the unbounded `players` array.
     *
     *      This prevents the gas consumption of `enter()` from growing
     *      linearly with the number of registered players.
     */
    function enter() external {
        if (isEntered[msg.sender]) {
            revert AlreadyEntered();
        }

        players.push(msg.sender);
        isEntered[msg.sender] = true;
    }

    /**
     * @notice Returns the total number of registered players.
     * @return The number of addresses stored in the `players` array.
     */
    function getNumberOfPlayers() external view returns (uint256) {
        return players.length;
    }
}
