// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {
    ITransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {LockedFBTCV2} from "../src/LockedFBTCV2.sol";

interface ILockedFBTCV2Access {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function PAUSER_ROLE() external view returns (bytes32);
    function MINTER_ROLE() external view returns (bytes32);
    function SAFETY_COMMITTEE_ROLE() external view returns (bytes32);
    function MIGRATOR_ROLE() external view returns (bytes32);
    function VERSION() external view returns (string memory);
    function fbtcBridge() external view returns (address);
    function fbtc() external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function paused() external view returns (bool);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
}

abstract contract TransparentLockedFBTCV2UpgradeBase is Script {
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
    bytes32 internal constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

    function _checkChain() internal view {
        require(block.chainid == vm.envUint("CHAIN_ID"), "wrong chain");
    }

    function _proxy() internal view returns (address) {
        return vm.envAddress("LOCKED_FBTC_PROXY");
    }

    function _timelock() internal view returns (TimelockController) {
        return TimelockController(payable(vm.envAddress("PROXY_ADMIN_TIMELOCK")));
    }

    function _newImplementation() internal view returns (address) {
        return vm.envAddress("LOCKED_FBTC_V2_IMPLEMENTATION");
    }

    function _expectedOldImplementation() internal view returns (address) {
        return vm.envAddress("EXPECTED_OLD_IMPLEMENTATION");
    }

    function _operationSalt() internal view returns (bytes32) {
        return vm.envBytes32("OPERATION_SALT");
    }

    function _requireContract(address account) internal view {
        require(account != address(0) && account.code.length > 0, "address is not a contract");
    }

    function _slotAddress(address account, bytes32 slot) internal view returns (address) {
        return address(uint160(uint256(vm.load(account, slot))));
    }

    function _proxyImplementation(address proxy) internal view returns (address) {
        return _slotAddress(proxy, IMPLEMENTATION_SLOT);
    }

    function _proxyAdmin(address proxy) internal view returns (address) {
        return _slotAddress(proxy, ADMIN_SLOT);
    }

    function _proxyBeacon(address proxy) internal view returns (address) {
        return _slotAddress(proxy, BEACON_SLOT);
    }

    function _requireTransparentProxy(address proxy, address timelock) internal view {
        _requireContract(proxy);
        _requireContract(timelock);
        require(_proxyAdmin(proxy) == timelock, "unexpected proxy admin");
        require(_proxyBeacon(proxy) == address(0), "proxy uses a beacon");
        _requireContract(_proxyImplementation(proxy));
    }

    function _requireV2Implementation(address implementation) internal view {
        _requireContract(implementation);
        require(
            keccak256(bytes(ILockedFBTCV2Access(implementation).VERSION())) == keccak256(bytes("2.0")),
            "wrong V2 implementation"
        );
    }

    function _upgradeCalldata(address implementation) internal pure returns (bytes memory) {
        return abi.encodeCall(ITransparentUpgradeableProxy.upgradeTo, (implementation));
    }

    function _operationId(TimelockController timelock, address proxy, address implementation, bytes32 salt)
        internal
        view
        returns (bytes32)
    {
        return timelock.hashOperation(proxy, 0, _upgradeCalldata(implementation), bytes32(0), salt);
    }

    function _requireExpectedState(address proxy) internal view {
        ILockedFBTCV2Access token = ILockedFBTCV2Access(proxy);
        require(token.fbtc() == vm.envAddress("EXPECTED_FBTC"), "FBTC changed");
        require(token.fbtcBridge() == vm.envAddress("EXPECTED_FBTC_BRIDGE"), "bridge changed");
        require(token.decimals() == vm.envUint("EXPECTED_DECIMALS"), "decimals changed");
        require(token.totalSupply() == vm.envUint("EXPECTED_TOTAL_SUPPLY"), "total supply changed");
        require(token.paused() == vm.envBool("EXPECTED_PAUSED"), "pause state changed");
        require(keccak256(bytes(token.name())) == keccak256(bytes(vm.envString("EXPECTED_NAME"))), "name changed");
        require(keccak256(bytes(token.symbol())) == keccak256(bytes(vm.envString("EXPECTED_SYMBOL"))), "symbol changed");
        require(
            token.hasRole(token.DEFAULT_ADMIN_ROLE(), vm.envAddress("EXPECTED_TOKEN_ADMIN")), "token admin role changed"
        );
        require(token.hasRole(token.PAUSER_ROLE(), vm.envAddress("EXPECTED_PAUSER")), "pauser role changed");
        require(token.hasRole(token.MINTER_ROLE(), vm.envAddress("EXPECTED_MINTER")), "minter role changed");
        require(
            token.hasRole(token.SAFETY_COMMITTEE_ROLE(), vm.envAddress("EXPECTED_SAFETY_COMMITTEE")),
            "safety committee role changed"
        );
    }

    function _startBroadcast() internal returns (address signer) {
        signer = vm.envAddress("SIGNER");
        require(signer != address(0), "SIGNER is zero");
        vm.startBroadcast();
    }
}

