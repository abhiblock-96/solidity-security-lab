// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MyToken
 * @notice ERC20 token used by the vault to represent deposited ETH.
 * @dev MTK tokens represent the caller's claim on ETH deposited into the vault.
 */
contract MyToken is ERC20 {
    /// @notice Creates the MTK token.
    constructor() ERC20("MyToken", "MTK") {}

    /**
     * @notice Mints MTK tokens to an account.
     * @param account Address receiving the newly minted tokens.
     * @param amount Amount of MTK tokens to mint.
     * @return True if the mint operation succeeds.
     */
    function mint(address account, uint256 amount) external returns (bool) {
        _mint(account, amount);
        return true;
    }

    /**
     * @notice Burns MTK tokens from an account.
     * @param account Address whose tokens will be burned.
     * @param amount Amount of MTK tokens to burn.
     * @return True if the burn operation succeeds.
     */
    function burn(address account, uint256 amount) external returns (bool) {
        _burn(account, amount);
        return true;
    }
}

/**
 * @title CrossContractFixedVault
 * @notice ETH vault that uses MTK tokens to represent deposited ETH.
 * @dev Protects the withdrawal flow against cross-contract reentrancy by
 *      updating the external token state before making the ETH transfer.
 *      ReentrancyGuard provides an additional protection against recursive
 *      calls to withdraw().
 */
contract CrossContractFixedVault is ReentrancyGuard {
    /// @notice Thrown when a zero-value deposit is attempted.
    error AmountMustBeGreaterThanZero();

    /// @notice Thrown when the ETH transfer during withdrawal fails.
    error WithdrawFailed();

    /// @notice Thrown when minting the deposit tokens fails.
    error MintFailed();

    /// @notice Token representing the user's deposited ETH.
    MyToken internal token;

    /**
     * @notice Sets the token contract used by the vault.
     * @param _token Address of the MyToken contract.
     */
    constructor(address _token) {
        token = MyToken(_token);
    }

    /**
     * @notice Deposits ETH and mints an equivalent amount of MTK tokens.
     * @dev The deposited ETH remains in the vault while the caller receives
     *      MTK representing their claim on the deposited ETH.
     */
    function deposit() external payable {
        if (msg.value == 0) revert AmountMustBeGreaterThanZero();

        bool success = token.mint(msg.sender, msg.value);
        if (!success) revert MintFailed();
    }

    /**
     * @notice Withdraws ETH based on the caller's MTK balance.
     * @dev The caller's MTK balance is burned before the external ETH transfer.
     *      This prevents the recipient from modifying its token balance during
     *      the callback and exploiting stale token accounting.
     */
    function withdraw() external nonReentrant {
        // CHECK
        uint256 amount = token.balanceOf(msg.sender);

        /// EFFECT
        token.burn(msg.sender, amount);

        /// INTERACTION
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert WithdrawFailed();
    }
}

/**
 * @title CrossContractFixedAttacker
 * @notice Test contract that attempts to exploit cross-contract reentrancy
 *         against the fixed vault.
 * @dev During the ETH callback, the attacker attempts to move its MTK balance
 *      through the external token contract. The attack should not produce an
 *      unauthorized withdrawal because the MTK balance has already been
 *      burned before the callback.
 */
contract CrossContractFixedAttacker {
    /// @notice Reference to the fixed vault.
    CrossContractFixedVault internal bank;

    /// @notice Reference to the external token contract.
    MyToken internal token;

    /// @notice Address receiving MTK during the attempted attack.
    address public constant attacker = address(1);

    /**
     * @notice Initializes the attacker contract.
     * @param _fixedContract Address of the fixed vault.
     * @param _token Address of the MyToken contract.
     */
    constructor(address _fixedContract, address _token) {
        bank = CrossContractFixedVault(_fixedContract);
        token = MyToken(_token);
    }

    /**
     * @notice Attempts to modify the attacker's token balance during the
     *         vault's ETH transfer callback.
     * @dev The vault burns the attacker's MTK balance before this callback,
     *      so there should be no MTK balance available to transfer.
     */
    receive() external payable {
        uint256 amount = token.balanceOf(address(this));

        if (amount > 0) {
            token.transfer(attacker, amount);
        }
    }

    /**
     * @notice Deposits ETH into the fixed vault on behalf of this contract.
     * @dev The vault mints MTK to this contract because it is msg.sender.
     */
    function deposit() external payable {
        bank.deposit{value: msg.value}();
    }

    /**
     * @notice Initiates the cross-contract reentrancy attack.
     * @dev The attack is expected to fail to obtain any unauthorized funds
     *      because the vault updates token accounting before the callback.
     */
    function attack() external {
        bank.withdraw();
    }
}
