// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LockedFBTC} from "../src/LockedFBTC.sol";
import {LockedFBTCFactory, ProtocolEvents} from "../src/LockedFBTCFactory.sol";
import {BaseTest, Fbtc0Mock, MockFireBridge} from "./BaseTest.sol";
import {Create2Deployer} from "./utils/Create2Deployer.sol";
import {newProxyWithAdmin, newLockedFBTC, newLockedFBTCFactory} from "./utils/Deploy.s.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {
ITransparentUpgradeableProxy,
TransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Request} from "../src/Common.sol";
import {console2 as console} from "forge-std/console2.sol";

contract LockedFBTCFactoryV2 is LockedFBTCFactory {
    function getPauserLength() public view returns (uint256){
        return pausers.length;
    }
}

contract LockedFBTCFactoryTest is BaseTest {

    LockedFBTCFactory public lockedFBTCFactory;
    LockedFBTC public lockedFBTCImpl;
    LockedFBTC public lockedFBTC;
    Fbtc0Mock public fbtc0Mock;
    MockFireBridge public mockBridge;
    Create2Deployer public create2Deployer;
    LockedFBTCFactoryV2 public lockedFBTCFactoryV2;
    address public immutable newAdmin = makeAddr("admin1");

    function setUp() public {
        fbtc0Mock = new Fbtc0Mock();
        mockBridge = new MockFireBridge(address(fbtc0Mock));
        create2Deployer = new Create2Deployer();
        lockedFBTCImpl = new LockedFBTC();
        lockedFBTCFactory = LockedFBTCFactory(address(newProxyWithAdmin(proxyAdmin)));
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(lockedFBTCImpl));
        address[] memory pausers = new address[](1);
        pausers[0] = pauser;

        bytes32 salt = keccak256(abi.encodePacked(address(fbtc0Mock)));

        lockedFBTCFactory = newLockedFBTCFactory(
            proxyAdmin,
            ITransparentUpgradeableProxy(address(lockedFBTCFactory)),
            LockedFBTCFactory.Params({
                _factoryAdmin: factoryAdmin,
                _beaconAddress: address(beacon),
                _fbtcAddress: address(fbtc0Mock),
                _fbtcBridgeAddress: address(mockBridge),
                _lockedFbtcAdmin: lockedFbtcAdmin,
                _pausers: pausers,
                _safetyCommittee: safetyCommittee
            }),
            salt,
            address(create2Deployer)
        );

        // Mint some mock tokens to user
        fbtc0Mock.mint(user, 1000 * 10 ** 8);
        fbtc0Mock.mint(minter, 500 * 10 ** 8);

        vm.startPrank(minter);
        vm.deal(minter, 1 ether);
        address fbtc1 = lockedFBTCFactory.createLockedFBTC(minter, "name", "symbol");
        lockedFBTC = LockedFBTC(fbtc1);
        console.log("created fbtc1 address: %s", address(fbtc1));
        assertEq(lockedFBTCFactory.getCreatedLockedFBTCs()[0], fbtc1);

    }

}

