pragma solidity ^0.8.0;

import {SwapERC20} from "./SwapErc20.sol";

contract Pair is SwapERC20 {
    address public factory;
    address public token0;
    address public token1;

    uint112 private s_reserve0;
    uint112 private s_reserve1;
    uint32 private s_blockTimestampLast;
}
