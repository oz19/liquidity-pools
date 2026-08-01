// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

import "./interfaces/IV2Router02.sol";


contract SwapApp {

    address public v2Router02Address;

    constructor(address v2Router02Address_) {
        v2Router02Address = v2Router02Address_;
    }

    // function swappTokens() external {

    //     IV2Router02(v2Router02Address).swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);

    // }

}