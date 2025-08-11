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

contract Factory {
    error Factory__IdenticalAddresses();
    error Factory__ZeroAddress();
    error Factory__PairExists();

    address public feeTo; // 手续费接收地址
    address public feeToSetter; // 可以修改 feeTo 的地址
    mapping(address => mapping(address => address)) public getPair; // tokenA => tokenB => pair地址
    address[] public allPairs; // 所有创建的 Pair 合约地址数组

    event PairCreated(address indexed token0, address indexed token1, address pair);

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    // 创建交易对
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        if (tokenA != tokenB) revert Factory__IdenticalAddresses();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert Factory__ZeroAddress();
        if (getPair[token0][token1] != address(0)) revert Factory__PairExists();

        // bytes memory bytecode = type(UniswapV2Pair).creationCode;
        // bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        // assembly {
        //     pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        // }

        // UniswapV2Pair(pair).initialize(token0, token1);
        // getPair[token0][token1] = pair;
        // getPair[token1][token0] = pair; // 双向映射
        // allPairs.push(pair);
        emit PairCreated(token0, token1, pair);
    }
}
