// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/* solhint-disable no-console */

import {
    deployAll, grantAndRenounceAllRoles, grantAllPauseRoles, Deployments, DeploymentParams
} from "./helpers/Proxy.sol";
import {console2 as console} from "forge-std/console2.sol";
import {Base} from "./base.s.sol";

contract Deploy is Base {
    function _readDeploymentParamsFromEnv() internal view returns (DeploymentParams memory) {
        return DeploymentParams({
            fbtcAddress: vm.envAddress("FBTC_ADDRESS"),
            fireBrdigeAddress: vm.envAddress("FIRE_BRIDGE_ADDRESS"),
            admin: vm.envAddress("SUPER_ADMIN"),
            proposer: vm.envAddress("PROPOSER_ADDRESS"),
            pauser1: vm.envAddress("PAUSER_ROLE_ADDRESS1"),
            pauser2: vm.envAddress("PAUSER_ROLE_ADDRESS2"),
            pauser3: vm.envAddress("PAUSER_ROLE_ADDRESS3"),
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

    function deploy(string memory projectName) public {
        DeploymentParams memory params = _readDeploymentParamsFromEnv();
        vm.startBroadcast();
        Deployments memory deps = deployAll(params);
        vm.stopBroadcast();

        logDeployments(deps);
        writeDeployments(projectName, deps);
    }

    function logDeployments(Deployments memory deps) public view {
        console.log("Deployments:");
        console.log("lockedFBTC address: %s", address(deps.lockedFBTC));
    }

    function transferAllRoles() public {
        DeploymentParams memory params = _readDeploymentParamsFromEnv();
        Deployments memory ds = readDeployments();

        vm.startBroadcast();
        grantAllPauseRoles(params, ds);
        grantAndRenounceAllRoles(params, ds, msg.sender);
        vm.stopBroadcast();
    }

    function transferAllRoles(string memory projectName) public {
        DeploymentParams memory params = _readDeploymentParamsFromEnv();
        Deployments memory ds = readDeployments(projectName);

        vm.startBroadcast();
        grantAllPauseRoles(params, ds);
        grantAndRenounceAllRoles(params, ds, msg.sender);
        vm.stopBroadcast();
    }

}
