// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

import "./interfaces/IV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title SwapApp
 * @notice Wrapper around a Uniswap V2-compatible router for token swaps and
 *         USDT/DAI liquidity pool management.
 * @dev USDT and DAI addresses are set at deploy time as immutables to avoid
 *      hardcoded chain-specific values and to enable local testing with mocks.
 */
contract SwapApp {
    using SafeERC20 for IERC20;

    /// @notice Address of the Uniswap V2-compatible router.
    address public v2Router02Address;

    /// @notice Address of the Uniswap V2-compatible factory.
    address public v2FactoryAddress;

    /// @notice Address of the USDT ERC20 token.
    address public immutable USDT;

    /// @notice Address of the DAI ERC20 token.
    address public immutable DAI;

    /**
     * @notice Emitted after a successful token swap.
     * @param tokenIn The address of the input token.
     * @param tokenOut The address of the output token.
     * @param amountIn The amount of tokenIn spent.
     * @param amountOut The amount of tokenOut received.
     */
    event SwapTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    /**
     * @notice Emitted after liquidity is added to the USDT/DAI pool.
     * @param usdtAdded Amount of USDT added.
     * @param daiAdded Amount of DAI added.
     * @param newLiquidity Amount of LP tokens received.
     */
    event UsdtDaiLiquidityAdded(uint usdtAdded, uint daiAdded, uint newLiquidity);

    /**
     * @notice Emitted after liquidity is removed from the USDT/DAI pool.
     * @param liquidity Amount of LP tokens burned.
     */
    event UsdtDaiLiquidityRemoved(uint256 liquidity);

    /**
     * @notice Deploys the swap and liquidity manager.
     * @param v2Router02Address_ Address of the Uniswap V2-compatible router.
     * @param v2FactoryAddress_ Address of the Uniswap V2-compatible factory.
     * @param usdt_ Address of the USDT ERC20 token.
     * @param dai_ Address of the DAI ERC20 token.
     */
    constructor(address v2Router02Address_, address v2FactoryAddress_, address usdt_, address dai_) {
        v2Router02Address = v2Router02Address_;
        v2FactoryAddress = v2FactoryAddress_;
        USDT = usdt_;
        DAI = dai_;
    }

    /**
     * @notice Swaps an exact amount of tokenIn for at least amountOutMin of tokenOut.
     * @dev Public (not external) so it can be called internally by addLiquidityToUsdtDaiFromUsdtFunds.
     *      Caller must approve this contract to spend at least amountIn_ of path_[0].
     * @param amountIn_ Amount of input token to swap.
     * @param amountOutMin_ Minimum amount of output token to receive.
     * @param path_ Swap path. Must have at least 2 token addresses.
     * @param deadline_ Unix timestamp after which the transaction reverts.
     * @return The amount of output token received.
     */
    function swapTokens(
        uint256 amountIn_,
        uint256 amountOutMin_,
        address[] memory path_,
        uint256 deadline_
    ) public returns (uint256) {
        require(path_.length >= 2, "Path must have at least 2 tokens");

        IERC20(path_[0]).safeTransferFrom(msg.sender, address(this), amountIn_);
        IERC20(path_[0]).forceApprove(v2Router02Address, amountIn_);

        uint[] memory amountsOut_ = IV2Router02(v2Router02Address).swapExactTokensForTokens(
            amountIn_,
            amountOutMin_,
            path_,
            msg.sender,
            deadline_
        );

        emit SwapTokens(path_[0], path_[path_.length - 1], amountIn_, amountsOut_[amountsOut_.length - 1]);

        return amountsOut_[amountsOut_.length - 1];
    }

    /**
     * @notice Adds liquidity to the USDT/DAI pool using only USDT as input.
     * @dev Splits totalUsdtToAdd_ in half: one half is kept as USDT, the other is swapped for DAI.
     *      Caller must approve this contract for totalUsdtToAdd_ USDT and the expected DAI amount.
     * @param totalUsdtToAdd_ Total USDT to use (split equally between direct deposit and swap).
     * @param daiOutMinForSwap_ Minimum DAI to receive from the swap (slippage protection).
     * @param deadline_ Unix timestamp after which the transaction reverts.
     */
    function addLiquidityToUsdtDaiFromUsdtFunds(
        uint256 totalUsdtToAdd_,
        uint256 daiOutMinForSwap_,
        uint deadline_
    ) external {
        uint256 usdtToAdd_ = totalUsdtToAdd_ / 2;
        IERC20(USDT).safeTransferFrom(msg.sender, address(this), usdtToAdd_);

        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = DAI;
        uint256 daiToAdd_ = swapTokens(usdtToAdd_, daiOutMinForSwap_, path, deadline_);
        IERC20(DAI).safeTransferFrom(msg.sender, address(this), daiToAdd_);

        IERC20(USDT).forceApprove(v2Router02Address, usdtToAdd_);
        IERC20(DAI).forceApprove(v2Router02Address, daiToAdd_);

        (uint usdtAdded, uint daiAdded, uint newLiquidity) = IV2Router02(v2Router02Address).addLiquidity(
            USDT,
            DAI,
            usdtToAdd_,
            daiToAdd_,
            usdtToAdd_ / 2,
            daiToAdd_ / 2,
            msg.sender,
            deadline_
        );

        emit UsdtDaiLiquidityAdded(usdtAdded, daiAdded, newLiquidity);
    }

    /**
     * @notice Removes liquidity from the USDT/DAI pool.
     * @dev Caller must approve this contract for the LP token amount.
     * @param liquidity Amount of LP tokens to burn.
     * @param usdtMin_ Minimum USDT to receive.
     * @param daiMin_ Minimum DAI to receive.
     * @param to_ Address that receives the underlying tokens.
     */
    function removeLiquidityFromUsdtDaiPool(
        uint256 liquidity,
        uint256 usdtMin_,
        uint256 daiMin_,
        address to_
    ) external {
        uint256 deadline_ = block.timestamp + 1 days;
        address pair = IUniswapV2Factory(v2FactoryAddress).getPair(USDT, DAI);
        IERC20(pair).safeTransferFrom(msg.sender, address(this), liquidity);
        IERC20(pair).forceApprove(v2Router02Address, liquidity);

        IV2Router02(v2Router02Address).removeLiquidity(USDT, DAI, liquidity, usdtMin_, daiMin_, to_, deadline_);

        emit UsdtDaiLiquidityRemoved(liquidity);
    }

}
