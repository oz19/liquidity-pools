// SPDX-License-Identifier: MIT

// To `fork-test` in Arbitrum run these commands in the terminal (test and coverage):
// forge test -vvvv --fork-url https://arb1.arbitrum.io/rpc --match-test TEST_NAME
// forge coverage --fork-url https://arb1.arbitrum.io/rpc

pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../src/SwapApp.sol";


contract TestSwapApp is Test {

    SwapApp app;
    address v2Router02Address = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;  // Uniswap Router used to swap tokens
    address user = 0xa7A1fe8dDaDE572A76Cebd4c43B2c5ce38893Fde;  // Address with USDT in Arbitrum Mainnet
    address usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;  // USDT smart contract address in Arbitrum Mainnet
    address dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;  // DAI smart contract address in Arbitrum Mainnet

    function setUp() public {
        app = new SwapApp(v2Router02Address);
    }

    function testIsCorrectlyInitialized() public view {
        assert(app.v2Router02Address() == v2Router02Address);
    }

    function testSwapTokensCorrectly() public {
        vm.startPrank(user);

        uint256 usdtDecimals_ = 10 ** IERC20Metadata(usdt).decimals();
        uint256 amountIn = 5 * usdtDecimals_;
        IERC20(usdt).approve(address(app), amountIn);

        uint256 daiDecimals_ = 10 ** IERC20Metadata(dai).decimals();
        uint256 amountOutMin = 4 * daiDecimals_;

        uint256 deadline = block.timestamp + 30 days;

        address[] memory path = new address[](2);
        path[0] = usdt;
        path[1] = dai;

        uint256 usdtBefore = IERC20(usdt).balanceOf(user);
        uint256 daiBefore = IERC20(dai).balanceOf(user);

        app.swapTokens(amountIn, amountOutMin, path, deadline);

        uint256 usdtAfter = IERC20(usdt).balanceOf(user);
        uint256 daiAfter = IERC20(dai).balanceOf(user);

        assert(usdtAfter == usdtBefore - amountIn);
        assert(daiAfter > daiBefore);
        assert(daiAfter - daiBefore > amountOutMin);

        vm.stopPrank();
    }

}