# [H-1] Gas-Based Denial of Service (DoS) Due to Unbounded Iteration

## Description

The `GasBasedExploit` contract is vulnerable to a gas-based Denial of Service because `enter()` performs a linear search over the entire `players` array before allowing a new participant to enter.

<details>
<summary>vulnerable code</summary>

```solidity
function enter() external {
    for (uint i = 0; i < players.length; i++) {
        if (msg.sender == players[i]) {
            revert AlreadyEntered(msg.sender);
        }
    }

    players.push(msg.sender);
}
```
</details>
<br>

`enter()` performs a linear search through `players`, so its gas cost increases with the array size. An attacker can add many unique addresses, causing the array to grow and making subsequent `enter()` calls increasingly expensive. If the array becomes sufficiently large, the function may exceed the available gas limit, preventing legitimate users from entering and causing a Denial of Service.


## Impact

An attacker can cause the gas cost of `enter()` to grow by increasing the number of stored players.

If the `players` array grows beyond a practical execution limit, legitimate users may be unable to call `enter()` successfully because the linear iteration consumes excessive gas.

This can prevent new participants from interacting with the protocol and may disrupt functionality that depends on successful registration through `enter()`.

The issue therefore represents an availability risk to the protocol's core functionality.

## Proof of Concept

The vulnerability can be demonstrated by measuring the gas required by `enter()` at different `players` array sizes.

With a smaller number of players, the function requires less gas. After additional players are added, the same operation requires significantly more gas.

<details>
<summary>PoC</summary>

```solidity
    function test_GasBasedExploit_GasGrowthLeadsToDoS() external {
        uint256 gasBefore;
        uint256 gasAfter;

        for (uint160 i = 0; i < 50; i++) {
            vm.prank(address(i + 1));
            gasBased.enter();
        }

        gasBefore = gasleft();

        vm.prank(user);
        gasBased.enter();

        gasAfter = gasleft();

        uint256 gasFor50Players = gasBefore - gasAfter;

        for (uint160 i = 100; i < 200; i++) {
            vm.prank(address(i));
            gasBased.enter();
        }

        gasBefore = gasleft();

        vm.prank(user2);
        gasBased.enter();

        gasAfter = gasleft();

        uint256 gasFor150Players = gasBefore - gasAfter;

        console.log("Gas with 50 players:", gasFor50Players);
        console.log("Gas with 150 players:", gasFor150Players);

        // Gas required by enter() increases with state size.
        assertGt(gasFor150Players, gasFor50Players);

        vm.prank(user);
        vm.expectRevert();
        gasBased.enter{gas: 50_000}();
    }
```
</details>

The assertion demonstrates that the gas required by `enter()` increases as the attacker-controlled `players` array grows.

## Mitigation

Avoid performing an unbounded linear search through the `players` array to determine whether an address has already entered.

Use a mapping for constant-time membership checks:

```solidity
mapping(address => bool) public hasEntered;
```

This changes the membership-checking operation from an O(n) linear scan to an approximately O(1) lookup, preventing gas consumption from increasing proportionally with the number of players.
<br>

## [H-2] Revert-Based Denial of Service (DoS) due to Malicious Attacker

### Description

`distribute()` iterates over all registered players and reverts the entire transaction if any Ether transfer fails. A malicious contract can register as a player and intentionally revert when receiving Ether.

<details>
<summary>Vulnerable Code</summary>

```solidity
function distribute() external {
    for (uint256 i = 0; i < players.length; i++) {
        uint256 amount = balances[players[i]];
        (bool success,) = payable(players[i]).call{value: amount}("");

        if (!success) {
            revert TransferFailed();
        }
    }
}
```

</details>

As a result, the attacker can cause `distribute()` to revert when execution reaches the malicious recipient, preventing the distribution from completing for all other players.

### Impact

An attacker can block the distribution process, causing a **Denial of Service** for all legitimate players whose funds are distributed through `distribute()`.

### Proof of Concept

The following Foundry test demonstrates that a malicious recipient can cause the entire `distribute()` transaction to revert:

<details>
<summary>PoC</summary>

```solidity
function test_RevertBasedExploit_MaliciousRecipientCausesDistributionDoS()
    external
{
    _enter(user);

    vm.prank(attacker);
    revertAttacker.attack{value: 5e17}();

    _enter(user2);

    vm.prank(attacker);
    vm.expectRevert(RevertBasedExploit.TransferFailed.selector);
    revertBased.distribute();

    assertEq(
        revertBased.balances(address(revertAttacker)),
        499e15
    );
    assertEq(revertBased.balances(user), 998e15);
    assertEq(revertBased.balances(user2), 998e15);
}
```

</details>

The attacker contract intentionally reverts when receiving Ether. Consequently, the transfer fails, `TransferFailed()` is triggered, and the entire distribution transaction is reverted.

### Mitigation

Use a **pull-payment pattern instead of a push-payment pattern**, allowing each player to independently withdraw their balance.

Alternatively, failed transfers can be recorded for later withdrawal rather than reverting the entire distribution.
