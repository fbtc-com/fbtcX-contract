// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Vulcan} from "../src/FBTCIdentity.sol"; // 确保引入了正确的合约

contract DeployOnMultipleNetworks is Script {
    function run() external {
        bytes32 salt = keccak256(abi.encodePacked("FBTC"));
        address owner = 0xDCB1BC0618D5F009A4C3e76d877Bf89d7c215BA9;// owner


        // 遍历所有 RPC 并在每个网络上部署合约

        vm.startBroadcast();
        // 使用 CREATE2 部署合约
        Vulcan nft = new Vulcan{salt: salt}(
            "https://static.testnet.mantle.xyz/fbtc/json/", // baseURI
            owner
        );

        vm.stopBroadcast();

        console.log("Deployed Vulcan contract at:", address(nft));
    }
}
