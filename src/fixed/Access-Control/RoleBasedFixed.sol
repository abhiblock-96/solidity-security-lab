//SPDX-License-Identifier:MIT
pragma solidity ^0.8.4;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20, AccessControl {
    bytes32 public SHOP_ROLE = keccak256("SHOP_ROLE");

    constructor() ERC20("MyToken", "MTK") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function grantShopRole(address _shop) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(SHOP_ROLE, _shop);
    }

    function mint(address account, uint256 amount) external onlyRole(SHOP_ROLE) returns (bool) {
        _mint(account, amount);
        return true;
    }

    function burn(address account, uint256 amount) external onlyRole(SHOP_ROLE) returns (bool) {
        _burn(account, amount);
        return true;
    }
}

contract RoleBasedFixedVault {
    MyToken internal token;

    mapping(address => uint256) public balances;

    error AmountMustBeGreaterThanZero();
    error InsufficientTokenAmount();
    error WithdrawFailed();

    constructor(address _token) payable {
        token = MyToken(_token);
    }

    function buyToken() external payable {
        if (msg.value == 0) {
            revert AmountMustBeGreaterThanZero();
        }

        token.mint(msg.sender, msg.value);
    }

    function sellToken(uint256 amount) external {
        uint256 tokenBal = token.balanceOf(msg.sender);

        if (amount > tokenBal) {
            revert InsufficientTokenAmount();
        }

        token.burn(msg.sender, amount);

        (bool success,) = payable(msg.sender).call{value: amount}("");

        if (!success) {
            revert WithdrawFailed();
        }
    }
}

contract FixedRoleBasedAttacker {
    RoleBasedFixedVault internal vault;
    MyToken internal token;

    /**
     * @param _vault Address of the vulnerable vault.
     * @param _token Address of the vulnerable token.
     */
    constructor(address _vault, address _token) {
        vault = RoleBasedFixedVault(_vault);
        token = MyToken(_token);
    }

    /// @notice Allows the attacker contract to receive ETH from the vault.
    receive() external payable {}

    /// @notice Allows the attacker contract to receive ETH sent through fallback calls.
    fallback() external payable {}

    function attack(uint256 amount) external {
        // fails to mint
        token.mint(address(this), amount);
        vault.sellToken(amount);
    }
}
