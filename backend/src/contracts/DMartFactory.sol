// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './interfaces/IDMartFactory.sol';
import './DMartProject.sol';

contract DMartFactory is IDMartFactory {
    address private _owner;

    mapping(address => address[]) public _getProjects;
    mapping(address => uint256) public nounces;
    address[] public allProjects;

    event ProjectCreated(address indexed project, uint256 indexed fund);

    constructor(address owner_) {
        _owner = owner_;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function getProject(uint256 id) public view returns (address project){
        require(allProjects[id] != address(0), "Invalid id.");
        return allProjects[id];
    }

    function getProject(address creator, uint256 id) public view returns (address project){
        require(creator != address(0), "Invalid creator.");
        require(id < _getProjects[creator].length, "Invalid id.");
        return _getProjects[creator][id];
    }

    function allProjectsLength() public view returns (uint) {
        return allProjects.length;
    }

    function createProject(uint256 fund) external returns (address project) {
        address creator = msg.sender;
        require(creator != address(0), "Creator doesn't exist.");
        require(fund > 0, "You have to set the amount of fund.");
        bytes memory bytecode = type(DMartProject).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(address(this), creator,nounces[creator]));
        assembly {
            project := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        DMartProject(project).initialize(fund);
        allProjects.push(project);
        nounces[creator]++;
        emit ProjectCreated(creator, fund);
    }
}