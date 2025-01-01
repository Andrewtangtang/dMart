// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './interfaces/IDMartFactory.sol';
import './DMartPool.sol';

contract UniswapV2Factory is IDMartFactory {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public gerPool;
    address[] public allPools;

    event PoolCreated(address indexed USDT, address indexed token1, address pool, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPoolsLength() external view returns (uint) {
        return allPools.length;
    }

    function createPool(address tokenA, address tokenB) external returns (address pool) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address USDT, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(USDT != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPool[USDT][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(UniswapV2Pool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(USDT, token1));
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IUniswapV2Pool(pool).initialize(USDT, token1);
        getPool[USDT][token1] = pool;
        getPool[token1][USDT] = pool; // populate mapping in the reverse direction
        allPools.push(pool);
        emit PoolCreated(USDT, token1, pool, allPools.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}