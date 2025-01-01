// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDMartFactory {
    event PoolCreated(address indexed token0, address indexed token1, address pool, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPool(address tokenA, address tokenB) external view returns (address pool);
    function allPools(uint) external view returns (address pool);
    function allPoolsLength() external view returns (uint);

    function createPool(address creator, uint256 goal) external returns (address pool);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}