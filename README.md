# ABIEncoderDemo

## Overview

**ABIEncoderDemo** is a Solidity contract that shows how `abi.encodePacked` and `keccak256` are used to build identifiers and payloads in DeFi protocols.

Each function takes the kind of data a real protocol works with (pools, swaps, limit orders, flash loans, staking configs, bridge transfers, stop-loss and take-profit orders) and packs it into a compact byte string, a hash, or both. The contract has no storage and holds no funds: every function is `pure` or `view`, so the focus stays on *how the data is encoded*, not on state.

The test suite checks every function against an independently computed expected value (never against the contract's own output), covers the single `require` path, and reaches 100% coverage. Writing those expected values by hand surfaced a real bug in the contract (see below).

## How it works

- [`ABIEncoderDemo.sol`](src/ABIEncoderDemo.sol) — the contract under test
- [`ABIEncoderDemo.t.sol`](test/ABIEncoderDemo.t.sol) — the Foundry test suite

Packed encoding concatenates values without padding or length prefixes: an `address` takes 20 bytes, a `uint256` or `bytes32` takes 32, and a string or `bytes` takes exactly its own length. The tests use this to also assert the exact byte length of each payload.

## Functions

| Function | What it encodes | Returns |
|---|---|---|
| `createPoolIdentifier` | Two tokens (sorted) and a fee | `bytes32` pool ID |
| `encodeTradingPosition` | User, tokens, amounts and `block.timestamp` | position ID and packed data |
| `encodeSwapData` | Token path, amounts and a deadline | packed bytes |
| `encodeLimitOrder` | Maker, taker, tokens, amounts, nonce | order hash and packed data |
| `encodeYieldPosition` | User, pool ID, amount, start time | `bytes32` position ID |
| `encodeFlashLoanData` | Token, amount, callback data | packed bytes |
| `encodeStakingPoolConfig` | Token, reward rate, lock period, max stakers, `block.timestamp` | packed bytes |
| `createUserMultiPoolHash` | A user and a list of pool IDs | `bytes32` hash |
| `encodeYieldStrategy` | Strategy name, pools and weights | packed bytes |
| `encodeCrossChainBridgeData` | Source/target chain, token, amount, recipient | packed bytes |
| `createDeFiTransactionId` | Transaction type, user, timestamp, nonce | `bytes32` ID |
| `encodeStopLossOrder` | User, token, amount, stop and trigger price | packed bytes |
| `encodeTakeProfitOrder` | User, token, amount, take-profit price | packed bytes |
| `encodeTrailingStopOrder` | User, token, amount, trailing %, activation price | packed bytes |

## Technical docs

*(Function-by-function documentation with links to the source: coming next.)*

## A bug found by testing

While writing the test for `encodeYieldStrategy`, the length check failed:

```
[FAIL: Yield strategy length should be 132 bytes: 196 != 132]
```

The difference was exactly 64 bytes, two `uint256` values too many. The cause was in the loop that packs the weights:

```solidity
// Before: appends the whole array on every iteration
weightsData = abi.encodePacked(weightsData, weights);

// After: appends one element per iteration
weightsData = abi.encodePacked(weightsData, weights[i]);
```

The contract compiled and ran without errors; only comparing against a hand-computed expected value exposed it. Two smaller fixes came from the same pass: a typo in the limit-order version tag (`"LIMIT_ORDER_V!"` → `"LIMIT_ORDER_V1"`) and a misspelled revert message.

## Usage Example

*(Pending — to be added if deployed to testnet or mainnet)*

## Contract addresses

*(Pending — to be added if deployed)*

## Tech

- Solidity 0.8.24
- Foundry
- `abi.encodePacked` / `keccak256`
- Cheatcodes: `vm.warp`, `vm.expectRevert`

## Testing

100% line, statement, branch and function coverage.

```
╭------------------------+-----------------+-----------------+---------------+-----------------╮
| File                   | % Lines         | % Statements    | % Branches    | % Funcs         |
+==============================================================================================+
| src/ABIEncoderDemo.sol | 100.00% (50/50) | 100.00% (49/49) | 100.00% (4/4) | 100.00% (14/14) |
|------------------------+-----------------+-----------------+---------------+-----------------|
| Total                  | 100.00% (50/50) | 100.00% (49/49) | 100.00% (4/4) | 100.00% (14/14) |
╰------------------------+-----------------+-----------------+---------------+-----------------╯
```
