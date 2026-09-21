reentrancy-exploit:; forge test --match-path test/exploit/Reentrancy/ReentrancyExploitTest.t.sol

reentrancy-fixed:; forge test --match-path test/fixed/Reentrancy/ReentrancyMitigationTest.t.sol

access-exploit:; forge test --match-path test/exploit/Access-Control/AccessControlExploitTest.t.sol