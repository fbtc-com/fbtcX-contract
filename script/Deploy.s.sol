// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
/* solhint-disable no-console */

import {
    deployAll, grantAndRenounceAllRoles, grantAllAdminRoles, Deployments, DeploymentParams
} from "./helpers/Proxy.sol";
import {console2 as console} from "forge-std/console2.sol";
import {Base} from "./base.s.sol";

contract Deploy is Base {
    function _readDeploymentParamsFromEnv() internal view returns (DeploymentParams memory) {
        return DeploymentParams({
            fbtcAddress: vm.envAddress("FBTC_ADDRESS"),
            fireBrdigeAddress: vm.envAddress("FIRE_BRIDGE_ADDRESS"),
            timeLockAdmin: vm.envAddress("TIMELOCK_ADMIN_ADDRESS"),
            upgrader: vm.envAddress("UPGRADER_ADDRESS"),
            admin: vm.envAddress("SUPER_ADMIN"),
            pauser: vm.envAddress("PAUSER_ROLE_ADDRESS"),
            minter: vm.envAddress("MINTER_ROLE_ADDRESS"),
            safetyCommittee: vm.envAddress("SAFETY_COMMITTEE")
        });
    }

    function deploy() public {
        DeploymentParams memory params = _readDeploymentParamsFromEnv();
        vm.startBroadcast();
        Deployments memory deps = deployAll(params);
        vm.stopBroadcast();

        logDeployments(deps);
        writeDeployments(deps);
    }

    function logDeployments(Deployments memory deps) public view {
        console.log("Deployments:");
        console.log("FBTC1 address: %s", address(deps.fbtc1));
    }

    function transferAllRoles() public {
        DeploymentParams memory params = _readDeploymentParamsFromEnv();
        Deployments memory ds = readDeployments();

        vm.startBroadcast();
        grantAndRenounceAllRoles(params, ds, msg.sender);
        vm.stopBroadcast();
    }

    function addNewAdminToAllContracts(address newAdmin) public {
        Deployments memory ds = readDeployments();
        vm.startBroadcast();
        grantAllAdminRoles(ds, newAdmin);
        vm.stopBroadcast();
    }
}
