// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
ITransparentUpgradeableProxy,
TransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {AccessControlUpgradeable} from
"openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {LockedFBTCFactory} from "../../src/LockedFBTCFactory.sol";
import {LockedFBTC} from "../../src/LockedFBTC.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {console2 as console} from "forge-std/console2.sol";

contract EmptyContract {}


struct FactoryDeployments {
    TimelockController factoryProxyAdmin;
    LockedFBTCFactory lockedFBTCFactory;
    UpgradeableBeacon beacon;
}

struct FactoryDeploymentParams {
    address factoryAdmin;
    address lockedFbtcAdmin;
    address proposer;
    address[] pausers;
    address minter;
    address safetyCommittee;
    address fbtcAddress;
    address fireBrdigeAddress;
}

function deployFactoryAll(FactoryDeploymentParams memory params) returns (FactoryDeployments memory) {
    return deployFactoryAll(params, msg.sender);
}

/// @notice Deploys the LockedFBTCFactory and its proxy contracts, initializes them, and returns their addresses.
/// @param params Configuration for deployment.
/// @param deployer The address executing the deployment.
function deployFactoryAll(FactoryDeploymentParams memory params, address deployer) returns (FactoryDeployments memory) {
    // 1: Create proxy admins
    TimelockController factoryProxyAdmin = _createTimelockController(deployer, params.factoryAdmin);
    TimelockController beaconAdmin = _createTimelockControllerWithSingleExecutor(params.proposer, params.lockedFbtcAdmin);

    // 2: Deploy the beacon and implementation
    UpgradeableBeacon beacon = _deployBeacon(beaconAdmin);

    // 3: Deploy the LockedFBTCFactory proxy
    FactoryDeployments memory ds = _deployLockedFBTCFactory(factoryProxyAdmin, beacon, params);

    // 4: Renounce roles if deployer is not the factoryAdmin
    _renounceRoles(factoryProxyAdmin, deployer, params.factoryAdmin);

    return ds;
}

function _createTimelockController(address deployer, address factoryAdmin) returns (TimelockController) {
    address[] memory executors = new address[](2);
    address[] memory proposers = new address[](2);
    proposers[0] = factoryAdmin;
    proposers[1] = deployer;
    executors[0] = factoryAdmin;
    executors[1] = deployer;

    return new TimelockController(0, proposers, executors, deployer);
}

function _createTimelockControllerWithSingleExecutor(address proposer, address executor) returns (TimelockController) {
    address[] memory executors = new address[](1);
    address[] memory proposers = new address[](1);
    proposers[0] = proposer;
    executors[0] = executor;

    return new TimelockController(0, proposers, executors, executor);
}

function _deployBeacon(TimelockController beaconAdmin) returns (UpgradeableBeacon) {
    LockedFBTC lockedFbtcImpl = new LockedFBTC();
    UpgradeableBeacon beacon = new UpgradeableBeacon(address(lockedFbtcImpl));
    beacon.transferOwnership(address(beaconAdmin));
    return beacon;
}

function _deployLockedFBTCFactory(
    TimelockController factoryProxyAdmin,
    UpgradeableBeacon beacon,
    FactoryDeploymentParams memory params
) returns (FactoryDeployments memory) {
    // Create an empty contract for the proxy
    EmptyContract empty = new EmptyContract();

    // Create proxy for the LockedFBTCFactory
    LockedFBTCFactory factory = LockedFBTCFactory(address(newProxy(empty, factoryProxyAdmin)));

    // Initialize the factory with the given parameters
    factory = initLockedFBTCFactory(
        factoryProxyAdmin,
        ITransparentUpgradeableProxy(address(factory)),
        LockedFBTCFactory.Params({
            _factoryAdmin: params.factoryAdmin,
            _beaconAddress: address(beacon),
            _fbtcAddress: params.fbtcAddress,
            _fbtcBridgeAddress: params.fireBrdigeAddress,
            _lockedFbtcAdmin: params.lockedFbtcAdmin,
            _pausers: params.pausers,
            _safetyCommittee: params.safetyCommittee
        })
    );

    // Prepare the deployments struct to return
    FactoryDeployments memory ds = FactoryDeployments({
        factoryProxyAdmin: factoryProxyAdmin,
        lockedFBTCFactory: factory,
        beacon: beacon
    });

    return ds;
}

function _renounceRoles(
    TimelockController factoryProxyAdmin,
    address deployer,
    address factoryAdmin
) {
    if (deployer != factoryAdmin) {
        factoryProxyAdmin.grantRole(factoryProxyAdmin.TIMELOCK_ADMIN_ROLE(), factoryAdmin);
        factoryProxyAdmin.renounceRole(factoryProxyAdmin.TIMELOCK_ADMIN_ROLE(), deployer);
        factoryProxyAdmin.renounceRole(factoryProxyAdmin.PROPOSER_ROLE(), deployer);
        factoryProxyAdmin.renounceRole(factoryProxyAdmin.EXECUTOR_ROLE(), deployer);
    }
}

function newProxy(EmptyContract empty, TimelockController admin) returns (TransparentUpgradeableProxy) {
    return new TransparentUpgradeableProxy(address(empty), address(admin), "");
}

function initLockedFBTCFactory(
    TimelockController factoryProxyAdmin,
    ITransparentUpgradeableProxy proxy,
    LockedFBTCFactory.Params memory params
) returns (LockedFBTCFactory) {
    LockedFBTCFactory impl = new LockedFBTCFactory();
    console.log("LockedFBTCFactory Impl: ", address(impl));

    // Initialize the factory with beacon and other params
    upgradeToAndCall(
        factoryProxyAdmin,
        proxy,
        address(impl),
        abi.encodeCall(LockedFBTCFactory.initialize, params)
    );

    return LockedFBTCFactory(address(proxy));
}

function upgradeToAndCall(
    TimelockController controller,
    ITransparentUpgradeableProxy proxy,
    address implementation,
    bytes memory data
) {
    controller.schedule({
        target: address(proxy),
        value: 0,
        data: abi.encodeCall(ITransparentUpgradeableProxy.upgradeToAndCall, (implementation, data)),
        predecessor: bytes32(0),
        salt: bytes32(0),
        delay: 0
    });
    controller.execute({
        target: address(proxy),
        value: 0,
        payload: abi.encodeCall(ITransparentUpgradeableProxy.upgradeToAndCall, (implementation, data)),
        predecessor: bytes32(0),
        salt: bytes32(0)
    });
}
