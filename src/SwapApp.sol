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

    event SwapTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event UsdtDaiLiquidityAdded(uint usdtAdded, uint daiAdded, uint newLiquidity);
    event UsdtDaiLiquidityRemoved(uint256 liquidity);

    constructor(address v2Router02Address_, address v2FactoryAddress_) {
        v2Router02Address = v2Router02Address_;
        v2FactoryAddress = v2FactoryAddress_;
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
    1. Sends half of the funds to the contract to later add USDT liquidity.
    2. Swaps the other half of the USDT to DAI, and send the given DAI to the contract.
    3. Add liquidity to the USDT/DAI pool.
    */
    function addLiquidityToUsdtDaiFromUsdtFunds(
        uint256 totalUsdtToAdd_,
        uint256 daiOutMinForSwap_,
        uint deadline_
    ) external {
        
        address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
        address DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
        
        //1st step: Swap tokens. Only USDT is required to add liquidity to the pool (DAI is obtained by swapping).
        // Send 1/2 of total USDT to this contract.
        uint256 usdtToAdd_ = totalUsdtToAdd_ / 2;
        IERC20(USDT).safeTransferFrom(msg.sender, address(this), usdtToAdd_);

        // Use 1/2 of total USDT to Swap and get DAI in return. Then send that DAI to this contract.
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = DAI;
        uint256 daiToAdd_ = swapTokens(usdtToAdd_, daiOutMinForSwap_, path, deadline_);  // Got DAI in msg.sender (we have to reuse swapTokens - better call swapExactTokensForTokens and return DAI to this contract directly)
        IERC20(DAI).safeTransferFrom(msg.sender, address(this), daiToAdd_);  // Send DAI to this contract
        
        // 2nd step: Add liquidity
        IERC20(USDT).approve(v2Router02Address, usdtToAdd_);
        IERC20(DAI).approve(v2Router02Address, daiToAdd_);
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

    function removeLiquidityFromUsdtDaiPool(uint256 liquidity, uint256 usdtMin_, uint256 daiMin_, address to_) external {

        address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
        address DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

        uint256 deadline_ = block.timestamp + 1 days;
        address pair = IUniswapV2Factory(v2FactoryAddress).getPair(USDT, DAI);
        IERC20(pair).safeTransferFrom(msg.sender, address(this), liquidity);
        IERC20(pair).approve(v2Router02Address, liquidity);

        IV2Router02(v2Router02Address).removeLiquidity(USDT, DAI, liquidity, usdtMin_, daiMin_, to_, deadline_);

        emit UsdtDaiLiquidityRemoved(liquidity);
    }

}