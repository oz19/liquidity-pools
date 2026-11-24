// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

/**
 * @title IUniswapV2Factory
 * @notice Minimal interface for a Uniswap V2-compatible factory.
 */
interface IUniswapV2Factory {

    /**
     * @notice Returns the pair address for two tokens, or address(0) if none exists.
     * @param tokenA Address of the first token.
     * @param tokenB Address of the second token.
     * @return pair The pair contract address.
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair);

}
