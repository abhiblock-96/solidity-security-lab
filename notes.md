## 1.Single-Function Reentrancy Attack (Classic Reentrancy)

In a **single-function reentrancy attack**, an attacker repeatedly re-enters the **same vulnerable function** before the contract has updated the attacker's state.

This can potentially allow the attacker to **drain the protocol's funds**, causing a loss of funds for other users.

The vulnerability commonly occurs when a function follows the **Check → Interaction → Effect** pattern, where the **external interaction happens before the state update**.

The key issue is:

> **The contract updates the user's balance after making an external call, giving the attacker an opportunity to re-enter the function before their balance is updated.**

### Attack Flow

```text
                Attacker Contract
                       |
                       | vault.withdraw()
                       ↓
                Vault Contract
                       |
                       | sends ETH
                       ↓
             attacker.receive()
                       |
                       | re-enters
                       ↓
                vault.withdraw()
                       |
                       ↓
             attacker.receive()
                       |
                     ...
```

During each reentrant call, the attacker's balance is still the original non-zero value because the **balance update has not yet occurred**.

### Vulnerable Pattern

```text
1. Check      → Verify user's balance
2. Interaction → Send ETH to attacker
3. Effect     → Update user's balance
```

Use **Openzeppelin NonReentrant** modifier to prevent attacker from reentering vulnerable function.

<br>

## 2. Cross-Function Reentrancy Attack

A **cross-function reentrancy attack** occurs when an attacker re-enters a **different function** that accesses or modifies the same shared state as the vulnerable function.

Unlike classic single-function reentrancy, the attacker does not need to call the same function again.

Even if the vulnerable function is protected with a **`nonReentrant` guard**, the attack may still be possible if another function that accesses the same state is **not protected**.

For example, suppose `withdraw()` sends ETH through an external call before completing its state updates. During this external call, the attacker's contract can re-enter the vault through another function such as `transfer()` and modify the same balance mapping.

### Attack Flow

```text
                  Attacker Contract
                         |
                         | vault.withdraw()
                         ↓
                    Vault Contract
                         |
                         | sends ETH
                         ↓
                  attacker.receive()
                         |
                         | re-enter another function
                         ↓
                    vault.transfer()
                         |
                         | modifies shared balance state
                         ↓
              attacker.receive() returns
                         |
                         ↓
                 withdraw() completes
                         |
                         ↓
              inconsistent balance/accounting
```

### Why `nonReentrant` May Not Be Enough

Consider:

```text
withdraw()     → protected by nonReentrant
transfer()     → not protected
      ↓
Both functions access the same balance state
```

When `withdraw()` makes an external call, the attacker can use the callback to call `transfer()`.

The `nonReentrant` guard prevents re-entering **`withdraw()` itself**, but it does not necessarily prevent execution of an **unguarded `transfer()`**.

If `transfer()` modifies state that `withdraw()` has not yet finished updating, the attacker may cause the contract's accounting to become inconsistent.

### Core Root Cause

The vulnerability occurs when:

**External Call → Re-entry into another function → Shared state modified → Original function continues using stale/inconsistent state**

Therefore, when auditing for cross-function reentrancy, don't only check whether individual functions have `nonReentrant`. Check whether **multiple functions share critical state and can be called during an external interaction**.

<br>

## 3. Cross-Contract Reentrancy Attack

A **cross-contract reentrancy attack** occurs when an attacker re-enters one contract through an external call and exploits **another contract that shares, depends on, or can affect the state of the first contract**.

The important point is that the vulnerable state may be distributed across **multiple contracts**.

For example, suppose a `Vault` contract interacts with a `Token` contract. During a withdrawal, the `Vault` makes an external call to the `Token` contract. The attacker's contract can use a callback to interact with another contract or protocol component before the original operation has completed.

### Attack Flow

```text
                    Attacker Contract
                           |
                           | vault.withdraw()
                           ↓
                       Vault A
                           |
                           | external call
                           ↓
                       Contract B
                           |
                           | callback / external interaction
                           ↓
                    Attacker Contract
                           |
                           | calls another function
                           ↓
                       Contract B
                           |
                           | modifies shared/dependent state
                           ↓
                       Vault A
                           |
                           ↓
                    withdraw() completes
                           |
                           ↓
                 Inconsistent accounting
```

### Example Scenario

Consider two contracts:

```text
Vault
  |
  | manages user deposits
  |
  └──── interacts with ────→ Token / Strategy Contract
                                  |
                                  └──── callback / external call
                                           ↓
                                      Attacker
```

The attacker may exploit the interaction between these contracts if:

* Contract A makes an external call to Contract B.
* Contract B can indirectly trigger a callback or another external interaction.
* The attacker can exploit Contract A or B before the original operation finishes.
* Critical state or accounting has not yet been updated.

### Difference from Cross-Function Reentrancy

```text
Single-Function Reentrancy
    withdraw()
       ↓
    withdraw()
       ↓
    same function


Cross-Function Reentrancy
    withdraw()
       ↓
    transfer()
       ↓
    different function
    in the same contract


Cross-Contract Reentrancy
    Contract A
       ↓
    Contract B
       ↓
    Contract A / C
       ↓
    exploit shared or dependent state
```

### Important Audit Point

**`nonReentrant` must be considered at the contract/system level, not just at the individual function level.**

A guard on one contract or function does not automatically make an entire multi-contract protocol reentrancy-safe.

When auditing cross-contract interactions, trace:

**Contract A → external Contract B → callback/interaction → Contract A or Contract C → state/accounting affected**

The root cause is usually an **unsafe external interaction combined with state that remains temporarily inconsistent or assumptions that become invalid during re-entry**.


## The safest pattern is:

```text
1. Check      → Verify user's balance
2. Effect     → Update user's balance
3. Interaction → Send ETH to attacker
```

This follows the **Checks → Effects → Interactions (CEI)** pattern and prevents the attacker from repeatedly withdrawing against the same unchanged balance.