contract LockedFBTCBasicTest is LockedFBTCFactoryTest, ProtocolEvents {

    function testDeployLockedFBTC() public {
        vm.startPrank(minter);
        vm.deal(minter, 1 ether);
        address fbtc1 = lockedFBTCFactory.createLockedFBTC(minter, "name", "symbol");
        lockedFBTC = LockedFBTC(fbtc1);

        console.log("test fbtc1 address: %s", address(fbtc1));

        assertEq(lockedFBTCFactory.getCreatedLockedFBTCs()[1], fbtc1);
    }

    function testSetAdminAddress() public {

        vm.startPrank(factoryAdmin);
        vm.expectEmit(true, true, true, true);
        // Verify that the ProtocolConfigChanged event has been triggered.
        emit ProtocolConfigChanged(
            lockedFBTCFactory.setAdmin.selector,
            "setAdmin(address)",
            abi.encode(newAdmin)
        );
        lockedFBTCFactory.setAdmin(newAdmin);
        assertEq(lockedFBTCFactory.lockedFbtcAdmin(), newAdmin);
    }

    function testSetAdminAccessControl() public {
        vm.startPrank(factoryAdmin);

        bytes32 adminRole = lockedFBTCFactory.DEFAULT_ADMIN_ROLE();
        assertTrue(lockedFBTCFactory.hasRole(adminRole, factoryAdmin));

        vm.stopPrank();

        vm.startPrank(address(1));
        vm.expectRevert();
        lockedFBTCFactory.setAdmin(address(2));

        vm.stopPrank();
    }

    function testRevertWhenSetAdmin() public {
        vm.startPrank(factoryAdmin);
        vm.expectRevert("Admin cannot be zero address");
        address newAdminAddress = address(0);
        lockedFBTCFactory.setAdmin(newAdminAddress);
        vm.stopPrank();
    }

    function testInitialization() public {
        assertEq(lockedFBTCFactory.fbtcAddress(), address(fbtc0Mock));
        assertEq(lockedFBTCFactory.fbtcBridgeAddress(), address(mockBridge));
        assertEq(lockedFBTCFactory.lockedFbtcAdmin(), lockedFbtcAdmin);
        assertEq(lockedFBTCFactory.safetyCommittee(), safetyCommittee);
    }

    function testCreateLockedFBTC() public {
        vm.startPrank(factoryAdmin);
        string memory name = "Test Locked FBTC";
        string memory symbol = "TLF";
        vm.deal(factoryAdmin, 1 ether);

        vm.expectEmit(true, false, false, false);
        emit LockedFBTCDeployed(minter, address(0));

        address f1ProxyAddress = lockedFBTCFactory.createLockedFBTC(minter, name, symbol);

        assertTrue(f1ProxyAddress != address(0), "Proxy address should be valid");
        vm.stopPrank();
    }

    function testPauseAndUnpauseAccessControl() public {
        vm.startPrank(address(1));
        vm.expectRevert();
        lockedFBTCFactory.pause();
        assertFalse(lockedFBTCFactory.paused());
        vm.expectRevert();
        lockedFBTCFactory.unpause();
        assertFalse(lockedFBTCFactory.paused());
        vm.stopPrank();
    }

    function testPauseAndUnpause() public {
        vm.startPrank(factoryAdmin);
        lockedFBTCFactory.pause();
        assertTrue(lockedFBTCFactory.paused());
        lockedFBTCFactory.unpause();
        assertFalse(lockedFBTCFactory.paused());
        vm.stopPrank();
    }

    function testCreateRevertWhenPaused() public {
        vm.startPrank(factoryAdmin);
        lockedFBTCFactory.pause();
        vm.expectRevert("Pausable: paused");
        lockedFBTCFactory.createLockedFBTC(minter, "Test Locked FBTC", "TLF");
        vm.stopPrank();
    }

    function testSetFbtcAccessControl() public {
        vm.startPrank(factoryAdmin);
        bytes32 adminRole = lockedFBTCFactory.DEFAULT_ADMIN_ROLE();
        assertTrue(lockedFBTCFactory.hasRole(adminRole, factoryAdmin));
        vm.stopPrank();

        vm.startPrank(address(1));
        vm.expectRevert();
        lockedFBTCFactory.setFbtcAddress(address(2));
        vm.stopPrank();
    }

    function testRevertSetFbtcAddress() public {
        vm.startPrank(factoryAdmin);

        address newFbtcAddress = address(0);
        vm.expectRevert("FBTC cannot be zero address");
        lockedFBTCFactory.setFbtcAddress(newFbtcAddress);

        vm.stopPrank();
    }

    function testSetFbtcAddress() public {
        vm.startPrank(factoryAdmin);
        address newFbtcAddress = address(1);

        vm.expectEmit(true, true, true, true);
        emit ProtocolConfigChanged(
            lockedFBTCFactory.setFbtcAddress.selector,
            "setFbtcAddress(address)",
            abi.encode(newFbtcAddress)
        );

        lockedFBTCFactory.setFbtcAddress(newFbtcAddress);
        assertEq(lockedFBTCFactory.fbtcAddress(), newFbtcAddress);

        vm.stopPrank();
    }

    function testSetFbtcBridgeAddressControl() public {
        vm.startPrank(factoryAdmin);

        bytes32 adminRole = lockedFBTCFactory.DEFAULT_ADMIN_ROLE();
        assertTrue(lockedFBTCFactory.hasRole(adminRole, factoryAdmin));

        vm.stopPrank();

        vm.startPrank(address(1));
        vm.expectRevert();
        lockedFBTCFactory.setFbtcBridgeAddress(address(2));
        vm.stopPrank();
    }

    function testRevertSetFbtcBridgeAddress() public {
        vm.startPrank(factoryAdmin);

        address newFbtcBridgeAddress = address(0);
        vm.expectRevert("FBTC Bridge cannot be zero address");
        lockedFBTCFactory.setFbtcBridgeAddress(newFbtcBridgeAddress);

        vm.stopPrank();
    }

    function testSetFbtcBridgeAddress() public {
        vm.startPrank(factoryAdmin);
        address newFbtcAddress = address(1);

        vm.expectEmit(true, true, true, true);
        emit ProtocolConfigChanged(
            lockedFBTCFactory.setFbtcAddress.selector,
            "setFbtcAddress(address)",
            abi.encode(newFbtcAddress)
        );

        lockedFBTCFactory.setFbtcAddress(newFbtcAddress);
        assertEq(lockedFBTCFactory.fbtcAddress(), newFbtcAddress);

        vm.stopPrank();
    }

    function testSetPauserAddressControl() public {
        vm.startPrank(factoryAdmin);

        bytes32 adminRole = lockedFBTCFactory.DEFAULT_ADMIN_ROLE();
        assertTrue(lockedFBTCFactory.hasRole(adminRole, factoryAdmin));

        vm.stopPrank();

        address[] memory pausers = new address[](3);
        pausers[0] = address(0);
        pausers[1] = address(1);
        pausers[2] = address(2);

        vm.startPrank(address(1));
        vm.expectRevert();
        lockedFBTCFactory.setPausers(pausers);
        vm.stopPrank();
    }

    function testRevertSetPauser() public {
        vm.startPrank(factoryAdmin);

        vm.expectRevert("Pausers array cannot be empty");
        address[] memory pausers;
        lockedFBTCFactory.setPausers(pausers);

        vm.stopPrank();
    }

    /// @notice The inserted array will replace the original pauser array
    function testSetPauser() public {
        vm.startPrank(factoryAdmin);

        address[] memory pausers = new address[](3);
        pausers[0] = address(0);
        pausers[1] = address(1);
        pausers[2] = address(2);

        vm.expectEmit(true, true, true, true);
        emit ProtocolConfigChanged(
            lockedFBTCFactory.setPausers.selector,
            "setPausers(address)",
            abi.encode(pausers)
        );

        lockedFBTCFactory.setPausers(pausers);
        assertEq(lockedFBTCFactory.pausers(0), pausers[0]);
        assertEq(lockedFBTCFactory.pausers(1), pausers[1]);
        assertEq(lockedFBTCFactory.pausers(2), pausers[2]);

        vm.stopPrank();
    }

    function testSetSafetyCommitteeAddressControl() public {
        address oldSafetyCommittee = lockedFBTCFactory.safetyCommittee();
        address newSafetyCommittee = address(2);

        vm.startPrank(factoryAdmin);
        bytes32 adminRole = lockedFBTCFactory.DEFAULT_ADMIN_ROLE();
        assertTrue(lockedFBTCFactory.hasRole(adminRole, factoryAdmin));
        vm.stopPrank();

        vm.startPrank(address(1));
        vm.expectRevert();
        lockedFBTCFactory.setSafetyCommittee(newSafetyCommittee);

        vm.assertEq(lockedFBTCFactory.safetyCommittee(), oldSafetyCommittee);
        vm.assertNotEq(oldSafetyCommittee, newSafetyCommittee);
        vm.stopPrank();
    }

    function testRevertSafetyCommittee() public {
        address oldSafetyCommittee = lockedFBTCFactory.safetyCommittee();
        address zeroSafetyCommittee = address(0);

        vm.startPrank(factoryAdmin);
        vm.expectRevert("SafetyCommittee cannot be zero address");
        lockedFBTCFactory.setSafetyCommittee(zeroSafetyCommittee);

        vm.assertEq(lockedFBTCFactory.safetyCommittee(), oldSafetyCommittee);
        vm.assertNotEq(oldSafetyCommittee, zeroSafetyCommittee);
        vm.stopPrank();
    }

    function testSafetyCommittee() public {
        address oldSafetyCommittee = lockedFBTCFactory.safetyCommittee();
        address newSafetyCommittee = address(1);

        vm.startPrank(factoryAdmin);
        vm.expectEmit(true, true, true, true);
        emit ProtocolConfigChanged(
            lockedFBTCFactory.setSafetyCommittee.selector,
            "setSafetyCommittee(address)",
            abi.encode(newSafetyCommittee)
        );

        lockedFBTCFactory.setSafetyCommittee(newSafetyCommittee);

        vm.assertEq(lockedFBTCFactory.safetyCommittee(), newSafetyCommittee);
        vm.assertNotEq(lockedFBTCFactory.safetyCommittee(), oldSafetyCommittee);
        vm.stopPrank();
    }

    function testGetCreatedLockedFBTCs() public {
        vm.startPrank(factoryAdmin);
        string memory name = "Test Locked FBTC";
        string memory symbol = "TLF";
        vm.deal(factoryAdmin, 1 ether);
        vm.expectEmit(true, false, false, false);
        emit LockedFBTCDeployed(minter, address(0));
        address f1ProxyAddress = lockedFBTCFactory.createLockedFBTC(minter, name, symbol);
        address[] memory lockedFBTCs = lockedFBTCFactory.getCreatedLockedFBTCs();
        assertTrue(f1ProxyAddress != address(0), "Proxy address should be valid");
        assertEq(lockedFBTCs[(lockedFBTCs.length - 1)], f1ProxyAddress, "Minter to proxy mapping is incorrect");
        vm.stopPrank();
    }

}

