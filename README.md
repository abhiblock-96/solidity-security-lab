# Solidity Security Lab

Hands-on Solidity smart contract security research and experimentation using **Foundry**.

This repository contains vulnerable smart contracts, exploit Proofs of Concept (PoCs), Foundry tests, security findings, and mitigation analysis.

## 🎯 Goals

* Understand common smart contract vulnerabilities
* Build practical exploit PoCs
* Write adversarial Foundry tests
* Analyze vulnerability impact and root causes
* Study and implement security mitigations
* Develop practical smart contract auditing skills

## 🏗️ Structure

```text
solidity-security-lab/
│
├── src/          # Vulnerable and fixed contracts
├── test/         # Exploit PoCs and security tests
├── findings/     # Security findings and reports
├── notes.md      # Security research notes
│
├── foundry.toml
├── Makefile
└── README.md
```

## 🧰 Tools

* Solidity
* Foundry
* OpenZeppelin Contracts
* GitHub Actions

## 🔬 Approach

Each vulnerability is studied through:

```text
Understand
    ↓
Identify
    ↓
Exploit
    ↓
Test
    ↓
Document
    ↓
Mitigate
```

The goal is to reproduce vulnerabilities in a controlled environment and understand their underlying security assumptions rather than only learning vulnerability definitions.

## ▶️ Getting Started

Clone the repository:

```bash
git clone https://github.com/abhiblock-96/solidity-security-lab.git
cd solidity-security-lab
```

Install dependencies:

```bash
forge install
```

Build:

```bash
forge build
```

Run tests:

```bash
forge test
```

Run tests with traces:

```bash
forge test -vvvv
```

## ⚠️ Disclaimer

This repository is intended for **educational and defensive security research purposes**.

The vulnerable contracts are intentionally insecure and should not be deployed with real funds or used against systems without authorization.

---

*This repository is actively evolving as I continue studying and researching smart contract security.*
