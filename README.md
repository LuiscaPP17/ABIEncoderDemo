# ABIEncoderDemo

## Overview

**ABIEncoderDemo** is a Solidity contract that shows how `abi.encodePacked` and `keccak256` are used to build identifiers and payloads in DeFi protocols.

Each function takes the kind of data a real protocol works with (pools, swaps, limit orders, flash loans, staking configs, bridge transfers, stop-loss and take-profit orders) and packs it into a compact byte string, a hash, or both. The contract has no storage and holds no funds: every function is `pure` or `view`, so the focus stays on *how the data is encoded*, not on state.

The test suite checks every function against an independently computed expected value (never against the contract's own output), covers the single `require` path, and reaches 100% coverage. Writing those expected values by hand surfaced a real bug in the contract (see below).

## How it works

- [`ABIEncoderDemo.sol`](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol) — the contract under test
- [`ABIEncoderDemo.t.sol`](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/test/ABIEncoderDemo.t.sol) — the Foundry test suite

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

### `createPoolIdentifier`
[Check function](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol#L23-L29)

```solidity
/**
 * @dev This function encodes the pool parameters
 * @param tokenA first pool token
 * @param tokenB second pool token
 * @param fee pool fee
 * @return poolId identifier (unique for this pool)
 */
function createPoolIdentifier(address tokenA, address tokenB, uint24 fee) external pure returns (bytes32 poolId) {
    // We order the tokens
    (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

    // Use of ABI.ENCODEPACKED: Create unique pool identifier
    poolId = keccak256(abi.encodePacked(token0, token1, fee));
}
```

### `encodeTradingPosition`
[Check function](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol#L41-L53)

```solidity
/**
 * @dev Encodes data for a trading position
 * @param user User address
 * @param tokenIn Input token
 * @param tokenOut Output token
 * @param amountIn Input amount
 * @param minAmountOut Minimum output amount
 * @return positionId Position identifier
 * @return encodedData Encoded position data
 */
function encodeTradingPosition(
    address user,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 minAmountOut
) external view returns (bytes32 positionId, bytes memory encodedData) {
    // Encoded the position data
    encodedData = abi.encodePacked(user, tokenIn, tokenOut, amountIn, minAmountOut, block.timestamp);

    // Create unique identifier for the position
    positionId = keccak256(encodedData);
}
```

### `encodeSwapData`
[Check function](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol#L62-L83)

```solidity
/**
 * @dev Encodes parameters for a swap on a DEX
 * @param path Array of tokens for the swap
 * @param amount Array of amounts
 * @param deadline Transaction deadline
 * @return swapData Encode swap data
 */
function encodeSwapData(address[] calldata path, uint256[] calldata amount, uint256 deadline)
    external
    pure
    returns (bytes memory swapData)
{
    require(path.length == amount.length, "Array length mismatch");

    // Encode the path
    bytes memory pathData;
    for (uint256 i = 0; i < path.length; i++) {
        pathData = abi.encodePacked(pathData, path[i]);
    }

    // Encode the amount
    bytes memory amountData;
    for (uint256 i = 0; i < path.length; i++) {
        amountData = abi.encodePacked(amountData, amount[i]);
    }

    // Combine everything
    swapData = abi.encodePacked(pathData, amountData, deadline);
}
```

### `encodeLimitOrder`
[Check function](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol#L97-L111)

```solidity
/**
 * @dev Encodes data for a limit order
 * @param maker Maker address
 * @param taker Taker address
 * @param tokenIn Input token
 * @param tokenOut Output token
 * @param amountIn Input amount
 * @param amountOut Output amount
 * @param nonce Unique nonce
 * @return orderHash Order hash
 * @return orderData Encoded order data
 */
function encodeLimitOrder(
    address maker,
    address taker,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOut,
    uint256 nonce
) external pure returns (bytes32 orderHash, bytes memory orderData) {
    // Encode the order data
    orderData = abi.encodePacked(maker, taker, tokenIn, tokenOut, amountIn, amountOut, nonce, "LIMIT_ORDER_V1");

    // Create the order hash
    orderHash = keccak256(orderData);
}
```

### `encodeYieldPosition`
[Check function](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol#L121-L127)

```solidity
/**
 * @dev Encodes data for a yield farming position
 * @param user User address
 * @param poolId Pool identifier
 * @param amount Staked amount
 * @param startTime Start time
 * @return positionId Position identifier
 */
function encodeYieldPosition(address user, bytes32 poolId, uint256 amount, uint256 startTime)
    external
    pure
    returns (bytes32 positionId)
{
    positionId = keccak256(abi.encodePacked(user, poolId, amount, startTime, "YIELD_POSITION"));
}
```

### `encodeFlashLoanData`
[Check function](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol#L136-L142)

```solidity
/**
 * @dev Encodes data for a flash loan
 * @param token Flash loan token
 * @param amount Loan amount
 * @param callbackData Callback data
 * @return flashData Encoded flash loan
 */
function encodeFlashLoanData(address token, uint256 amount, bytes calldata callbackData)
    external
    pure
    returns (bytes memory flashData)
{
    flashData = abi.encodePacked(token, amount, callbackData, "FLASH_LOAN_V1");
}
```

### `encodeStakingPoolConfig`
[Check function](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol#L152-L158)

```solidity
/**
 * @dev Encodes parameters for a staking pool
 * @param token Token address
 * @param rewardRate Reward rate
 * @param lockPeriod Lock period
 * @param maxStakers Maximum number of stakers
 * @return poolConfig Encoded configuration data
 */
function encodeStakingPoolConfig(address token, uint256 rewardRate, uint256 lockPeriod, uint256 maxStakers)
    external
    view
    returns (bytes memory poolConfig)
{
    poolConfig = abi.encodePacked(token, rewardRate, lockPeriod, maxStakers, block.timestamp);
}
```

### `createUserMultiPoolHash`
[Check function](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol#L166-L178)

```solidity
/**
 * @dev Creates a unique hash for a user across multiple pools
 * @param user User address
 * @param poolIds Array of pool identifiers
 * @return userHash Unique user hash
 */
function createUserMultiPoolHash(address user, bytes32[] calldata poolIds)
    external
    pure
    returns (bytes32 userHash)
{
    bytes memory data = abi.encodePacked(user);
    for (uint256 i = 0; i < poolIds.length; i++) {
        data = abi.encodePacked(data, poolIds[i]);
    }

    data = abi.encodePacked(data, "MULTI_POOL_USER");
    userHash = keccak256(data);
}
```

### `encodeYieldStrategy`
[Check function](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol#L187-L211)

```solidity
/**
 * @dev Encodes data for a yield farming strategy
 * @param strategyName Name of the strategy
 * @param pools Array of involved pools
 * @param weights Array of weights for each pool
 * @return strategyData Encoded strategy data
 */
function encodeYieldStrategy(string calldata strategyName, address[] calldata pools, uint256[] calldata weights)
    external
    pure
    returns (bytes memory strategyData)
{
    require(pools.length == weights.length, "Arrays length mismatch");

    // Encode strategy name
    bytes memory nameData = abi.encodePacked(strategyName);

    // Encode pools
    bytes memory poolsData;
    for (uint256 i = 0; i < pools.length; i++) {
        poolsData = abi.encodePacked(poolsData, pools[i]);
    }

    // Encode weights
    bytes memory weightsData;
    for (uint256 i = 0; i < weights.length; i++) {
        weightsData = abi.encodePacked(weightsData, weights[i]);
    }

    // Combine everything
    strategyData = abi.encodePacked(nameData, poolsData, weightsData, "YIELD_STRATEGY_V1");
}
```

### `encodeCrossChainBridgeData`
[Check function](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol#L222-L230)

```solidity
/**
 * @dev Demonstrates encoding data for a cross-chain bridge
 * @param sourceChain Source chain
 * @param targetChain Target chain
 * @param token Token to transfer
 * @param amount Amount
 * @param recipient Recipient
 * @return bridgeData Encoded bridge data
 */
function encodeCrossChainBridgeData(
    uint256 sourceChain,
    uint256 targetChain,
    address token,
    uint256 amount,
    address recipient
) external pure returns (bytes memory bridgeData) {
    bridgeData = abi.encodePacked(sourceChain, targetChain, token, amount, recipient, "CROSS_CHAIN_BRIDGE");
}
```

### `createDeFiTransactionId`
[Check function](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol#L240-L246)

```solidity
/**
 * @dev Creates a unique identifier for a DeFi transaction
 * @param txType Transaction type
 * @param user User
 * @param timestamp Timestamp
 * @param nonce Unique nonce
 * @return txId Unique transaction identifier
 */
function createDeFiTransactionId(string calldata txType, address user, uint256 timestamp, uint256 nonce)
    external
    pure
    returns (bytes32 txId)
{
    txId = keccak256(abi.encodePacked(txType, user, timestamp, nonce, "DEFI_TX"));
}
```

### `encodeStopLossOrder`
[Check function](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol#L257-L263)

```solidity
/**
 * @dev Encodes data for a stop loss order
 * @param user User address
 * @param token Token to sell
 * @param amount Amount to sell
 * @param stopPrice Stop loss price
 * @param triggerPrice Trigger price
 * @return stopLossData Encoded order data
 */
function encodeStopLossOrder(address user, address token, uint256 amount, uint256 stopPrice, uint256 triggerPrice)
    external
    pure
    returns (bytes memory stopLossData)
{
    stopLossData = abi.encodePacked(user, token, amount, stopPrice, triggerPrice, "STOP_LOSS_ORDER");
}
```

### `encodeTakeProfitOrder`
[Check function](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol#L273-L279)

```solidity
/**
 * @dev Encodes data for a take profit order
 * @param user User address
 * @param token Token to sell
 * @param amount Amount to sell
 * @param takeProfitPrice Take profit price
 * @return takeProfitData Encoded order data
 */
function encodeTakeProfitOrder(address user, address token, uint256 amount, uint256 takeProfitPrice)
    external
    pure
    returns (bytes memory takeProfitData)
{
    takeProfitData = abi.encodePacked(user, token, amount, takeProfitPrice, "TAKE_PROFIT_ORDER");
}
```

### `encodeTrailingStopOrder`
[Check function](https://github.com/LuiscaPP17/ABIEncoderDemo/blob/main/src/ABIEncoderDemo.sol#L290-L300)

```solidity
/**
 * @dev Encodes data for a trailing stop order
 * @param user User address
 * @param token Token to sell
 * @param amount Amount to sell
 * @param trailingPercent Trailing percentage
 * @param activationPrice Activation price
 * @return trailingStopData Encoded order data
 */
function encodeTrailingStopOrder(
    address user,
    address token,
    uint256 amount,
    uint256 trailingPercent,
    uint256 activationPrice
) external pure returns (bytes memory trailingStopData) {
    trailingStopData = abi.encodePacked(
        user, token, amount, trailingPercent, activationPrice, "TRAILING_STOP_ORDER"
    );
}
```

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
