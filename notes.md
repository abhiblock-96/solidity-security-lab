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


# Access Control Security Notes

## 1. Missing Access Control

A **missing access control vulnerability** occurs when a sensitive function can be called by an unauthorized account because the contract does not properly verify **who is allowed to perform the operation**.

The vulnerability commonly affects functions that can:

* Transfer ownership
* Withdraw funds
* Mint or burn tokens
* Change protocol configuration
* Update prices or oracles
* Pause or unpause contracts
* Upgrade implementations
* Modify critical accounting

The key issue is:

> **The contract performs a privileged state-changing operation without verifying that `msg.sender` has the required authority.**

### Example

Suppose a vault has an `owner` variable and exposes:

```text
transferOwnership()
withdraw()
```

If neither function checks whether the caller is authorized, the existence of the `owner` variable provides no actual security.

### Attack Flow

```text
                    Attacker
                       |
                       | calls privileged function
                       ↓
                 Vulnerable Contract
                       |
                       | missing authorization check
                       ↓
              privileged operation
                       |
             ┌─────────┴─────────┐
             ↓                   ↓
      Change ownership      Withdraw funds
             |                   |
             ↓                   ↓
       Attacker becomes      Vault loses
            owner              ETH
```

### Common Examples

```text
Missing authorization
        ↓
┌─────────────────────────────────┐
│ mint()                          │
│ burn()                          │
│ withdraw()                      │
│ transferOwnership()             │
│ setPrice()                      │
│ setOracle()                     │
│ pause()                         │
│ upgrade()                       │
└─────────────────────────────────┘
        ↓
Unauthorized state change
```

### Example: Unauthorized Minting

If `mint()` does not restrict the caller:

```text
Attacker
   |
   | mint(Attacker, largeAmount)
   ↓
Token Contract
   |
   | no authorization check
   ↓
Tokens created
   |
   ↓
Attacker receives unbacked tokens
```

If another protocol treats those tokens as having economic value, the attacker may use them to extract real assets.

### Example: Unauthorized Burning

If `burn(account, amount)` does not verify authorization:

```text
Attacker
   |
   | burn(Victim, amount)
   ↓
Token Contract
   |
   | no authorization check
   ↓
Victim balance decreases
```

The attacker does not need to own the victim's tokens if the token contract incorrectly allows arbitrary callers to burn them.

### Example: Unauthorized Withdrawal

```text
Attacker
   |
   | withdraw()
   ↓
Vault
   |
   | no owner check
   ↓
Vault ETH transferred
   |
   ↓
Attacker receives funds
```

### Root Cause

The root cause is:

> **A privileged capability exists without an enforced authorization boundary.**

A useful audit question is:

> **Who should be able to call this function, and where is that restriction enforced?**

Do not assume that the presence of an `owner`, `admin`, or `role` variable automatically provides access control.

The authorization must be enforced on the sensitive state transition itself.

---

## 2. Role-Based Access Control (RBAC)

**Role-Based Access Control (RBAC)** restricts sensitive operations according to explicitly defined roles rather than giving every privileged operation to a single owner.

Instead of:

```text
Owner
  |
  ├── mint
  ├── burn
  ├── pause
  ├── upgrade
  └── change configuration
```

RBAC can separate privileges:

```text
                    Admin
                      |
          ┌───────────┼───────────┐
          ↓           ↓           ↓
       MINTER       BURNER      PAUSER
          |           |           |
          ↓           ↓           ↓
        mint()      burn()      pause()
```

The key idea is:

> **An account should receive only the permissions required to perform its intended responsibilities.**

### Example Role Model

```text
ADMIN_ROLE
    |
    ├── manages roles
    |
    ├────────→ MINTER_ROLE
    |              |
    |              ↓
    |            mint()
    |
    ├────────→ BURNER_ROLE
    |              |
    |              ↓
    |            burn()
    |
    └────────→ PAUSER_ROLE
                   |
                   ↓
                 pause()
```

For a protocol with a shop/vault contract:

```text
Admin
  |
  | grants SHOP_ROLE
  ↓
Shop / Vault
  |
  ├── mint()
  └── burn()
```

Users should not automatically receive `SHOP_ROLE`.

### Authorized Flow

```text
Admin
  |
  | grant SHOP_ROLE
  ↓
Shop Contract
  |
  | mint()
  ↓
Token Contract
  |
  | verify SHOP_ROLE
  ↓
Mint succeeds
```

### Unauthorized Flow

```text
Attacker
   |
   | mint()
   ↓
Token Contract
   |
   | check SHOP_ROLE
   ↓
No role
   |
   ↓
Transaction reverts
```

### Why RBAC Is Useful

RBAC provides **least-privilege authorization**.

For example:

```text
MINTER
   ↓
Can mint

BURNER
   ↓
Can burn

PAUSER
   ↓
Can pause

UPGRADER
   ↓
Can upgrade
```

A minter does not automatically need permission to upgrade the entire protocol.

This reduces the number of capabilities available to each account.

---

## 3. Role Administration Is Also an Attack Surface

RBAC introduces another important security boundary:

> **Who can grant, revoke, or administer a role?**

Consider:

```text
Attacker
   |
   | obtains role-admin privilege
   ↓
Role Manager
   |
   | grantRole(MINTER_ROLE, attacker)
   ↓
Attacker
   |
   ↓
mint()
```

The token's `mint()` function may correctly check `MINTER_ROLE`, but the system is still vulnerable if an unauthorized account can obtain that role.

Therefore, when auditing RBAC, do not only inspect:

```text
hasRole(MINTER_ROLE, msg.sender)
```

Also inspect:

```text
Who can grant MINTER_ROLE?
Who can revoke MINTER_ROLE?
Who administers that role?
Who can change the role administrator?
Can an existing role grant a more powerful role?
Can roles be escalated?
```

### Role Escalation

A common privilege-escalation pattern is:

```text
Low-Privilege Role
        |
        | can modify role administration
        ↓
Higher-Privilege Role
        |
        ↓
Admin / Upgrader
        |
        ↓
Complete protocol control
```

The important audit principle is:

> **A role is only as secure as the mechanism that controls who receives that role.**

---

## 4. Ownership vs Role-Based Access Control

Ownership provides a relatively simple authorization model:

```text
Owner
  |
  └── privileged functions
```

RBAC separates privileges:

```text
Admin
 |
 ├── Minter
 ├── Burner
 ├── Pauser
 └── Upgrader
```

### Ownership

Useful when:

```text
One trusted authority
        ↓
controls protocol
```

### RBAC

Useful when:

```text
Multiple responsibilities
        ↓
different permissions
        ↓
least privilege
```

The important security question is not:

> **"Should I use Ownable or AccessControl?"**

Instead ask:

> **"What capabilities exist, who needs each capability, and how is that authority granted and revoked?"**

---

## 5. Access-Control Audit Checklist

When auditing access control, identify every sensitive function:

```text
mint()
burn()
withdraw()
pause()
unpause()
upgrade()
initialize()
setOracle()
setPrice()
setFee()
setTreasury()
transferOwnership()
grantRole()
revokeRole()
```

For each function ask:

```text
Who can call it?
        ↓
Who should call it?
        ↓
Where is authorization checked?
        ↓
What capability does it provide?
        ↓
What state can it modify?
        ↓
Can another function achieve the same result?
        ↓
Can privileges be escalated?
        ↓
Who controls the authorization mechanism?
```