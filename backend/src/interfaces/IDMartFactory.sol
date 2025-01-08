// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDMartFactory {
    event ProjectCreated(address indexed project, uint256 indexed fund);

    function Owner() external view returns (address);

    function getProject(uint256 id) external view returns (address project);
    function getProject(address creator, uint256 id) external view returns (address project);
    function allProjectsLength() external view returns (uint256);

    function createProject(address creator, uint256 amount) external returns (address project);

}