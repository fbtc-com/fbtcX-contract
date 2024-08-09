// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {AccessControlUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {LockedFBTC} from "../../src/LockedFBTC.sol";
import {console2 as console} from "forge-std/console2.sol";

// EmptyContract serves as a dud implementation for the proxy, which lets us point
// to something and deploy the proxy before we deploy the implementation.
// This helps avoid the cyclic dependencies in init.
contract EmptyContract {}

struct Deployments {
    TimelockController proxyAdmin;
    LockedFBTC lockedFBTC;
}

struct DeploymentParams {
    address admin;
    address proposer;
    address pauser1;
    address pauser2;
    address pauser3;
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
/// timelock controller with `params.admin` as proposer and executor, and `params.admin` as timelock admin.
/// The `deployer` will be added as admin, proposer and executer for the duration of the deployment. The permissions are
/// renounced accordingly at the end of the deployment.
/// @param params the configuration to use for the deployment.
/// @param deployer the address executing this function. While this will always be `msg.sender` in deployement scripts,
/// it will need to be set in tests as `prank`s will not affect `msg.sender` in free functions.
function deployAll(DeploymentParams memory params, address deployer) returns (Deployments memory) {
    address[] memory executors = new address[](2);
     address[] memory proposers = new address[](2);
    executors[0] = params.admin;
    executors[1] = deployer;
    proposers[0] = params.proposer;
    proposers[1] = deployer;
    TimelockController proxyAdmin =
        new TimelockController({minDelay: 0, admin: deployer, proposers: proposers, executors: executors});

    // Create empty contract for proxy pointer
    EmptyContract empty = new EmptyContract();
    // Create proxies for all contracts
    Deployments memory ds = Deployments({proxyAdmin: proxyAdmin, lockedFBTC: LockedFBTC(address(newProxy(empty, proxyAdmin)))});
    console.log("Implementations proxy: %s", address(ds.lockedFBTC));

    ds.lockedFBTC = initLockedFBTC(
        proxyAdmin,
        ITransparentUpgradeableProxy(address(ds.lockedFBTC)),
        params.fbtcAddress,
        params.fireBrdigeAddress,
        deployer,
        params.pauser1,
        params.minter,
        params.safetyCommittee,
        "TOKEN_NAME",
        "TOKEN_SYMBOL"
    );

    // Renounce all roles, now that we have deployed everything
    // Keep roles only if the deployer was also set as admin, repspectively.
    if (deployer != params.admin) {
        proxyAdmin.grantRole(proxyAdmin.TIMELOCK_ADMIN_ROLE(), params.admin);
        proxyAdmin.renounceRole(proxyAdmin.TIMELOCK_ADMIN_ROLE(), deployer);
        proxyAdmin.renounceRole(proxyAdmin.PROPOSER_ROLE(), deployer);
        proxyAdmin.renounceRole(proxyAdmin.EXECUTOR_ROLE(), deployer);
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

function upgradeTo(TimelockController controller, ITransparentUpgradeableProxy proxy, address implementation) {
    scheduleAndExecute(
        controller, address(proxy), 0, abi.encodeCall(ITransparentUpgradeableProxy.upgradeTo, (implementation))
    );
}

function initLockedFBTC(
    TimelockController proxyAdmin,
    ITransparentUpgradeableProxy proxy,
    address fbtcAddress,
    address fireBrdigeAddress,
    address admin,
    address pauser,
    address minter,
    address safetyCommittee,
    string memory name,
    string memory symbol
) returns (LockedFBTC) {
    LockedFBTC impl = new LockedFBTC();
    console.log("LockedFBTC Impl: ", address(impl));
    upgradeToAndCall(
        proxyAdmin,
        proxy,
        address(impl),
        abi.encodeCall(LockedFBTC.initialize, (fbtcAddress, fireBrdigeAddress, admin, pauser, minter, safetyCommittee, name, symbol))
    );
    return LockedFBTC(address(proxy));
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
    
    grantAndRenounce(ds.lockedFBTC, ds.lockedFBTC.DEFAULT_ADMIN_ROLE(), sender, params.admin);
    console.log("renounce admin role: ", sender);
    console.log("new admin role: ", params.admin);
}

function grantAllPauseRoles(DeploymentParams memory params, Deployments memory ds) {
           grantRole(ds.lockedFBTC, ds.lockedFBTC.PAUSER_ROLE(), params.pauser2);
           grantRole(ds.lockedFBTC, ds.lockedFBTC.PAUSER_ROLE(), params.pauser3);
           console.log("new pauser role2: ", params.pauser2);
           console.log("new pauser role3: ", params.pauser3);
}
