// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDMartFactory {
    event ProjectCreated(address indexed project, uint256 indexed amount);

    // function feeTo() external view returns (address);
    // function feeToSetter() external view returns (address);

    function getProject(uint256 id) external view returns (address project);
    function getAllProjects(address user) external view returns (address project);
    function allProjectsLength() external view returns (uint256);

    function createProject(address creator, uint256 amount) external returns (address project);

    // function setFeeTo(address) external;
    // function setFeeToSetter(address) external;
}