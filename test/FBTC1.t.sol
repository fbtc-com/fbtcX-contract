// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FBTC1} from "../src/FBTC1.sol";
import {BaseTest, Fbtc0Mock, MockFireBridge} from "./BaseTest.sol";
import {newProxyWithAdmin, newFbtc1Token} from "./utils/Deploy.s.sol";
import {
ITransparentUpgradeableProxy, TransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Request }  from "../src/Common.sol";
import {console2 as console} from "forge-std/console2.sol";

contract FBTC1Test is BaseTest {
    FBTC1 public fbtc1;
    Fbtc0Mock public fbtc0Mock;
    MockFireBridge public mockBridge;

    function setUp() public {

        fbtc0Mock = new Fbtc0Mock();
        mockBridge = new MockFireBridge(address(fbtc0Mock));
        fbtc1 = FBTC1(address(newProxyWithAdmin(proxyAdmin)));

        fbtc1 = newFbtc1Token(
            proxyAdmin,
            ITransparentUpgradeableProxy(address(fbtc1)),
            address(fbtc0Mock),
            address(mockBridge),
            admin,
            pauser,
            minter,
            safetyCommittee
        );

        // Mint some mock tokens to user
        fbtc0Mock.mint(user, 1000 * 10 ** 8);
        fbtc0Mock.mint(minter, 500 * 10 ** 8);

    }

}

contract FBTC1VandalTest is FBTC1Test {


    function testMintFbtc1Request() public {

        vm.startPrank(minter);
        vm.deal(minter, 1 ether);

        console.log("FBTC1 address: %s", address(fbtc1));
        fbtc0Mock.approve(address(fbtc1), 500 * 10 ** 8);
        fbtc1.mintFbtc1Request(500 * 10 ** 8);

        bytes32 requestHash = keccak256(abi.encodePacked(fbtc1)); 
        Request memory lastRequest = mockBridge.getRequest(requestHash);

        uint256 expectedBalance = 500 * 10 ** 8 - lastRequest.fee;
        uint256 fbtc1Balance = fbtc1.balanceOf(minter);

        assertEq(fbtc1Balance, expectedBalance, "Minted FBTC1 balance mismatch");

        vm.stopPrank();
    }


    function testRedeemFbtcRequest() public {
        vm.startPrank(minter);

        fbtc0Mock.approve(address(fbtc1), 500 * 10 ** 8);
        fbtc1.mintFbtc1Request(500 * 10 ** 8);

        (bytes32 mintRequestHash, Request memory request) = mockBridge.addMintRequest(300 * 10 ** 8, bytes32("0xabc"), 1);

        fbtc1.redeemFbtcRequest(300 * 10 ** 8, bytes32("0xabc"), 1);

        assertTrue(mintRequestHash != bytes32(0), "Mint request hash should not be zero");
        assertTrue(request.amount == 300 * 10 ** 8, "Mint request amount mismatch");

    }

    function testConfirmRedeemFbtc() public {
        vm.startPrank(minter);

        fbtc0Mock.approve(address(fbtc1), 500 * 10 ** 8);
        fbtc1.mintFbtc1Request(500 * 10 ** 8);

        (bytes32 mintRequestHash, Request memory request) = fbtc1.redeemFbtcRequest(300 * 10 ** 8, bytes32("0xabc"), 1);

        mockBridge.confirmMintRequest(mintRequestHash);

        fbtc1.confirmRedeemFbtc(300 * 10 ** 8);

        uint256 fbtc0Balance = fbtc0Mock.balanceOf(minter);
        assertEq(fbtc0Balance, 300 * 10 ** 8, "Redeemed FBTC0 balance mismatch");
    }

     function testEmergencyBurn() public {

        vm.startPrank(minter);
        vm.deal(minter, 1 ether);
        fbtc0Mock.approve(address(fbtc1), 500 * 10 ** 8);
        uint256 realAmount = fbtc1.mintFbtc1Request(500 * 10 ** 8);
        vm.startPrank(safetyCommittee);
        fbtc1.emergencyBurn(minter, 200 * 10 ** 8);

        uint256 fbtc1Balance = fbtc1.balanceOf(minter);
        assertEq(fbtc1Balance, realAmount - 200 * 10 ** 8, "Emergency burn balance mismatch");
    }

    function testTransfer() public {
        vm.startPrank(user);
        
        vm.expectRevert("FBTC1: transfers are disabled");
        fbtc1.transfer(address(0x6), 100 * 10 ** 8);
    }

    function testTransferFrom() public {
        vm.startPrank(user);

        vm.expectRevert("FBTC1: transfers are disabled");
        fbtc1.transferFrom(user, address(0x6), 100 * 10 ** 8);
    }

    function testPause() public {
        vm.prank(minter);
        vm.expectRevert(missingRoleError(minter,keccak256("PAUSER_ROLE")));
        fbtc1.pause();

        // Pause by authorized pauser should succeed
        vm.prank(pauser);
        fbtc1.pause();

        assertTrue(fbtc1.paused(), "Contract should be paused.");
    }

    function testUnpause() public {

        vm.prank(pauser);
        fbtc1.pause();
        assertTrue(fbtc1.paused(), "Contract should be paused.");

        // Attempt to unpause by non-authorized user should fail
        vm.prank(minter);
        vm.expectRevert(missingRoleError(minter,0x00));
        fbtc1.unpause();

        // Unpause by authorized pauser should succeed
        vm.prank(admin);
        fbtc1.unpause();

        assertFalse(fbtc1.paused(), "Contract should be unpaused.");
    }

}


