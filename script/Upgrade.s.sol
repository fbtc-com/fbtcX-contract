// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/* solhint-disable no-console */

import {console2 as console} from "forge-std/console2.sol";
import {ITransparentUpgradeableProxy} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";

import {Base} from "./base.s.sol";
import {ScriptBase} from "forge-std/Base.sol";
import {Deployments, scheduleAndExecute, upgradeTo} from "./helpers/Proxy.sol";

import {LockedFBTC} from "../src/LockedFBTC.sol";

contract CalldataPrinter is ScriptBase {
    string private _name;
    mapping(bytes4 => string) private _selectorNames;

    constructor(string memory name) {
        _name = name;
    }

    function setSelectorName(bytes4 selector, string memory name) external {
        _selectorNames[selector] = name;
    }

    fallback() external {
        console.log("Calldata to %s [%s]:", _name, _selectorNames[bytes4(msg.data[:4])]);
        console.logBytes(msg.data);
    }
}

contract Upgrade is Base {
    /// @dev Deploys a new implementation contract for a given contract name and returns its proxy address with its new
    /// implementation address.
    /// @param contractName The name of the contract to deploy as implementation.
    /// @return proxyAddr The address of the new proxy contract.
    /// @return implAddress The address of the new implementation contract.
    function _deployImplementation(string memory contractName) internal returns (address, address) {
        Deployments memory depls = readDeployments();
        if (keccak256(bytes(contractName)) == keccak256("LockedFBTC")) {
            LockedFBTC impl = new LockedFBTC();
            return (address(depls.lockedFBTC), address(impl));
        }
        revert("Uknown contract");
    }

    function upgrade(string memory contractName, bool shouldExecute) public {
        Deployments memory depls = readDeployments();

        vm.startBroadcast();
        (address proxyAddr, address implAddress) = _deployImplementation(contractName);
        vm.stopBroadcast();

        bytes memory callData = abi.encodeCall(ITransparentUpgradeableProxy.upgradeTo, (implAddress));

        console.log("=============================");
        console.log("Onchain addresses");
        console.log("=============================");
        console.log(string.concat(contractName, " address (proxy):"));
        console.log(proxyAddr);
        console.log("New implementation address:");
        console.log(implAddress);
        console.log();

        TimelockController proxyAdmin;

        if (shouldExecute) {
            console.log("=============================");
            console.log("SUBMITTING UPGRADE TX ONCHAIN");
            console.log("=============================");

            proxyAdmin = depls.proxyAdmin;
            vm.startBroadcast();
        } else {
            console.log("=============================");
            console.log("REQUESTED NOT TO EXECUTE");
            console.log("MUST CALL PROXY ADMIN WITH CALLDATA");
            console.log("=============================");
            console.log("Proxy:");
            console.log(proxyAddr);
            console.log("Calldata to Proxy:");
            console.logBytes(callData);
            console.log("---");
            console.log("ProxyAdmin:");
            console.log(address(depls.proxyAdmin));
            CalldataPrinter printer = new CalldataPrinter("ProxyAdmin");
            printer.setSelectorName(TimelockController.schedule.selector, "schedule");
            printer.setSelectorName(TimelockController.execute.selector, "execute");

            proxyAdmin = TimelockController(payable(address(printer)));
        }

        // Run the upgrade.
        scheduleAndExecute(proxyAdmin, proxyAddr, 0, callData);
    }

    function upgradeToAndCall(
        string memory contractName, 
        bool shouldExecute,
        address fbtcAddress,
        address fireBrdigeAddress,
        address admin,
        address[] memory pausers,
        address minter,
        address safetyCommittee,
        string memory name,
        string memory symbol
        ) public {
        Deployments memory depls = readDeployments();

        vm.startBroadcast();
        (address proxyAddr, address implAddress) = _deployImplementation(contractName);
        vm.stopBroadcast();

        // The initialize method for LockedFBTC needs to be overwritten as the reinitialize method
        bytes memory callData = abi.encodeCall(ITransparentUpgradeableProxy.upgradeToAndCall, (implAddress,abi.encodeCall(LockedFBTC.initialize, (fbtcAddress, fireBrdigeAddress, admin, pausers, minter, safetyCommittee, name, symbol))));

        console.log("=============================");
        console.log("Onchain addresses");
        console.log("=============================");
        console.log(string.concat(contractName, " address (proxy):"));
        console.log(proxyAddr);
        console.log("New implementation address:");
        console.log(implAddress);
        console.log();

        TimelockController proxyAdmin;

        if (shouldExecute) {
            console.log("=============================");
            console.log("SUBMITTING UPGRADE TX ONCHAIN");
            console.log("=============================");

            proxyAdmin = depls.proxyAdmin;
            vm.startBroadcast();
        } else {
            console.log("=============================");
            console.log("REQUESTED NOT TO EXECUTE");
            console.log("MUST CALL PROXY ADMIN WITH CALLDATA");
            console.log("=============================");
            console.log("Proxy:");
            console.log(proxyAddr);
            console.log("Calldata to Proxy:");
            console.logBytes(callData);
            console.log("---");
            console.log("ProxyAdmin:");
            console.log(address(depls.proxyAdmin));
            CalldataPrinter printer = new CalldataPrinter("ProxyAdmin");
            printer.setSelectorName(TimelockController.schedule.selector, "schedule");
            printer.setSelectorName(TimelockController.execute.selector, "execute");

            proxyAdmin = TimelockController(payable(address(printer)));
        }

        // Run the upgrade.
        scheduleAndExecute(proxyAdmin, proxyAddr, 0, callData);
    }

}
