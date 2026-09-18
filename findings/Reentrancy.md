# [C-1] Classic Reentrancy in `withdraw()`

## Description

`ClassicExploitContract::withdraw()` sends ETH to `msg.sender` before updating `balanceOf[msg.sender]` to zero.

Because the recipient is an arbitrary address, a malicious contract can execute its fallback/`receive()` function during the external call and recursively invoke `withdraw()`. Each recursive call observes the attacker's original non-zero balance because the state update has not yet occurred.

<details>

<summary>Vulnerable Code</summary>

```solidity
function withdraw() external {
    uint amount = balanceOf[msg.sender];

    (bool success,) = payable(msg.sender).call{value: amount}("");

    if (!success) revert WithdrawFailed();

    balanceOf[msg.sender] = 0;
}
```

</details>

## Impact

An attacker can repeatedly withdraw against the same recorded balance and drain the contract's available ETH, resulting in **loss of user funds**.

## Proof of Concept

The accompanying Foundry test demonstrates that an attacker can recursively re-enter `withdraw()` and drain the contract's entire ETH balance.

<details>

<summary>PoC</summary>

```solidity
function test_classicReentrancy_attackerSuccessfullyDrainsTheVault() external {
    vm.prank(user1);
    classicVault.deposit{value: 5 ether}();

    vm.prank(user2);
    classicVault.deposit{value: 9 ether}();

    vm.prank(attacker);
    classicAttacker.deposit{value: 1 ether}();

    uint256 initialVaultBalance = address(classicVault).balance;

    vm.prank(attacker);
    classicAttacker.attack();

    assertEq(address(classicVault).balance, 0);
    assertEq(
        address(classicAttacker).balance,
        initialVaultBalance
    );
}
```

</details>

## Mitigation

Follow the **Checks-Effects-Interactions (CEI)** pattern by setting the user's balance to zero before performing the external call.

Alternatively, protect `withdraw()` with a reentrancy guard such as OpenZeppelin's `ReentrancyGuard`.

---
<br>

# [C-2] Cross-Function Reentrancy Causes Incorrect Balance Accounting

## Description

`CrossFunctionReentrancyVault::withdraw()` performs an external ETH transfer before updating `balanceOf[msg.sender]`.

Although `withdraw()` is protected by `nonReentrant`, a malicious contract can use the external call to re-enter through a **different unprotected function** that also modifies `balanceOf`. This allows the attacker to manipulate the shared balance state before `withdraw()` completes.

Unlike classic reentrancy, the attacker does not need to recursively call `withdraw()`; re-entering another state-changing function is sufficient.

<details>

<summary>Vulnerable Code</summary>

```solidity
function withdraw() external nonReentrant {
    uint amount = balanceOf[msg.sender];

    (bool success,) = payable(msg.sender).call{value: amount}("");

    if (!success) revert WithdrawFailed();

    balanceOf[msg.sender] = 0;
}
```

</details>

## Impact

An attacker can manipulate the shared balance accounting and withdraw ETH that should not be available, resulting in **loss of vault funds** and incorrect internal balances.

## Proof of Concept

The accompanying Foundry test demonstrates that the attacker re-enters through another function, transfers its recorded balance to the owner, and subsequently withdraws the manipulated balance.

<details>

<summary>PoC</summary>

```solidity
function test_crossFunctionReentrancy_exploitsSharedBalance() external {
    vm.prank(user1);
    crossFunctionVault.deposit{value: 5 ether}();

    vm.prank(user2);
    crossFunctionVault.deposit{value: 9 ether}();

    vm.prank(attacker);
    crossFunctionAttacker.deposit{value: 1 ether}();

    vm.prank(attacker);
    crossFunctionAttacker.attack();

    assertEq(
        crossFunctionVault.balanceOf(address(crossFunctionAttacker)),
        0
    );

    assertEq(
        crossFunctionVault.balanceOf(crossFunctionAttacker.owner()),
        1 ether
    );

    vm.prank(crossFunctionAttacker.owner());
    crossFunctionVault.withdraw();

    assertEq(address(crossFunctionVault).balance, 13 ether);
}
```

</details>

## Mitigation

Follow **Checks-Effects-Interactions (CEI)** by updating the balance before the external call.

Additionally, ensure that **all functions modifying the shared state are protected by the same reentrancy guard**, rather than protecting only `withdraw()`.

<br>

# [C-3] Cross-Contract Reentrancy Causes Incorrect Token Accounting

## Description

`CrossContractReentrancyVault::withdraw()` transfers ETH to `msg.sender` before burning the corresponding MTK balance.

Although `withdraw()` is protected by `nonReentrant`, the recipient can execute its `receive()` function during the external ETH transfer and modify its MTK balance through the separate `MyToken` contract.

When execution returns to `withdraw()`, the vault burns the recipient's **current** token balance rather than the balance used to calculate the withdrawal amount. The attacker can therefore transfer the MTK during the callback, causing the vault to burn zero tokens while still transferring the previously calculated amount of ETH.

Unlike cross-function reentrancy, the attacker does not need to re-enter another function of the vault. The attack relies on modifying state in an **external contract** that the vault uses for its accounting.

<details>

<summary>Vulnerable Code</summary>

```solidity
function withdraw() external nonReentrant {
    uint256 amount = token.balanceOf(msg.sender);

    (bool success,) = payable(msg.sender).call{value: amount}("");
    if (!success) revert WithdrawFailed();

    token.burn(msg.sender, token.balanceOf(msg.sender));
}
```

</details>

## Impact

An attacker can transfer their MTK balance during the ETH callback, causing the vault to send ETH without burning the corresponding tokens. The transferred tokens can subsequently be used by another attacker-controlled address to claim additional ETH, resulting in **loss of vault funds** and inconsistent token/ETH accounting.

## Proof of Concept

The accompanying Foundry test demonstrates that an attacker can move its MTK balance to another attacker-controlled contract during the withdrawal callback. The second contract can then use the transferred tokens to perform another withdrawal while the corresponding tokens are again transferred before being burned.

<details>

<summary>PoC</summary>

```solidity
function test_crossContractReentrancy_manipulatesTokenBalance() external {
    vm.prank(user1);
    crossContractVault.deposit{value: 8 ether}();

    vm.prank(user2);
    crossContractVault.deposit{value: 5 ether}();

    vm.prank(attacker);
    crossContractAttackerFirst.deposit{value: 1 ether}();

    vm.prank(attacker);
    crossContractAttackerFirst.attack();

    uint256 attacker1TokenBalance =
        token.balanceOf(crossContractAttackerFirst.attacker1());

    assertEq(attacker1TokenBalance, 1 ether);

    vm.prank(crossContractAttackerFirst.attacker1());
    token.transfer(
        address(crossContractAttackerSecond),
        attacker1TokenBalance
    );

    vm.prank(attacker);
    crossContractAttackerSecond.attack();

    assertEq(address(crossContractVault).balance, 12 ether);
}
```

</details>

## Mitigation

Follow the **Checks-Effects-Interactions (CEI)** pattern by burning the corresponding MTK balance before transferring ETH.

The withdrawal amount should also be determined once and used consistently for both the token burn and ETH transfer, rather than querying the external token balance again after the external call.


