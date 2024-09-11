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

contract LockedFBTCFactoryTest is BaseTest {

    LockedFBTCFactory public lockedFBTCFactory;
    LockedFBTC public lockedFBTCImpl;
    LockedFBTC public lockedFBTC;
    Fbtc0Mock public fbtc0Mock;
    MockFireBridge public mockBridge;
    Create2Deployer public create2Deployer;
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
        address fbtc1 = lockedFBTCFactory.createLockedFBTC(minter,"name","symbol");
        lockedFBTC = LockedFBTC(fbtc1);

    }

}

contract LockedFBTCBasicTest is LockedFBTCFactoryTest, ProtocolEvents {

    function testDeployLockedFBTC() public {
        vm.startPrank(minter);
        vm.deal(minter, 1 ether);
        address fbtc1 = lockedFBTCFactory.createLockedFBTC(minter,"name","symbol");
        lockedFBTC = LockedFBTC(fbtc1);
    }

    function testSetAdminAddress() public {

        vm.startPrank(factoryAdmin);
        vm.expectEmit(true,true,true,true);
        // Verify that the ProtocolConfigChanged event has been triggered.
        emit ProtocolConfigChanged(
            lockedFBTCFactory.setAdmin.selector,
            "setAdmin(address)",
            abi.encode(newAdmin)
        );
        lockedFBTCFactory.setAdmin(newAdmin);
        assertEq(lockedFBTCFactory.lockedFbtcAdmin(), newAdmin);
    }
}

contract LockedFBTCTest is LockedFBTCBasicTest {
    function testMintLockedFBTCRequest() public {
        vm.startPrank(minter);
        vm.deal(minter, 1 ether);

        console.log("LockedFBTC address: %s", address(lockedFBTC));
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