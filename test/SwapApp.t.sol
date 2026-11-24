// SPDX-License-Identifier: MIT

// Fork tests (require Arbitrum RPC):
// forge test --fork-url https://arb1.arbitrum.io/rpc --match-contract TestSwapAppFork
// forge coverage --fork-url https://arb1.arbitrum.io/rpc

pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../src/SwapApp.sol";
import "../src/interfaces/IV2Router02.sol";
import "../src/interfaces/IUniswapV2Factory.sol";

// ─── Mocks ───────────────────────────────────────────────────────────────────

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockLPToken is ERC20 {
    constructor() ERC20("Mock LP", "MLP") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockFactory is IUniswapV2Factory {
    address public pair;

    constructor(address pair_) {
        pair = pair_;
    }

    function getPair(address, address) external view override returns (address) {
        return pair;
    }
}

/// @dev Simulates a V2 router. Mints output tokens on swap, LP on addLiquidity,
///      and underlying tokens on removeLiquidity.
contract MockRouter is IV2Router02 {
    MockLPToken public lp;

    constructor(address lp_) {
        lp = MockLPToken(lp_);
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint, /* amountOutMin */
        address[] calldata path,
        address to,
        uint /* deadline */
    ) external override returns (uint[] memory amounts) {
        MockERC20(path[path.length - 1]).mint(to, amountIn);
        amounts = new uint[](path.length);
        for (uint i = 0; i < path.length; i++) amounts[i] = amountIn;
    }

    function addLiquidity(
        address, /* tokenA */
        address, /* tokenB */
        uint amountADesired,
        uint amountBDesired,
        uint, /* amountAMin */
        uint, /* amountBMin */
        address to,
        uint /* deadline */
    ) external override returns (uint amountA, uint amountB, uint liquidity) {
        amountA = amountADesired;
        amountB = amountBDesired;
        liquidity = amountADesired + amountBDesired;
        lp.mint(to, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidityAmount,
        uint, /* amountAMin */
        uint, /* amountBMin */
        address to,
        uint /* deadline */
    ) external override returns (uint amountA, uint amountB) {
        lp.transferFrom(msg.sender, address(this), liquidityAmount);
        amountA = liquidityAmount / 2;
        amountB = liquidityAmount / 2;
        MockERC20(tokenA).mint(to, amountA);
        MockERC20(tokenB).mint(to, amountB);
    }
}

// ─── Unit tests (no fork required) ───────────────────────────────────────────

contract TestSwapApp is Test {

    SwapApp app;
    MockERC20 usdt;
    MockERC20 dai;
    MockLPToken lpToken;
    MockRouter router;
    MockFactory factory;

    address user = vm.addr(1);
    uint256 amountIn = 100 ether;

    function setUp() public {
        usdt = new MockERC20("USDT", "USDT");
        dai = new MockERC20("DAI", "DAI");
        lpToken = new MockLPToken();
        router = new MockRouter(address(lpToken));
        factory = new MockFactory(address(lpToken));
        app = new SwapApp(address(router), address(factory), address(usdt), address(dai));

        usdt.mint(user, amountIn * 10);
        dai.mint(user, amountIn * 10);
    }

    function testIsCorrectlyInitialized() public view {
        assertEq(app.v2Router02Address(), address(router));
        assertEq(app.v2FactoryAddress(), address(factory));
        assertEq(app.USDT(), address(usdt));
        assertEq(app.DAI(), address(dai));
    }

    function testSwapRevertsIfPathTooShort() public {
        vm.startPrank(user);
        usdt.approve(address(app), amountIn);

        address[] memory path = new address[](1);
        path[0] = address(usdt);

        vm.expectRevert("Path must have at least 2 tokens");
        app.swapTokens(amountIn, 0, path, block.timestamp + 1);

        vm.stopPrank();
    }

    function testSwapTokensCorrectly() public {
        vm.startPrank(user);
        usdt.approve(address(app), amountIn);

        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(dai);

        uint256 usdtBefore = usdt.balanceOf(user);
        uint256 daiBefore = dai.balanceOf(user);

        vm.expectEmit(true, true, false, true);
        emit SwapApp.SwapTokens(address(usdt), address(dai), amountIn, amountIn);
        app.swapTokens(amountIn, 0, path, block.timestamp + 1);

        assertEq(usdt.balanceOf(user), usdtBefore - amountIn);
        assertGt(dai.balanceOf(user), daiBefore);

        vm.stopPrank();
    }

    function testAddLiquidityCorrectly() public {
        uint256 totalUsdt = amountIn * 2;

        vm.startPrank(user);
        // Approve totalUsdt USDT (half direct + half for swap)
        usdt.approve(address(app), totalUsdt);
        // Approve DAI that will be received from swap and re-pulled
        dai.approve(address(app), amountIn);

        uint256 lpBefore = lpToken.balanceOf(user);

        vm.expectEmit(false, false, false, false);
        emit SwapApp.UsdtDaiLiquidityAdded(0, 0, 0);
        app.addLiquidityToUsdtDaiFromUsdtFunds(totalUsdt, 0, block.timestamp + 1);

        assertGt(lpToken.balanceOf(user), lpBefore);

        vm.stopPrank();
    }

    function testRemoveLiquidityCorrectly() public {
        uint256 totalUsdt = amountIn * 2;

        // First add liquidity to get LP tokens
        vm.startPrank(user);
        usdt.approve(address(app), totalUsdt);
        dai.approve(address(app), amountIn);
        app.addLiquidityToUsdtDaiFromUsdtFunds(totalUsdt, 0, block.timestamp + 1);

        uint256 lpBalance = lpToken.balanceOf(user);
        assertGt(lpBalance, 0);

        uint256 usdtBefore = usdt.balanceOf(user);
        uint256 daiBefore = dai.balanceOf(user);

        lpToken.approve(address(app), lpBalance);

        vm.expectEmit(false, false, false, true);
        emit SwapApp.UsdtDaiLiquidityRemoved(lpBalance);
        app.removeLiquidityFromUsdtDaiPool(lpBalance, 0, 0, user);

        assertEq(lpToken.balanceOf(user), 0);
        assertGt(usdt.balanceOf(user), usdtBefore);
        assertGt(dai.balanceOf(user), daiBefore);

        vm.stopPrank();
    }

}

// ─── Fork tests (Arbitrum Mainnet) ───────────────────────────────────────────

contract TestSwapAppFork is Test {

    SwapApp app;
    address v2Router02Address = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address v2FactoryAddress = 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9;
    address user = 0xa7A1fe8dDaDE572A76Cebd4c43B2c5ce38893Fde;
    address usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    function setUp() public {
        if (block.chainid != 42161) {
            vm.skip(true);
            return;
        }
        app = new SwapApp(v2Router02Address, v2FactoryAddress, usdt, dai);
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

        assert(IERC20(usdt).balanceOf(user) == usdtBefore - amountIn);
        assert(IERC20(dai).balanceOf(user) > daiBefore);

        vm.stopPrank();
    }

    function testAddLiquidityToUsdtDaiWorksCorrectly() public {
        vm.startPrank(user);

        address usdtDaiPair_ = IUniswapV2Factory(v2FactoryAddress).getPair(usdt, dai);
        uint256 liquidityPoolTokensBefore_ = IERC20(usdtDaiPair_).balanceOf(user);
        uint256 usdtDecimals_ = 10 ** IERC20Metadata(usdt).decimals();
        uint256 totalUsdtToAdd_ = 6 * usdtDecimals_;
        uint256 daiDecimals_ = 10 ** IERC20Metadata(dai).decimals();
        uint256 daiToAdd_ = 3 * daiDecimals_;
        uint256 deadline_ = block.timestamp + 7 days;
        IERC20(usdt).approve(address(app), totalUsdtToAdd_);
        IERC20(dai).approve(address(app), daiToAdd_);

        app.addLiquidityToUsdtDaiFromUsdtFunds(totalUsdtToAdd_, 0, deadline_);

        assert(IERC20(usdtDaiPair_).balanceOf(user) > liquidityPoolTokensBefore_);

        vm.stopPrank();
    }

    function testRemoveLiquidityFromUsdtDaiWorksCorrectly() public {
        vm.startPrank(user);

        address usdtDaiPair_ = IUniswapV2Factory(v2FactoryAddress).getPair(usdt, dai);
        uint256 usdtDecimals_ = 10 ** IERC20Metadata(usdt).decimals();
        uint256 totalUsdtToAdd_ = 6 * usdtDecimals_;
        uint256 daiDecimals_ = 10 ** IERC20Metadata(dai).decimals();
        uint256 daiToAdd_ = 3 * daiDecimals_;
        uint256 deadline_ = block.timestamp + 7 days;
        IERC20(usdt).approve(address(app), totalUsdtToAdd_);
        IERC20(dai).approve(address(app), daiToAdd_);

        app.addLiquidityToUsdtDaiFromUsdtFunds(totalUsdtToAdd_, 0, deadline_);

        uint256 liquidityPoolTokensAfter_ = IERC20(usdtDaiPair_).balanceOf(user);
        uint256 usdtBalanceBefore_ = IERC20(usdt).balanceOf(user);
        uint256 daiBalanceBefore_ = IERC20(dai).balanceOf(user);
        IERC20(usdtDaiPair_).approve(address(app), liquidityPoolTokensAfter_);

        app.removeLiquidityFromUsdtDaiPool(liquidityPoolTokensAfter_, totalUsdtToAdd_ / 4, daiToAdd_ / 2, user);

        assert(IERC20(usdtDaiPair_).balanceOf(user) == 0);
        assert(IERC20(usdt).balanceOf(user) > usdtBalanceBefore_);
        assert(IERC20(dai).balanceOf(user) > daiBalanceBefore_);

        vm.stopPrank();
    }

}
