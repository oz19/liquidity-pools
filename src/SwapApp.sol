// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

import "./interfaces/IV2Router02.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";


contract SwapApp {
    using SafeERC20 for IERC20;

    address public v2Router02Address;

    event SwapTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event UsdtDaiLiquidityAdded(uint usdtAdded, uint daiAdded, uint newLiquidity);

    constructor(address v2Router02Address_) {
        v2Router02Address = v2Router02Address_;
    }

    function swapTokens(
        uint256 amountIn_,
        uint256 amountOutMin_,
        address[] memory path_,
        uint256 deadline_) 
        public returns (uint256) {

        IERC20(path_[0]).safeTransferFrom(msg.sender, address(this), amountIn_);
        IERC20(path_[0]).approve(v2Router02Address, amountIn_);
        uint[] memory amountsOut_= IV2Router02(v2Router02Address).swapExactTokensForTokens(
            amountIn_,
            amountOutMin_,
            path_,
            msg.sender,
            deadline_
        );

        emit SwapTokens(path_[0], path_[path_.length - 1], amountIn_, amountsOut_[amountsOut_.length - 1]);
        
        return amountsOut_[amountsOut_.length - 1];
    }

    /*
    This function gets USDT funds:
    1. Keeps half of the funds to add USDT liquidity.
    2. Swaps the other half of the USDT to DAI.
    3. Add liquidity.
    */
    function addLiquidiyToUsdtDaiFromUsdtFunds(
        uint256 totalUsdtToAdd_,
        uint256 usdtInForSwap_,
        uint256 daiOutMinForSwap_,
        uint deadline_
    ) external {
        
        address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
        address DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
        
        //1st step: Swap tokens. Only USDT is required to perform this operation.
        // Send 1/2 of total USDT to this contract.
        uint256 usdtToAdd_ = totalUsdtToAdd_ / 2;
        IERC20(USDT).transferFrom(msg.sender, address(this), usdtToAdd_);

        // Use 1/2 of total USDT to Swap and get DAI in return.
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = DAI;
        uint256 daiToAdd_ = swapTokens(usdtInForSwap_, daiOutMinForSwap_, path, deadline_);  // Got DAI in msg.sender
        IERC20(DAI).transferFrom(msg.sender, address(this), daiToAdd_);  // Send DAI to this contract
        
        // 2nd step: Add liquidity
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

}