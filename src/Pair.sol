//SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
pragma solidity ^0.8.0;

import {SwapERC20} from "./SwapERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Pair is SwapERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    error Pair__NotFactory();
    error Pair__AlreadyInitialized();
    error Pair__Overflow();
    error Pair__InsufficientLiquidityMinted();
    error Pair__InsufficientLiquidityBurned();
    error Pair__InsufficientOutputAmount();
    error Pair__InsufficientLiquidity();
    error Pair__InsufficientInputAmount();
    error Pair__K();

    address public factory;
    address public token0;
    address public token1;

    uint112 private s_reserve0;
    uint112 private s_reserve1;
    uint32 private s_blockTimestampLast;
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    constructor() SwapERC20() {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        if (msg.sender != factory) revert Pair__NotFactory();
        if (token0 != address(0) || token1 != address(0)) revert Pair__AlreadyInitialized();
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = s_reserve0;
        _reserve1 = s_reserve1;
        _blockTimestampLast = s_blockTimestampLast;
    }

    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = (amount0 * amount1).sqrt().saturatingSub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY); // 锁定最小流动性，防止除0错误
        } else {
            liquidity = Math.min(amount0 * (_totalSupply) / _reserve0, amount1 * (_totalSupply) / _reserve1);
        }
        if (liquidity <= 0) {
            revert Pair__InsufficientLiquidityMinted();
        }
        _mint(to, liquidity);
        _update(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));
        uint256 _totalSupply = totalSupply();
        amount0 = liquidity * _reserve0 / _totalSupply;
        amount1 = liquidity * _reserve1 / _totalSupply;

        if (amount0 == 0 || amount1 == 0) revert Pair__InsufficientLiquidityBurned();

        _burn(address(this), liquidity);

        IERC20(token0).safeTransfer(to, amount0);
        IERC20(token1).safeTransfer(to, amount1);

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to) external nonReentrant {
        if (amount0Out == 0 && amount1Out == 0) revert Pair__InsufficientOutputAmount();

        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        if (amount0Out > _reserve0 || amount1Out > _reserve1) revert Pair__InsufficientLiquidity();

        if (amount0Out > 0) IERC20(token0).safeTransfer(to, amount0Out);
        if (amount1Out > 0) IERC20(token1).safeTransfer(to, amount1Out);

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;

        if (amount0In == 0 && amount1In == 0) revert Pair__InsufficientInputAmount();

        uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
        uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
        if (balance0Adjusted * balance1Adjusted < uint256(_reserve0) * uint256(_reserve1) * (1000 ** 2)) {
            revert Pair__K();
        }
        _update(balance0, balance1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function _update(uint256 balance0, uint256 balance1) private {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) revert Pair__Overflow();
        s_reserve0 = uint112(balance0);
        s_reserve1 = uint112(balance1);
        s_blockTimestampLast = uint32(block.timestamp % 2 ** 32);
    }

    function sync() external nonReentrant {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }
}
