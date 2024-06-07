// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {AccessControlUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {FBTC1} from "../../src/FBTC1.sol";
import {console2 as console} from "forge-std/console2.sol";

// EmptyContract serves as a dud implementation for the proxy, which lets us point
// to something and deploy the proxy before we deploy the implementation.
// This helps avoid the cyclic dependencies in init.
contract EmptyContract {}

struct Deployments {
    TimelockController proxyAdmin;
    FBTC1 fbtc1;
}

struct DeploymentParams {
    address timeLockAdmin;
    address upgrader;
    address admin;
    address pauser;
    address minter;
    address safetyCommittee;
    address fbtcAddress;
    address fireBrdigeAddress;
}

function deployAll(DeploymentParams memory params) returns (Deployments memory) {
    return deployAll(params, msg.sender);
}

/// @notice Deploys all proxy and implementation contract, initializes them and returns a struct containing all the
/// addresses.
/// @dev All upgradeable contracts are deployed using the transparent proxy pattern, with the proxy admin being a
/// timelock controller with `params.upgrader` as proposer and executor, and `params.admin` as timelock admin.
/// The `deployer` will be added as admin, proposer and executer for the duration of the deployment. The permissions are
/// renounced accordingly at the end of the deployment.
/// @param params the configuration to use for the deployment.
/// @param deployer the address executing this function. While this will always be `msg.sender` in deployement scripts,
/// it will need to be set in tests as `prank`s will not affect `msg.sender` in free functions.
function deployAll(DeploymentParams memory params, address deployer) returns (Deployments memory) {
    address[] memory controllers = new address[](2);
    controllers[0] = params.upgrader;
    controllers[1] = deployer;
    TimelockController proxyAdmin =
        new TimelockController({minDelay: 0, admin: deployer, proposers: controllers, executors: controllers});

    // Create empty contract for proxy pointer
    EmptyContract empty = new EmptyContract();
    // Create proxies for all contracts
    Deployments memory ds = Deployments({proxyAdmin: proxyAdmin, fbtc1: FBTC1(address(newProxy(empty, proxyAdmin)))});
    console.log("Implementations proxy: %s", address(ds.fbtc1));

    ds.fbtc1 = initFbtc1Token(
        proxyAdmin,
        ITransparentUpgradeableProxy(address(ds.fbtc1)),
        params.fbtcAddress,
        params.fireBrdigeAddress,
        params.admin,
        params.pauser,
        params.minter,
        params.safetyCommittee
    );

    if (deployer != params.upgrader) {
        proxyAdmin.renounceRole(proxyAdmin.PROPOSER_ROLE(), deployer);
        proxyAdmin.renounceRole(proxyAdmin.EXECUTOR_ROLE(), deployer);
        proxyAdmin.renounceRole(proxyAdmin.CANCELLER_ROLE(), deployer);
    }

    return ds;
}

function newProxy(EmptyContract empty, TimelockController admin) returns (TransparentUpgradeableProxy) {
    return new TransparentUpgradeableProxy(address(empty), address(admin), "");
}

function scheduleAndExecute(TimelockController controller, address target, uint256 value, bytes memory data) {
    controller.schedule({target: target, value: value, data: data, predecessor: bytes32(0), delay: 0, salt: bytes32(0)});
    controller.execute{value: value}({
        target: target,
        value: value,
        payload: data,
        predecessor: bytes32(0),
        salt: bytes32(0)
    });
}

function upgradeToAndCall(
    TimelockController controller,
    ITransparentUpgradeableProxy proxy,
    address implementation,
    uint256 value,
    bytes memory data
) {
    scheduleAndExecute(
        controller,
        address(proxy),
        value,
        abi.encodeCall(ITransparentUpgradeableProxy.upgradeToAndCall, (implementation, data))
    );
}

function upgradeToAndCall(
    TimelockController controller,
    ITransparentUpgradeableProxy proxy,
    address implementation,
    bytes memory data
) {
    upgradeToAndCall(controller, proxy, implementation, 0, data);
}

function initFbtc1Token(
    TimelockController proxyAdmin,
    ITransparentUpgradeableProxy proxy,
    address fbtcAddress,
    address fireBrdigeAddress,
    address admin,
    address pauser,
    address minter,
    address safetyCommittee
) returns (FBTC1) {
    FBTC1 impl = new FBTC1();
    console.log("FBTC1 Impl: ", address(impl));
    upgradeToAndCall(
        proxyAdmin,
        proxy,
        address(impl),
        abi.encodeCall(FBTC1.initialize, (fbtcAddress, fireBrdigeAddress, admin, pauser, minter, safetyCommittee))
    );
    return FBTC1(address(proxy));
}

function grantRole(AccessControlUpgradeable controllable, bytes32 role, address newAccount) {
    controllable.grantRole(role, newAccount);
}

function grantAndRenounce(AccessControlUpgradeable controllable, bytes32 role, address sender, address newAccount) {
    // To prevent reassigning to self and renouncing later leaving the role empty
    if (sender != newAccount) {
        controllable.grantRole(role, newAccount);
        controllable.renounceRole(role, sender);
    }
}

/// @notice Grants roles to addresses as specified in `params` and renounces the roles from `sender`.
/// @dev Assumes that all contracts were deployed using `sender` as admin/manager/etc.
function grantAndRenounceAllRoles(DeploymentParams memory params, Deployments memory ds, address sender) {
    //
    grantAndRenounce(ds.fbtc1, ds.fbtc1.DEFAULT_ADMIN_ROLE(), sender, params.admin);
}

function grantAllAdminRoles(Deployments memory ds, address newAdmin) {
    //        grantRole(ds.proxyAdmin, ds.proxyAdmin.TIMELOCK_ADMIN_ROLE(), newAdmin);
}
