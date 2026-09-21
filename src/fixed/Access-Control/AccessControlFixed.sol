// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AccessControlFixedVault
 * @notice Vault demonstrating owner-based access control.
 *
 * @dev
 * This contract is the mitigated version of the missing access-control
 * vulnerability.
 *
 * The sensitive `withdraw()` function is protected with OpenZeppelin's
 * `onlyOwner` modifier, ensuring that an unauthorized account cannot
 * withdraw the vault's ETH balance.
 */
contract AccessControlFixedVault is Ownable {
    /// @notice ETH balance credited to each depositor.
    mapping(address => uint256) public balances;

    error WithdrawFailed();

    /**
     * @notice Initializes the vault with an owner.
     *
     * @param _owner Address that is authorized to perform owner-only
     * operations.
     */
    constructor(address _owner) Ownable(_owner) {}

    /**
     * @notice Deposits ETH into the vault.
     *
     * @dev
     * The deposited amount is credited to the caller's internal balance.
     */
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    /**
     * @notice Withdraws the entire ETH balance of the vault.
     *
     * @dev
     * Only the vault owner can call this function.
     *
     * The `onlyOwner` modifier prevents unauthorized accounts from
     * draining the vault.
     */
    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;

        (bool success,) = payable(msg.sender).call{value: amount}("");

        if (!success) {
            revert WithdrawFailed();
        }
    }
}

/**
 * @title FixedAccessControlAttacker
 * @notice Attacker contract used to verify the access-control mitigation.
 *
 * @dev
 * This contract attempts to call the owner-restricted `withdraw()`
 * function.
 *
 * The call is expected to revert when initiated by an unauthorized
 * account, demonstrating that the vault can no longer be drained
 * through the previous attack path.
 */
contract FixedAccessControlAttacker {
    AccessControlFixedVault internal vault;

    /// @notice Allows the contract to receive ETH during testing.
    receive() external payable {}

    /**
     * @notice Initializes the attacker with the fixed vault.
     *
     * @param _vault Address of the protected vault.
     */
    constructor(address _vault) {
        vault = AccessControlFixedVault(_vault);
    }

    /**
     * @notice Attempts to execute the unauthorized withdrawal exploit.
     *
     * @dev
     * This call should revert because the attacker is not the owner
     * of the vault.
     */
    function attack() external {
        vault.withdraw();
    }
}
