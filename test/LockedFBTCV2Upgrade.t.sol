// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {LockedFBTC} from "../src/LockedFBTC.sol";
import {LockedFBTCV2} from "../src/LockedFBTCV2.sol";

contract LockedFBTCV2UpgradeTest is Test {
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant SALT = keccak256("LOCKED_FBTC_V2_TEST");

    address internal constant FBTC = address(0xF1);
    address internal constant BRIDGE = address(0xB1);
    address internal constant PROPOSER = address(0xA11);
    address internal constant EXECUTOR = address(0xE11);
    address internal constant MINTER_A = address(0xA1);
    address internal constant MINTER_B = address(0xB2);
    address internal constant SAFETY_COMMITTEE = address(0x5AFE);
    address internal constant MIGRATOR = address(0xA11CE);
    address internal constant RECIPIENT = address(0xCAFE);

    TimelockController internal timelock;
    LockedFBTC internal targetV1;
    LockedFBTC internal otherV1;
    address internal v1Implementation;

    function setUp() public {
        vm.warp(1_000_000);
        v1Implementation = address(new LockedFBTC());
        address[] memory proposers = new address[](1);
        proposers[0] = PROPOSER;
        address[] memory executors = new address[](1);
        executors[0] = EXECUTOR;
        timelock = new TimelockController(0, proposers, executors, address(this));

        targetV1 = LockedFBTC(_deployProxy("Target", "TGT", MINTER_A));
        otherV1 = LockedFBTC(_deployProxy("Other", "OTH", MINTER_B));
    }

    function _deployProxy(string memory name, string memory symbol, address minter) internal returns (address) {
        address[] memory pausers = new address[](1);
        pausers[0] = address(this);
        bytes memory initializer = abi.encodeCall(
            LockedFBTC.initialize, (FBTC, BRIDGE, address(this), pausers, minter, SAFETY_COMMITTEE, name, symbol)
        );
        return address(new TransparentUpgradeableProxy(v1Implementation, address(timelock), initializer));
    }

    function _implementation(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT))));
    }

    function _schedule(address proxy, address implementation) internal returns (bytes memory payload) {
        payload = abi.encodeCall(ITransparentUpgradeableProxy.upgradeTo, (implementation));
        vm.prank(PROPOSER);
        timelock.schedule(proxy, 0, payload, bytes32(0), SALT, 0);
    }

    function _execute(address proxy, bytes memory payload) internal {
        vm.prank(EXECUTOR);
        timelock.execute(proxy, 0, payload, bytes32(0), SALT);
    }

    function _upgradeTarget() internal returns (LockedFBTCV2 target, address v2Implementation) {
        v2Implementation = address(new LockedFBTCV2());
        bytes memory payload = _schedule(address(targetV1), v2Implementation);
        _execute(address(targetV1), payload);
        target = LockedFBTCV2(address(targetV1));
    }

    function testTimelockUpgradeChangesOnlyTargetProxyAndPreservesState() public {
        (LockedFBTCV2 target, address v2Implementation) = _upgradeTarget();

        assertEq(_implementation(address(targetV1)), v2Implementation);
        assertEq(_implementation(address(otherV1)), v1Implementation);
        assertEq(target.VERSION(), "2.0");
        assertEq(target.name(), "Target");
        assertEq(target.symbol(), "TGT");
        assertEq(address(target.fbtc()), FBTC);
        assertEq(address(target.fbtcBridge()), BRIDGE);
        assertEq(target.decimals(), 8);
        assertEq(target.totalSupply(), 0);
        assertFalse(target.paused());
        assertTrue(target.hasRole(target.DEFAULT_ADMIN_ROLE(), address(this)));
        assertTrue(target.hasRole(target.PAUSER_ROLE(), address(this)));
        assertTrue(target.hasRole(target.MINTER_ROLE(), MINTER_A));
        assertTrue(target.hasRole(target.SAFETY_COMMITTEE_ROLE(), SAFETY_COMMITTEE));

        (bool ok,) = address(otherV1).call(abi.encodeWithSignature("VERSION()"));
        assertFalse(ok);
        assertEq(otherV1.name(), "Other");
        assertEq(otherV1.symbol(), "OTH");
        assertTrue(otherV1.hasRole(otherV1.MINTER_ROLE(), MINTER_B));
    }

    function testMigratorRoleAndMintAreIsolatedToTargetProxy() public {
        (LockedFBTCV2 target,) = _upgradeTarget();
        target.grantRole(target.MIGRATOR_ROLE(), MIGRATOR);

        assertTrue(target.hasRole(target.MIGRATOR_ROLE(), MIGRATOR));
        assertFalse(otherV1.hasRole(keccak256("MIGRATOR_ROLE"), MIGRATOR));

        vm.prank(MIGRATOR);
        target.migrateLockedFbtc(RECIPIENT, 10);
        assertEq(target.balanceOf(RECIPIENT), 10);
        assertEq(target.totalSupply(), 10);
        assertEq(otherV1.totalSupply(), 0);
    }

    function testMigrationIntentionallyRemainsAvailableWhilePaused() public {
        (LockedFBTCV2 target,) = _upgradeTarget();
        target.grantRole(target.MIGRATOR_ROLE(), MIGRATOR);
        target.pause();

        vm.prank(MIGRATOR);
        target.migrateLockedFbtc(RECIPIENT, 1);
        assertEq(target.balanceOf(RECIPIENT), 1);
    }

    function testProxyCannotBeReinitializedAfterUpgrade() public {
        (LockedFBTCV2 target,) = _upgradeTarget();
        address[] memory pausers = new address[](1);
        pausers[0] = address(this);

        vm.expectRevert("Initializable: contract is already initialized");
        target.initialize(FBTC, BRIDGE, address(this), pausers, MINTER_A, SAFETY_COMMITTEE, "Changed", "BAD");
    }

    function testProposerCannotExecuteAndExecutorCannotSchedule() public {
        address implementation = address(new LockedFBTCV2());
        bytes memory payload = _schedule(address(targetV1), implementation);

        vm.prank(PROPOSER);
        vm.expectRevert();
        timelock.execute(address(targetV1), 0, payload, bytes32(0), SALT);

        vm.prank(EXECUTOR);
        vm.expectRevert();
        timelock.schedule(address(otherV1), 0, payload, bytes32(0), bytes32(uint256(1)), 0);
    }

    function testUnauthorizedAccountCannotUpgradeProxyDirectly() public {
        address implementation = address(new LockedFBTCV2());

        vm.prank(address(0xBAD));
        vm.expectRevert();
        ITransparentUpgradeableProxy(address(targetV1)).upgradeTo(implementation);

        assertEq(_implementation(address(targetV1)), v1Implementation);
    }
}