contract LockedFBTCTest is LockedFBTCBasicTest {
    function testMintLockedFBTCRequest() public {
        vm.startPrank(minter);
        vm.deal(minter, 1 ether);

        console.log("test LockedFBTC address: %s", address(lockedFBTC));
        fbtc0Mock.approve(address(lockedFBTC), 500 * 10 ** 8);
        lockedFBTC.mintLockedFbtcRequest(500 * 10 ** 8);

        bytes32 requestHash = keccak256(abi.encodePacked(lockedFBTC));
        Request memory lastRequest = mockBridge.getRequest(requestHash);

        uint256 expectedBalance = 500 * 10 ** 8 - lastRequest.fee;
        uint256 lockedFBTCBalance = lockedFBTC.balanceOf(minter);

        assertEq(lockedFBTCBalance, expectedBalance, "Minted LockedFBTC balance mismatch");

        vm.stopPrank();
    }

    function testRedeemFbtcRequest() public {
        vm.startPrank(minter);

        fbtc0Mock.approve(address(lockedFBTC), 500 * 10 ** 8);
        lockedFBTC.mintLockedFbtcRequest(500 * 10 ** 8);

        (bytes32 mintRequestHash, Request memory request) =
                            mockBridge.addMintRequest(300 * 10 ** 8, bytes32("0xabc"), 1);

        lockedFBTC.redeemFbtcRequest(300 * 10 ** 8, bytes32("0xabc"), 1);

        assertTrue(mintRequestHash != bytes32(0), "Mint request hash should not be zero");
        assertTrue(request.amount == 300 * 10 ** 8, "Mint request amount mismatch");
    }

    function testConfirmRedeemFbtc() public {
        vm.startPrank(minter);

        fbtc0Mock.approve(address(lockedFBTC), 500 * 10 ** 8);
        lockedFBTC.mintLockedFbtcRequest(500 * 10 ** 8);

        (bytes32 mintRequestHash, Request memory request) = lockedFBTC.redeemFbtcRequest(300 * 10 ** 8, bytes32("0xabc"), 1);

        mockBridge.confirmMintRequest(mintRequestHash);

        lockedFBTC.confirmRedeemFbtc(300 * 10 ** 8);

        uint256 fbtc0Balance = fbtc0Mock.balanceOf(minter);
        assertEq(fbtc0Balance, 300 * 10 ** 8, "Redeemed FBTC0 balance mismatch");
    }

    function testBurn() public {
        vm.startPrank(minter);
        vm.deal(minter, 1 ether);
        fbtc0Mock.approve(address(lockedFBTC), 500 * 10 ** 8);
        uint256 realAmount = lockedFBTC.mintLockedFbtcRequest(500 * 10 ** 8);

        bytes32 requestHash = keccak256(abi.encodePacked(lockedFBTC));
        Request memory lastRequest = mockBridge.getRequest(requestHash);

        uint256 expectedBalance = 500 * 10 ** 8 - lastRequest.fee;
        vm.startPrank(minter);
        lockedFBTC.burn(expectedBalance);

        uint256 lockedFBTCBalance = lockedFBTC.balanceOf(minter);
        assertEq(lockedFBTCBalance, realAmount - expectedBalance, "Burn balance mismatch");
    }

    function testEmergencyBurn() public {
        vm.startPrank(minter);
        vm.deal(minter, 1 ether);
        fbtc0Mock.approve(address(lockedFBTC), 500 * 10 ** 8);
        uint256 realAmount = lockedFBTC.mintLockedFbtcRequest(500 * 10 ** 8);
        vm.startPrank(safetyCommittee);
        lockedFBTC.emergencyBurn(minter, 200 * 10 ** 8);

        uint256 lockedFBTCBalance = lockedFBTC.balanceOf(minter);
        assertEq(lockedFBTCBalance, realAmount - 200 * 10 ** 8, "Emergency burn balance mismatch");
    }

    function testTransfer() public {
        vm.startPrank(user);

        vm.expectRevert("lockedFBTC: transfers are disabled");
        lockedFBTC.transfer(address(0x6), 100 * 10 ** 8);
    }

    function testTransferFrom() public {
        vm.startPrank(user);

        vm.expectRevert("lockedFBTC: transfers are disabled");
        lockedFBTC.transferFrom(user, address(0x6), 100 * 10 ** 8);
    }

    function testPause() public {
        vm.startPrank(minter);
        vm.expectRevert(missingRoleError(minter, keccak256("PAUSER_ROLE")));
        lockedFBTC.pause();

        // Pause by authorized pauser should succeed
        vm.startPrank(pauser);
        lockedFBTC.pause();

        assertTrue(lockedFBTC.paused(), "Contract should be paused.");
    }

    function testUnpause() public {
        vm.startPrank(pauser);
        lockedFBTC.pause();
        assertTrue(lockedFBTC.paused(), "Contract should be paused.");

        // Attempt to unpause by non-authorized user should fail
        vm.startPrank(minter);
        vm.expectRevert(missingRoleError(minter, 0x00));
        lockedFBTC.unpause();

        // Unpause by authorized pauser should succeed
        vm.startPrank(lockedFbtcAdmin);
        lockedFBTC.unpause();

        assertFalse(lockedFBTC.paused(), "Contract should be unpaused.");
    }
}