/// @notice Deploys only the V2 implementation and never changes a proxy.
contract DeployLockedFBTCV2Implementation is TransparentLockedFBTCV2UpgradeBase {
    function run() external returns (address implementation) {
        _checkChain();
        _startBroadcast();
        implementation = address(new LockedFBTCV2());
        vm.stopBroadcast();

        _requireV2Implementation(implementation);
        console.log("LockedFBTCV2 implementation:", implementation);
    }
}

/// @notice Read-only preflight that prints the exact Timelock operation.
contract PrepareTransparentLockedFBTCV2Upgrade is TransparentLockedFBTCV2UpgradeBase {
    function run() external view {
        _checkChain();
        address proxy = _proxy();
        TimelockController timelock = _timelock();
        address oldImplementation = _expectedOldImplementation();
        address newImplementation = _newImplementation();
        bytes32 salt = _operationSalt();

        _requireTransparentProxy(proxy, address(timelock));
        require(_proxyImplementation(proxy) == oldImplementation, "unexpected current implementation");
        require(oldImplementation != newImplementation, "implementation already active");
        _requireV2Implementation(newImplementation);
        _requireExpectedState(proxy);

        bytes memory payload = _upgradeCalldata(newImplementation);
        console.log("Transparent proxy (Timelock target):", proxy);
        console.log("Current implementation:", oldImplementation);
        console.log("New implementation:", newImplementation);
        console.log("Proxy admin Timelock:", address(timelock));
        console.log("Timelock minimum delay:", timelock.getMinDelay());
        console.log("Operation salt:");
        console.logBytes32(salt);
        console.log("Operation ID:");
        console.logBytes32(_operationId(timelock, proxy, newImplementation, salt));
        console.log("Proxy upgradeTo calldata:");
        console.logBytes(payload);
    }
}

/// @notice Schedules the TransparentUpgradeableProxy upgrade through its direct Timelock admin.
contract ScheduleTransparentLockedFBTCV2Upgrade is TransparentLockedFBTCV2UpgradeBase {
    function run() external {
        _checkChain();
        address proxy = _proxy();
        TimelockController timelock = _timelock();
        address oldImplementation = _expectedOldImplementation();
        address newImplementation = _newImplementation();
        bytes32 salt = _operationSalt();

        _requireTransparentProxy(proxy, address(timelock));
        require(_proxyImplementation(proxy) == oldImplementation, "unexpected current implementation");
        require(oldImplementation != newImplementation, "implementation already active");
        _requireV2Implementation(newImplementation);
        _requireExpectedState(proxy);

        address signer = _startBroadcast();
        require(timelock.hasRole(timelock.PROPOSER_ROLE(), signer), "SIGNER is not proposer");
        timelock.schedule(proxy, 0, _upgradeCalldata(newImplementation), bytes32(0), salt, timelock.getMinDelay());
        vm.stopBroadcast();

        console.log("Scheduled operation ID:");
        console.logBytes32(_operationId(timelock, proxy, newImplementation, salt));
    }
}

