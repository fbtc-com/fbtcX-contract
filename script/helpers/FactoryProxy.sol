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
import {LockedFBTCBeacon} from "../../src/LockedFBTCBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {console2 as console} from "forge-std/console2.sol";

contract EmptyContract {}

interface ICreate2Deployer {
    function deploy(uint256 value, bytes32 salt, bytes memory code) external;
    function computeAddress(bytes32 salt, bytes32 codeHash) external view returns (address);
}

struct FactoryDeployments {
    TimelockController factoryProxyAdmin;
    TimelockController beaconAdmin;
    LockedFBTCFactory lockedFBTCFactory;
    LockedFBTCBeacon beacon;
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
    address create2Deployer;
}

function deployFactoryAll(FactoryDeploymentParams memory params) returns (FactoryDeployments memory) {
    return deployFactoryAll(params, msg.sender);
}

/// @notice Deploys the LockedFBTCFactory and its proxy contracts, initializes them, and returns their addresses.
/// @param params Configuration for deployment.
/// @param deployer The address executing the deployment.
function deployFactoryAll(FactoryDeploymentParams memory params, address deployer) returns (FactoryDeployments memory) {

    bytes32 salt = keccak256(abi.encodePacked(address(params.fbtcAddress)));

    // 1: Create proxy admins
    TimelockController factoryProxyAdmin = _createTimelockController(deployer, params.factoryAdmin, salt, params.create2Deployer);
    TimelockController beaconAdmin = _createTimelockControllerWithSingleExecutor(params.proposer, params.lockedFbtcAdmin, salt, params.create2Deployer);

    // 2: Deploy the beacon and implementation
    LockedFBTCBeacon beacon = _deployBeacon(beaconAdmin, salt, params.create2Deployer);

    // 3: Deploy the LockedFBTCFactory proxy
    FactoryDeployments memory ds = _deployLockedFBTCFactory(factoryProxyAdmin, beaconAdmin, beacon, params, salt);

    // 4: Renounce roles if deployer is not the factoryAdmin
    _renounceRoles(factoryProxyAdmin, deployer, params.factoryAdmin);

    return ds;
}

function _createTimelockController(address deployer, address factoryAdmin, bytes32 salt, address create2Deployer) returns (TimelockController) {
    address[] memory executors = new address[](2);
    address[] memory proposers = new address[](2);
    proposers[0] = factoryAdmin;
    proposers[1] = deployer;
    executors[0] = factoryAdmin;
    executors[1] = deployer;

    bytes memory bytecode = abi.encodePacked(type(TimelockController).creationCode, abi.encode(0, proposers, executors, deployer));

    // Use ICreate2Deployer to deploy the contract via CREATE2
    ICreate2Deployer(create2Deployer).deploy(0, salt, bytecode);
    return TimelockController(payable(ICreate2Deployer(create2Deployer).computeAddress(salt, keccak256(bytecode))));
}

function _createTimelockControllerWithSingleExecutor(address proposer, address executor, bytes32 salt, address create2Deployer) returns (TimelockController) {
    address[] memory executors = new address[](1);
    address[] memory proposers = new address[](1);
    proposers[0] = proposer;
    executors[0] = executor;

    bytes memory bytecode = abi.encodePacked(type(TimelockController).creationCode, abi.encode(0, proposers, executors, executor));

    // Use ICreate2Deployer to deploy the contract via CREATE2
    ICreate2Deployer(create2Deployer).deploy(0, salt, bytecode);

    return TimelockController(payable(ICreate2Deployer(create2Deployer).computeAddress(salt, keccak256(bytecode))));
}

function _deployBeacon(TimelockController beaconAdmin, bytes32 salt, address create2Deployer) returns (LockedFBTCBeacon) {
    bytes memory lockedFbtcBytecode = abi.encodePacked(type(LockedFBTC).creationCode);
    ICreate2Deployer(create2Deployer).deploy(0, salt, lockedFbtcBytecode);
    address lockedFbtcImplAddress = ICreate2Deployer(create2Deployer).computeAddress(salt, keccak256(lockedFbtcBytecode));

    bytes memory bytecode = abi.encodePacked(type(LockedFBTCBeacon).creationCode, abi.encode(lockedFbtcImplAddress,beaconAdmin));

    // Use ICreate2Deployer to deploy the LockedFBTCBeacon via CREATE2
    ICreate2Deployer(create2Deployer).deploy(0, salt, bytecode);

    address beaconAddress = ICreate2Deployer(create2Deployer).computeAddress(salt, keccak256(bytecode));
    LockedFBTCBeacon beacon = LockedFBTCBeacon(payable(beaconAddress));

    return beacon;
}

function _deployLockedFBTCFactory(
    TimelockController factoryProxyAdmin,
    TimelockController beaconAdmin,
    LockedFBTCBeacon beacon,
    FactoryDeploymentParams memory params,
    bytes32 salt
) returns (FactoryDeployments memory) {
    // Create an empty contract for the proxy
    bytes memory bytecode = abi.encodePacked(type(EmptyContract).creationCode);
    ICreate2Deployer(params.create2Deployer).deploy(0, salt, bytecode);
    address emptyAddress = ICreate2Deployer(params.create2Deployer).computeAddress(salt, keccak256(bytecode));

    // Create proxy for the LockedFBTCFactory
    LockedFBTCFactory factory = LockedFBTCFactory(address(newProxy(emptyAddress, factoryProxyAdmin, salt, params.create2Deployer)));

    // Initialize the factory with the given parameters
    factory = initLockedFBTCFactory(
        factoryProxyAdmin,
        ITransparentUpgradeableProxy(address(factory)),
        salt,
        params.create2Deployer,
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
        beaconAdmin: beaconAdmin,
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

function newProxy(
    address empty,
    TimelockController admin,
    bytes32 salt,
    address create2Deployer
) returns (TransparentUpgradeableProxy) {
    // Get the bytecode for the TransparentUpgradeableProxy
    bytes memory proxyCode = abi.encodePacked(
        type(TransparentUpgradeableProxy).creationCode,
        abi.encode(empty, address(admin), "")
    );

    // Deploy the proxy using CREATE2
    ICreate2Deployer(create2Deployer).deploy(0, salt, proxyCode);

    // Compute the address of the deployed proxy
    address proxyAddress = ICreate2Deployer(create2Deployer).computeAddress(salt, keccak256(proxyCode));

    return TransparentUpgradeableProxy(payable(proxyAddress));
}

function initLockedFBTCFactory(
    TimelockController factoryProxyAdmin,
    ITransparentUpgradeableProxy proxy,
    bytes32 salt,
    address create2Deployer,
    LockedFBTCFactory.Params memory params
) returns (LockedFBTCFactory) {
    bytes memory bytecode = abi.encodePacked(type(LockedFBTCFactory).creationCode);
    ICreate2Deployer(create2Deployer).deploy(0, salt, bytecode);
    address implAddress = ICreate2Deployer(create2Deployer).computeAddress(salt, keccak256(bytecode));
    console.log("LockedFBTCFactory Impl: ", implAddress);

    // Initialize the factory with beacon and other params
    upgradeToAndCall(
        factoryProxyAdmin,
        proxy,
        implAddress,
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
