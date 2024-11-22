// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RateProvider} from "../src/FBTCRateProvider.sol";
import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

contract RateProviderTest is Test {
    RateProvider public rateProvider;

    address public admin = address(1);
    address public operator = address(2);

    function setUp() public {

        rateProvider = new RateProvider(admin, operator);
        vm.startPrank(admin);
        rateProvider.grantRole(rateProvider.DEFAULT_ADMIN_ROLE(), admin);
        rateProvider.grantRole(rateProvider.OPERATOR_ROLE(), operator);
        vm.stopPrank();
    }

    function testSetTotalSupplyFbtc() public {
        vm.startPrank(operator);

        uint256 initialSupply = 1000 * 1e8;
        rateProvider.setTotalSupplyFbtc(initialSupply);

        uint256 totalSupply = rateProvider.getTotalSupplyFbtc();
        assertEq(totalSupply, initialSupply, "Total supply of FBTC mismatch");

        vm.stopPrank();
    }

    function testSetTotalBtcInProtocol() public {
        vm.startPrank(operator);

        uint256 initialBtc = 500 * 1e8;
        rateProvider.setTotalBtcInProtocol(initialBtc);

        uint256 totalBtc = rateProvider.getTotalBtcInProtocol();
        assertEq(totalBtc, initialBtc, "Total BTC in protocol mismatch");

        vm.stopPrank();
    }

    function testUpdateBounds() public {

        uint256 totalSupply = 10000 * 1e8;
        uint256 totalBtc = 9999 * 1e8;

        vm.prank(operator);
        rateProvider.setTotalSupplyFbtc(totalSupply);
        vm.prank(operator);
        rateProvider.setTotalBtcInProtocol(totalBtc);

        uint256 rate = rateProvider.getRate();
        uint256 expectedRate = (totalBtc * 1e18) / totalSupply;
        console.log("rate: %s",rate);
        console.log("expectedRate: %s",expectedRate);
        assertEq(rate, expectedRate, "Rate outside new bounds");

        vm.prank(admin);
        uint256 newLowerBound = 9900; // 0.99
        uint256 newUpperBound = 10100; // 1.01
        rateProvider.updateBounds(newLowerBound, newUpperBound);

        vm.prank(operator);
        rateProvider.setTotalSupplyFbtc(1000 * 1e8);
        vm.prank(operator);
        rateProvider.setTotalBtcInProtocol(985 * 1e8);

        uint256 rate2 = rateProvider.getRate();
        console.log("rate2: %s",rate2);
        assertEq(rate2, rate, "Rate outside new bounds");
        vm.stopPrank();
    }

    function testGetRateOutsideBounds() public {
        vm.startPrank(operator);

        uint256 totalSupply = 1000 * 1e8;
        uint256 totalBtc = 1200 * 1e8; // Set an out-of-bound BTC value

        rateProvider.setTotalSupplyFbtc(totalSupply);
        rateProvider.setTotalBtcInProtocol(totalBtc);

        uint256 firstRate = rateProvider.getRate();
        console.log("firstRate: %s", firstRate);

        uint256 newBtc = 1001 * 1e8;
        rateProvider.setTotalBtcInProtocol(newBtc);

        // Fetch rate again, should return lastRate
        uint256 secondRate = rateProvider.getRate();
        assertEq(secondRate, 1001000000000000000, "Rate should remain unchanged outside bounds");

        vm.stopPrank();
    }

    function testUpdateRateFailsWithZeroBtc() public {
        vm.startPrank(operator);

        uint256 totalSupply = 1000 * 1e8;
        rateProvider.setTotalSupplyFbtc(totalSupply);

        vm.expectRevert("Total BTC in protocol must be greater than 0");
        rateProvider.setTotalBtcInProtocol(0);

        vm.stopPrank();
    }

    // Test that lastRate is updated correctly when within bounds
    function testLastRateUpdateWithinBounds() public {

        uint256 totalSupply = 1000 * 1e8; // 1000 FBTC
        uint256 totalBtc = 1005 * 1e8; // 1005 BTC (rate = 1.005)
        vm.prank(operator);
        rateProvider.setTotalSupplyFbtc(totalSupply);
        vm.prank(operator);
        rateProvider.setTotalBtcInProtocol(totalBtc);

        uint256 updatedRate = rateProvider.getRate();

        assertEq(updatedRate, (totalBtc * 1e18) / totalSupply, "lastRate should be updated to the computed rate");
    }

    function testLastRateUpdatesWithAdjustedBounds() public {

        uint256 totalSupply = 1000 * 1e8; // 1000 FBTC
        uint256 totalBtc = 980 * 1e8; // 980 BTC (rate = 0.98)
        vm.prank(operator);
        rateProvider.setTotalSupplyFbtc(totalSupply);
        vm.prank(operator);
        rateProvider.setTotalBtcInProtocol(totalBtc);
        uint256 oldRate = rateProvider.getRate();
        assertEq(oldRate,1e18, "lastRate should be 0");
        vm.prank(admin);
        rateProvider.updateBounds(9700, 10300); // New bounds: 0.97 - 1.03

        uint256 updatedRate = rateProvider.getRate();

        assertEq(updatedRate, (totalBtc * 1e18) / totalSupply, "lastRate should update correctly with adjusted bounds");

        vm.prank(admin);
        rateProvider.updateBounds(9820, 10100); // New bounds: 0.982 - 1.03

        uint256 updatedRate2 = rateProvider.getRate();

        assertEq(updatedRate2, 1e18, "lastRate should update correctly with adjusted bounds");

    }

}