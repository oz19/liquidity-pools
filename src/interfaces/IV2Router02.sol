// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

/**
 * @title IV2Router02
 * @notice Minimal interface for a Uniswap V2-compatible router.
 */
interface IV2Router02 {

    /**
     * @notice Swaps an exact amount of input tokens for as many output tokens as possible.
     * @param amountIn The amount of input tokens to send.
     * @param amountOutMin The minimum amount of output tokens to receive.
     * @param path An array of token addresses representing the swap path.
     * @param to The recipient of the output tokens.
     * @param deadline Unix timestamp after which the transaction reverts.
     * @return amounts The amounts for each step in the path.
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    /**
     * @notice Adds liquidity to an ERC20/ERC20 pool.
     * @param tokenA Address of the first token.
     * @param tokenB Address of the second token.
     * @param amountADesired Desired amount of tokenA to add.
     * @param amountBDesired Desired amount of tokenB to add.
     * @param amountAMin Minimum amount of tokenA to add.
     * @param amountBMin Minimum amount of tokenB to add.
     * @param to Recipient of the LP tokens.
     * @param deadline Unix timestamp after which the transaction reverts.
     * @return amountA Actual tokenA added.
     * @return amountB Actual tokenB added.
     * @return liquidity LP tokens minted.
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    /**
     * @notice Removes liquidity from an ERC20/ERC20 pool.
     * @param tokenA Address of the first token.
     * @param tokenB Address of the second token.
     * @param liquidity Amount of LP tokens to burn.
     * @param amountAMin Minimum tokenA to receive.
     * @param amountBMin Minimum tokenB to receive.
     * @param to Recipient of the underlying tokens.
     * @param deadline Unix timestamp after which the transaction reverts.
     * @return amountA TokenA received.
     * @return amountB TokenB received.
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

}
