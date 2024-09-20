// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Vulcan} from "../src/FBTCIdentity.sol"; 

contract DeployOnMultipleNetworks is Script {
    function run() external {
        bytes32 salt = keccak256(abi.encodePacked("FBTC"));
        address owner = 0xDCB1BC0618D5F009A4C3e76d877Bf89d7c215BA9;// owner

        vm.startBroadcast();
        // use create2 to deploy the contract
        Vulcan nft = new Vulcan{salt: salt}(
            "https://static.testnet.mantle.xyz/fbtc/json/", // baseURI
            owner
        );

        vm.stopBroadcast();

        console.log("Deployed Vulcan contract at:", address(nft));
    }
}
