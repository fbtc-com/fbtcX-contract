// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {LockedFBTC} from "../../src/LockedFBTC.sol";

import {initLockedFBTC} from "../../script/helpers/Proxy.sol";
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
    address pauser,
    address minter,
    address safetyCommittee
) returns (LockedFBTC) {
    return initLockedFBTC(proxyAdmin, proxy, fbtcAddress, fireBrdigeAddress, admin, pauser, minter, safetyCommittee);
}

function testDeployAll(DeploymentParams memory params, address deployer) returns (Deployments memory) {
    Deployments memory deps = deployAll(params, deployer);
    return deps;
}
