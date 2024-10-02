// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
/* solhint-disable no-console */

import {
deployFactoryAll, FactoryDeployments, FactoryDeploymentParams
} from "./helpers/FactoryProxy.sol";
import {console2 as console} from "forge-std/console2.sol";
import {Base} from "./base.s.sol";

contract Deploy is Base {
    function _readDeploymentParamsFromEnv() internal view returns (FactoryDeploymentParams memory) {
        // Reading environment variables for pauser addresses and storing them in an array address;
        address[] memory pausers = new address[](3);
        pausers[0] = vm.envAddress("PAUSER_ROLE_ADDRESS1");
        pausers[1] = vm.envAddress("PAUSER_ROLE_ADDRESS2");
        pausers[2] = vm.envAddress("PAUSER_ROLE_ADDRESS3");

        // Returning deployment parameters with the pauser array
        return FactoryDeploymentParams({
            factoryAdmin : vm.envAddress("FACTORY_ADMIN"),
            fbtcAddress: vm.envAddress("FBTC_ADDRESS"),
            fireBrdigeAddress: vm.envAddress("FIRE_BRIDGE_ADDRESS"),
            lockedFbtcAdmin: vm.envAddress("SUPER_ADMIN"),
            proposer: vm.envAddress("PROPOSER_ADDRESS"),
            pausers: pausers,
            minter: vm.envAddress("MINTER_ROLE_ADDRESS"),
            safetyCommittee: vm.envAddress("SAFETY_COMMITTEE"),
            create2Deployer: vm.envAddress("CREATE2_DEPLOYER")
        });
    }

    function deploy(string memory projectName) public {
        FactoryDeploymentParams memory params = _readDeploymentParamsFromEnv();
        vm.startBroadcast();
        FactoryDeployments memory deps = deployFactoryAll(params);
        vm.stopBroadcast();

        logDeployments(deps);
        writeFactoryDeployments(projectName,deps);
    }

    function logDeployments(FactoryDeployments memory deps) public pure {
        console.log("Deployments:");
        console.log("proxyAdmin address: %s", address(deps.factoryProxyAdmin));
        console.log("BeaconProxyAdmin address: %s", address(deps.beaconAdmin));
        console.log("beacon address: %s", address(deps.beacon));
        console.log("lockedFBTCFactory address: %s", address(deps.lockedFBTCFactory));
    }

}
