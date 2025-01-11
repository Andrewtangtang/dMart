// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/contracts/DMartFactory.sol";

contract DeployFactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 部署 DMartFactory 合約
        DMartFactory factory = new DMartFactory();
        console.log("DMartFactory deployed at:", address(factory));

        vm.stopBroadcast();
    }
}

