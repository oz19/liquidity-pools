// SPDX-License-Identifier: MIT

// To `fork-test` in Arbitrum run this command in the terminal:
// forge test -vvvv --fork-url https://arb1.arbitrum.io/rpc --match-test TEST_NAME

pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../src/SwapApp.sol";


contract TestSwapApp is Test {

    SwapApp app;
    address v2Router02Address = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;

    function setUp() public {
        app = new SwapApp(v2Router02Address);
    }

    function testIsCorrectlyInitialized() public view {
        assert(app.v2Router02Address() == v2Router02Address);
    }

}