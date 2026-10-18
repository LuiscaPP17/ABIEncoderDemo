// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/ABIEncoderDemo.sol";

/// @title ABIEncoderDemoTest
/// @notice Comprehensive tests targeting 100% coverage for ABIEncoderDemo
contract ABIEncoderDemoTest is Test {
    ABIEncoderDemo private demo;

    /// @dev Deply a fresh contract before each test
    function setUp() external {
        demo = new ABIEncoderDemo();
    }

    /// @dev PPol id must be invariant to token ordering (tokens are sorted internally)
    function test_createPoolIdentifier_SameForBothTokenOrders() external view {
        address tokenA = address(0x1000);
        address tokenB = address(0x2000);
        uint24 fee = 3000;

        bytes32 idAB = demo.createPoolIdentifier(tokenA, tokenB, fee);
        bytes32 idBA = demo.createPoolIdentifier(tokenB, tokenA, fee);

        bytes32 expected = keccak256(abi.encodePacked(tokenA, tokenB, fee));

        assertEq(idAB, idBA, "Tokens are not correctly sorted");
        assertEq(idAB, expected, "Pool ID does not match expected hash");
    }

    function test_createPoolIdentifier_DifferentFeeDifferentId() external view {
        address tokenA = address(0x1000);
        address tokenB = address(0x2000);
        uint24 fee0 = 3000;
        uint24 fee1 = 500;

        bytes32 idLow = demo.createPoolIdentifier(tokenA, tokenB, fee0);
        bytes32 idHigh = demo.createPoolIdentifier(tokenB, tokenA, fee1);

        assertTrue(idLow != idHigh, "Different fees must yield different ids");
    }

    function test_encodeTradingPosition_ReturnsExpectedDataHash() external {
        address user = address(0x1234);
        address tokenIn = address(0xA1);
        address tokenOut = address(0xB2);
        uint256 amountIn = 1 ether;
        uint256 minAmountOut = 2 ether;

        // Freeze block timestamp to a known value
        uint256 fixedTs = 1_700_000_000;
        vm.warp(fixedTs);

        (bytes32 positionId, bytes memory encodedData) =
            demo.encodeTradingPosition(user, tokenIn, tokenOut, amountIn, minAmountOut);

        bytes memory expected = abi.encodePacked(user, tokenIn, tokenOut, amountIn, minAmountOut, fixedTs);

        assertEq(encodedData, expected, "Encoded trading position mismatch");
        assertEq(positionId, keccak256(expected), "Position id must be keccak of encodedData");
    }

    function test_encodeSwapData_EncodesPathDeadline() external view {
        address[] memory path = new address[](3);
        path[0] = address(0x1);
        path[1] = address(0x2);
        path[2] = address(0x3);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 10;
        amounts[1] = 10;
        amounts[2] = 10;

        uint256 deadline = 999;

        bytes memory pathData;
        for (uint256 i; i < path.length; i++) {
            pathData = abi.encodePacked(pathData, path[i]);
        }

        bytes memory amountsData;
        for (uint256 i; i < path.length; i++) {
            amountsData = abi.encodePacked(amountsData, amounts[i]);
        }

        bytes memory expected = abi.encodePacked(pathData, amountsData, deadline);
        bytes memory actual = demo.encodeSwapData(path, amounts, deadline);

        assertEq(expected, actual, "Swap data encoding mismatch");
    }

    function test_encodeSwapData_RevertsOnLengthMismatch() external {
        address[] memory path = new address[](2);
        path[0] = address(0x1);
        path[1] = address(0x2);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;

        vm.expectRevert(abi.encodeWithSignature("Error(string)", "Array length mismatch"));
        demo.encodeSwapData(path, amounts, 123);
    }

    function test_encodeLimitOrder_ReturnsExpectedDataAndHash() external view {
        address maker = address(0x1000);
        address taker = address(0x2000);
        address tokenIn = address(0x3000);
        address tokenOut = address(0x4000);
        uint256 amountIn = 1 ether;
        uint256 amountOut = 2 ether;
        uint256 nonce = 7;

        (bytes32 orderHash, bytes memory orderData) =
            demo.encodeLimitOrder(maker, taker, tokenIn, tokenOut, amountIn, amountOut, nonce);

        bytes memory expected =
            abi.encodePacked(maker, taker, tokenIn, tokenOut, amountIn, amountOut, nonce, "LIMIT_ORDER_V1");

        assertEq(orderData, expected, "Limit order data does not match expected packed encoding");
        assertEq(orderHash, keccak256(expected), "Limit order hash does not match keccak256 of expected data");
        assertEq(orderData.length, 190, "Unexpected packed length");
    }

    function test_encodeYieldPosition_ReturnsExpectedHash() external view {
        address user = address(0x1000);
        bytes32 poolId = keccak256("pool");
        uint256 amount = 1 ether;
        uint256 startTime = 1_700_000_000;

        bytes32 positionId = demo.encodeYieldPosition(user, poolId, amount, startTime);

        bytes memory expected = abi.encodePacked(user, poolId, amount, startTime, "YIELD_POSITION");

        assertEq(positionId, keccak256(expected), "Yield position ID does not match expected hash");
    }

    function test_encodeFlashLoanData_ReturnsExpectedData() external view {
        address token = address(0x1000);
        uint256 amount = 1 ether;
        bytes memory callbackData = hex"deadbeef";

        bytes memory flashData = demo.encodeFlashLoanData(token, amount, callbackData);

        bytes memory expected = abi.encodePacked(token, amount, callbackData, "FLASH_LOAN_V1");

        assertEq(flashData, expected, "Flash loan data does not match expected packed encoding");
        assertEq(flashData.length, 69, "Packed flash loan data length should be 69 bytes");
    }

    function test_encodeStakingPoolConfig_ReturnsExpectedData() external {
        address token = address(0x1000);
        uint256 rewardRate = 1 ether;
        uint256 lockPeriod = 30 days;
        uint256 maxStakers = 100;

        uint256 fixedTs = 1_700_000_000;
        vm.warp(fixedTs);

        bytes memory poolConfig = demo.encodeStakingPoolConfig(token, rewardRate, lockPeriod, maxStakers);

        bytes memory expected = abi.encodePacked(token, rewardRate, lockPeriod, maxStakers, fixedTs);

        assertEq(poolConfig, expected, "Packed staking pool config does not match expected packed encoding");
        assertEq(poolConfig.length, 148, "Packed staking pool config length should be 148 bytes");
    }

    function test_createUserMultiPoolHash_ReturnsExpectedHash() external view {
        address user = address(0x1000);

        bytes32[] memory poolIds = new bytes32[](2);
        poolIds[0] = keccak256("pool1");
        poolIds[1] = keccak256("pool2");

        bytes32 userHash = demo.createUserMultiPoolHash(user, poolIds);

        bytes32 expected = keccak256(abi.encodePacked(user, poolIds[0], poolIds[1], "MULTI_POOL_USER"));

        assertEq(userHash, expected, "User multi-pool hash does not match expected");
    }

    function test_encodeYieldStrategy_ReturnsExpectedData() external view {
        string memory strategyName = "StableYield";

        address[] memory pools = new address[](2);
        pools[0] = address(0x1000);
        pools[1] = address(0x2000);

        uint256[] memory weights = new uint256[](2);
        weights[0] = 6_000; // 60.00 %
        weights[1] = 4_000; // 40.00 %

        bytes memory strategyData = demo.encodeYieldStrategy(strategyName, pools, weights);

        bytes memory expected =
            abi.encodePacked(strategyName, pools[0], pools[1], weights[0], weights[1], "YIELD_STRATEGY_V1");

        assertEq(strategyData.length, 132, "Yield strategy length should be 132 bytes");
        assertEq(strategyData, expected, "Yield strategy does not match expected packed encoding");
    }

    function test_encodeYieldStrategy_RevertsOnLengthMismatch() external {
        string memory strategyName = "StableYield";

        address[] memory pools = new address[](2);
        pools[0] = address(0x1000);
        pools[1] = address(0x2000);

        uint256[] memory weights = new uint256[](3);
        weights[0] = 6_000;
        weights[1] = 2_000;
        weights[2] = 2_000;

        vm.expectRevert(abi.encodeWithSignature("Error(string)", "Arrays length mismatch"));
        demo.encodeYieldStrategy(strategyName, pools, weights);
    }

    function test_encodeCrossChainBridgeData_ReturnsExpectedData() external view {
        uint256 sourceChain = 42161; // Arbitrum One
        uint256 targetChain = 1; // Ethereum mainnet
        address token = address(0x1000);
        uint256 amount = 1 ether;
        address recipient = address(0x2000);

        bytes memory bridgeData = demo.encodeCrossChainBridgeData(sourceChain, targetChain, token, amount, recipient);

        bytes memory expected =
            abi.encodePacked(sourceChain, targetChain, token, amount, recipient, "CROSS_CHAIN_BRIDGE");

        assertEq(bridgeData.length, 154, "Cross chain bridge data should be 154 bytes");
        assertEq(bridgeData, expected, "Cross chain bridge data does not match expected packed encoding");
    }

    function test_createDeFiTransactionId_ReturnsExpectedHash() external view {
        string memory txType = "SWAP";
        address user = address(0x1000);
        uint256 timestamp = 1_700_000_000;
        uint256 nonce = 1;

        bytes32 txId = demo.createDeFiTransactionId(txType, user, timestamp, nonce);

        bytes32 expected = keccak256(abi.encodePacked(txType, user, timestamp, nonce, "DEFI_TX"));

        assertEq(txId, expected, "DeFi transaction id does not match expected hash");
    }

    function test_encodeStopLossOrder_ReturnsExpectedData() external view {
        address user = address(0x1000);
        address token = address(0x2000);
        uint256 amount = 1 ether;
        uint256 stopPrice = 1_800 ether;
        uint256 triggerPrice = 1_900 ether;

        bytes memory stopLossData = demo.encodeStopLossOrder(user, token, amount, stopPrice, triggerPrice);

        bytes memory expected = abi.encodePacked(user, token, amount, stopPrice, triggerPrice, "STOP_LOSS_ORDER");

        assertEq(stopLossData.length, 151, "Stop loss data should be 151 bytes");
        assertEq(stopLossData, expected, "Stop loss data does not match expected packed encoding");
    }

    function test_encodeTakeProfitOrder_ReturnsExpectedData() external view {
        address user = address(0x1000);
        address token = address(0x2000);
        uint256 amount = 1 ether;
        uint256 takeProfitPrice = 2_500 ether;

        bytes memory takeProfitData = demo.encodeTakeProfitOrder(user, token, amount, takeProfitPrice);

        bytes memory expected = abi.encodePacked(user, token, amount, takeProfitPrice, "TAKE_PROFIT_ORDER");

        assertEq(takeProfitData.length, 121, "Take profit data should be 121 bytes");
        assertEq(takeProfitData, expected, "Take profit data does not match expected packed encoding");
    }

    function test_encodeTrailingStopOrder_ReturnsExpectedData() external view {
        address user = address(0x1000);
        address token = address(0x2000);
        uint256 amount = 1 ether;
        uint256 trailingPercent = 5;
        uint256 activationPrice = 2_000 ether;

        bytes memory trailingStopData =
            demo.encodeTrailingStopOrder(user, token, amount, trailingPercent, activationPrice);

        bytes memory expected =
            abi.encodePacked(user, token, amount, trailingPercent, activationPrice, "TRAILING_STOP_ORDER");

        assertEq(trailingStopData.length, 155, "Trailing stop data should be 155 bytes");
        assertEq(trailingStopData, expected, "Trailing stop data does not match expected packed encoding");
    }
}
