# [H-1] Unrestricted Minting and Burning in `MyToken`

## Description

`MyToken::mint()` and `MyToken::burn()` are externally callable without any access-control mechanism.

As a result, any address can arbitrarily increase the token supply by minting MTK to any address or destroy MTK belonging to another address.

<details>
<summary>vulnerable code</summary>

```solidity
function mint(address account, uint256 amount) external returns (bool) {
    _mint(account, amount);
    return true;
}

function burn(address account, uint256 amount) external returns (bool) {
    _burn(account, amount);
    return true;
}

Neither function verifies that `msg.sender` is authorized to perform the corresponding supply-management operation.
```
</details>

## Impact

An attacker can exploit the unrestricted `mint()` function to create an arbitrary amount of unbacked MTK.

Because `MissingRoleBasedVault::sellToken()` treats MTK as redeemable for ETH, an attacker can mint tokens and exchange them for ETH held by the vault.

This can result in **loss of vault funds and unauthorized token supply inflation**.

The unrestricted `burn()` function allows an attacker to burn MTK from arbitrary addresses without authorization, resulting in **unauthorized loss of user token balances**.

## Proof of Concept

The accompanying Foundry test demonstrates that an attacker can mint arbitrary MTK and redeem it through the vault and can also burn tokens held by other users.

<details>
<summary>PoC</summary>

```Solidity
function test_missingRoleBasedControl_Exploits() external {
        vm.prank(user1);
        missingRoleVault.buyToken{value: 1 ether}();

        vm.prank(user2);
        missingRoleVault.buyToken{value: 3 ether}();

        uint256 initialVaultBalance = address(missingRoleVault).balance;
        assertEq(initialVaultBalance, 24e18);

        vm.prank(attacker);
        missingRoleAttacker.attack(5e18);

        uint256 vaultBalance = address(missingRoleVault).balance;

        assertEq(address(missingRoleAttacker).balance, 5e18);

        assertEq(vaultBalance, initialVaultBalance - 5e18);

        vm.prank(attacker);
        token.burn(user2, 2e18);

        assertEq(token.balanceOf(user2), 1e18);
    }

```
</details>



## Mitigation

Restrict `mint()` and `burn()` to authorized accounts or contracts.

The vault should only be granted the permissions required for its intended interaction with the token.

Additionally, `burn()` should not allow arbitrary callers to burn tokens belonging to another account unless that behavior is explicitly intended and authorized.

Unauthorized callers should revert, while authorized callers should retain the required functionality.

<br>

# [C-1] Missing Access Control Allows Unauthorized Ownership Transfer and Vault Drain

## Description

`MissingAccessControlVault::transferOwnership()` and `MissingAccessControlVault::withdraw()` do not enforce any access-control checks.

As a result, any address can:

1. Change the vault owner to an arbitrary address.
2. Withdraw the entire ETH balance of the vault.

The `owner` variable does not provide any protection because neither sensitive function verifies that the caller is authorized.

<details>
<summary>Vulnerable Code</summary>

```solidity
function transferOwnership(address _newOwner) external {
    owner = _newOwner;
}

function withdraw() external {
    uint256 amount = address(this).balance;

    (bool success,) = payable(msg.sender).call{value: amount}("");

    if (!success) {
        revert WithdrawFailed();
    }
}
```

</details>

## Impact

An attacker can arbitrarily change the vault owner, potentially gaining access to functionality intended only for the owner.

More critically, any address can call `withdraw()` and transfer the vault's entire ETH balance to itself.

This results in **complete loss of funds held by the vault**.

The unauthorized withdrawal does not depend on the attacker first becoming the owner because `withdraw()` does not check the `owner` variable.

## Proof of Concept

The accompanying Foundry test demonstrates both unauthorized ownership transfer and unauthorized withdrawal.

<details>
<summary>PoC</summary>

```solidity
function test_missingAccessControl_Exploits() external {
        _deposit(user1, 8 ether);

        assertEq(missingAccessControlVault.owner(), admin);

        vm.prank(attacker);
        missingAccessControlVault.transferOwnership(attacker);

        assertEq(missingAccessControlVault.owner(), attacker);

        vm.prank(attacker);
        missingAccessControlAttacker.attack();

        uint256 vaultBalance = address(missingAccessControlVault).balance;

        assertEq(vaultBalance, 0);
    }
```
</details>


## Mitigation

Restrict ownership management to the current owner or another explicitly authorized account.

`withdraw()` should also verify that the caller is authorized to withdraw funds before performing the external ETH transfer.

Use an established access-control mechanism such as OpenZeppelin's `Ownable` or `AccessControl`, depending on the intended authorization model.

Additionally, ownership transfer should follow a secure ownership-transfer pattern, such as a two-step transfer, where appropriate.
