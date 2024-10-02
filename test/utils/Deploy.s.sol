// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {LockedFBTC} from "../../src/LockedFBTC.sol";
import {LockedFBTCFactory} from "../../src/LockedFBTCFactory.sol";

import {initLockedFBTC} from "../../script/helpers/Proxy.sol";
import {initLockedFBTCFactory,FactoryDeploymentParams, deployFactoryAll, FactoryDeployments} from "../../script/helpers/FactoryProxy.sol";
import {EmptyContract, deployAll, DeploymentParams, Deployments} from "../../script/helpers/Proxy.sol";

function newProxyWithAdmin(TimelockController admin) returns (ITransparentUpgradeableProxy) {
    EmptyContract empty = new EmptyContract();
    return ITransparentUpgradeableProxy(address(new TransparentUpgradeableProxy(address(empty), address(admin), "")));
}

function newLockedFBTC(
    TimelockController proxyAdmin,
    ITransparentUpgradeableProxy proxy,
    address fbtcAddress,
    address fireBrdigeAddress,
    address admin,
    address[] memory pausers,
    address minter,
    address safetyCommittee,
    string memory name,
    string memory symbol
) returns (LockedFBTC) {
    return initLockedFBTC(proxyAdmin, proxy, fbtcAddress, fireBrdigeAddress, admin, pausers, minter, safetyCommittee, name, symbol);
}

function newLockedFBTCFactory(
    TimelockController proxyAdmin,
    ITransparentUpgradeableProxy proxy,
    LockedFBTCFactory.Params memory params,
    bytes32 salt,
    address create2Deployer
) returns (LockedFBTCFactory) {
    return initLockedFBTCFactory(proxyAdmin, proxy, salt, create2Deployer, params);
}

function testDeployAll(DeploymentParams memory params, address deployer) returns (Deployments memory) {
    Deployments memory deps = deployAll(params, deployer);
    return deps;
}

function testDeployFactoryAll(FactoryDeploymentParams memory params, address deployer) returns (FactoryDeployments memory) {
    FactoryDeployments memory deps = deployFactoryAll(params, deployer);
    return deps;
}
