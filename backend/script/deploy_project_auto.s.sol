// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Foundry Script基礎
import {Script} from "forge-std/Script.sol";

// 匯入要部署的合約
import {DMartProjectAuto} from "../src/contracts/DMartProjectAuto.sol";

contract DeployAuto is Script {
    // 這些參數可以改成你實際要傳入的值
    address linkToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789; // Sepolia LINK
    address oracle = 0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD;    // Sepolia Oracle
    bytes32 jobIdCreate = 0x7da2702f37fd48e5b1b9a5715e3509b600000000000000000000000000000000;       // 示例 jobId
    bytes32 jobIdResult = 0x7da2702f37fd48e5b1b9a5715e3509b600000000000000000000000000000000; 
    uint256 fee = 0.1 * 10**18; // 0.1 LINK (注意：LINK本身是有18 decimals, 建議改為 0.1 * 10**18)

    function run() external {
        // 1. 開始 "broadcast" 表示要發交易
        vm.startBroadcast();

        // 2. 部署合約
        DMartProjectAuto autoContract = new DMartProjectAuto(
            linkToken,
            oracle,
            jobIdCreate,
            jobIdResult,
            fee
        );

        // 3. 停止 broadcast
        vm.stopBroadcast();

        // 4. 在終端機顯示部署結果
        //console.log("DMartProjectAuto deployed at:", address(autoContract));
    }
}

