// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Deployments} from "./helpers/Proxy.sol";

contract Base is Script {

    function setUp() public virtual {
        require(vm.envUint("CHAIN_ID") == block.chainid, "wrong chain id");
    }

    function _deploymentsFile() internal view returns (string memory) {
        string memory root = vm.projectRoot();
        return string.concat(root, "/deployments/", vm.toString(block.chainid));
    }

    function writeDeployments(Deployments memory deps) public {
        vm.writeFileBinary(_deploymentsFile(), abi.encode(deps));
    }

    function readDeployments() public view returns (Deployments memory) {
        bytes memory data = vm.readFileBinary(_deploymentsFile());
        Deployments memory depls = abi.decode(data, (Deployments));

        require(address(depls.fbtc1).code.length > 0, "contracts are not deployed yet");
        return depls;
    }
}