/// @notice Executes an already-ready TransparentUpgradeableProxy upgrade through its direct Timelock admin.
contract ExecuteTransparentLockedFBTCV2Upgrade is TransparentLockedFBTCV2UpgradeBase {
    function run() external {
        _checkChain();
        address proxy = _proxy();
        TimelockController timelock = _timelock();
        address oldImplementation = _expectedOldImplementation();
        address newImplementation = _newImplementation();
        bytes32 salt = _operationSalt();

        _requireTransparentProxy(proxy, address(timelock));
        require(_proxyImplementation(proxy) == oldImplementation, "unexpected current implementation");
        _requireV2Implementation(newImplementation);
        _requireExpectedState(proxy);
        bytes32 operationId = _operationId(timelock, proxy, newImplementation, salt);
        require(timelock.isOperationReady(operationId), "operation is not ready");

        address signer = _startBroadcast();
        require(
            timelock.hasRole(timelock.EXECUTOR_ROLE(), signer)
                || timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)),
            "SIGNER is not executor"
        );
        timelock.execute(proxy, 0, _upgradeCalldata(newImplementation), bytes32(0), salt);
        vm.stopBroadcast();

        require(_proxyImplementation(proxy) == newImplementation, "proxy upgrade failed");
        _requireExpectedState(proxy);
    }
}

/// @notice Read-only preflight that prints target-token grantRole calldata.
contract PrepareLockedFBTCMigratorRole is TransparentLockedFBTCV2UpgradeBase {
    function run() external view {
        _checkChain();
        address proxy = _proxy();
        TimelockController timelock = _timelock();
        address implementation = _newImplementation();
        address migrator = vm.envAddress("LOCKED_FBTC_MIGRATOR_PROXY");

        _requireTransparentProxy(proxy, address(timelock));
        require(_proxyImplementation(proxy) == implementation, "V2 is not active");
        _requireContract(migrator);
        ILockedFBTCV2Access token = ILockedFBTCV2Access(proxy);
        require(token.MIGRATOR_ROLE() == MIGRATOR_ROLE, "wrong MIGRATOR_ROLE");

        console.log("grantRole target (LockedFBTC proxy):", proxy);
        console.log("Migrator proxy:", migrator);
        console.log("grantRole calldata:");
        console.logBytes(abi.encodeCall(ILockedFBTCV2Access.grantRole, (MIGRATOR_ROLE, migrator)));
    }
}

/// @notice Grants MIGRATOR_ROLE on this token proxy only, after V2 is active.
contract GrantLockedFBTCMigratorRole is TransparentLockedFBTCV2UpgradeBase {
    function run() external {
        _checkChain();
        address proxy = _proxy();
        TimelockController timelock = _timelock();
        address implementation = _newImplementation();
        address migrator = vm.envAddress("LOCKED_FBTC_MIGRATOR_PROXY");

        _requireTransparentProxy(proxy, address(timelock));
        require(_proxyImplementation(proxy) == implementation, "V2 is not active");
        _requireContract(migrator);
        ILockedFBTCV2Access token = ILockedFBTCV2Access(proxy);
        require(token.MIGRATOR_ROLE() == MIGRATOR_ROLE, "wrong MIGRATOR_ROLE");
        if (token.hasRole(MIGRATOR_ROLE, migrator)) return;

        address signer = _startBroadcast();
        require(token.hasRole(token.getRoleAdmin(MIGRATOR_ROLE), signer), "SIGNER is not role admin");
        token.grantRole(MIGRATOR_ROLE, migrator);
        vm.stopBroadcast();
        require(token.hasRole(MIGRATOR_ROLE, migrator), "MIGRATOR_ROLE grant failed");
    }
}

/// @notice Read-only post-upgrade and post-role-grant verification.
contract VerifyTransparentLockedFBTCV2Upgrade is TransparentLockedFBTCV2UpgradeBase {
    function run() external view {
        _checkChain();
        address proxy = _proxy();
        TimelockController timelock = _timelock();
        address implementation = _newImplementation();
        address migrator = vm.envAddress("LOCKED_FBTC_MIGRATOR_PROXY");

        _requireTransparentProxy(proxy, address(timelock));
        require(_proxyImplementation(proxy) == implementation, "wrong implementation");
        ILockedFBTCV2Access token = ILockedFBTCV2Access(proxy);
        require(keccak256(bytes(token.VERSION())) == keccak256(bytes("2.0")), "proxy is not V2");
        require(token.MIGRATOR_ROLE() == MIGRATOR_ROLE, "wrong MIGRATOR_ROLE");
        require(token.hasRole(MIGRATOR_ROLE, migrator), "migrator role is missing");
        _requireExpectedState(proxy);

        console.log("Transparent LockedFBTC V2 upgrade verified:", proxy);
    }
}
