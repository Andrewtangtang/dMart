// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDMartProject {
    function factory() external view returns (address);

    function initialize(address, address) external;
}