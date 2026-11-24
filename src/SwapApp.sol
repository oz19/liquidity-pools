// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

import "./interfaces/IV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";


contract SwapApp {
    using SafeERC20 for IERC20;

    address public v2Router02Address;
    address public v2FactoryAddress;
    address public immutable USDT;
    address public immutable DAI;

    event SwapTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event UsdtDaiLiquidityAdded(uint usdtAdded, uint daiAdded, uint newLiquidity);
    event UsdtDaiLiquidityRemoved(uint256 liquidity);

    constructor(address v2Router02Address_, address v2FactoryAddress_, address usdt_, address dai_) {
        v2Router02Address = v2Router02Address_;
        v2FactoryAddress = v2FactoryAddress_;
        USDT = usdt_;
        DAI = dai_;
    }

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
