// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {FBTCBadge} from "../src/FBTCIdentity.sol"; 

contract DeployOnMultipleNetworks is Script {
    function run() external {
        bytes32 salt = keccak256(abi.encodePacked("FBTC"));
        address owner = vm.envAddress("OWNER");// owner
        string memory baseUrl= vm.envString("BASEURL");

        vm.startBroadcast();
        // use create2 to deploy the contract
        FBTCBadge nft = new FBTCBadge{salt: salt}(
            baseUrl, // baseURI
            owner
        );

        vm.stopBroadcast();

        console.log("Deployed FBTCBadge contract at:", address(nft));
    }
}
