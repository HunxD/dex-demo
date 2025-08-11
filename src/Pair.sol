pragma solidity ^0.8.0;
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

import {SwapERC20} from "./SwapErc20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract Pair is SwapERC20 {
    using Math for uint256;

    error Pair__NotFactory();
    error Pair__AlreadyInitialized();
    error Pair__Overflow();
    error Pair__InsufficientLiquidityMinted();

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

    function _update(uint256 balance0, uint256 balance1) private {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) revert Pair__Overflow();
        s_reserve0 = uint112(balance0);
        s_reserve1 = uint112(balance1);
        s_blockTimestampLast = uint32(block.timestamp % 2 ** 32);
    }

    function mint(address to) external returns (uint256 liquidity) {
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
    }
}
