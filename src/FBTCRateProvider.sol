// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract RateProvider is AccessControl {

    // total supply of FBTC in all fbtc token contracts
    uint256 private totalSupplyFbtc;

    // total BTC in fbtc protocol
    uint256 private totalBtcInProtocol;

    // Stores the last computed rate between totalBtcInProtocol and totalSupplyFbtc.
    // Used to maintain stability in the rate by providing a fallback value if the computed rate
    // falls outside the defined bounds.
    uint256 private lastRate;

    // lower bounds
    uint256 private lowerBound;

    // upper bounds
    uint256 private upperBound;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Event declarations with old and new values
    event TotalSupplyFbtcUpdated(uint256 indexed oldTotalSupplyFbtc, uint256 indexed newTotalSupplyFbtc);
    event TotalBtcInProtocolUpdated(uint256 indexed  oldTotalBtcInProtocol, uint256 indexed newTotalBtcInProtocol);

    constructor(address owner, address operator) {

        require(owner != address(0), "Owner address cannot be 0");
        require(operator != address(0), "Operator address cannot be 0");

        _grantRole(DEFAULT_ADMIN_ROLE,owner);
        _grantRole(OPERATOR_ROLE,operator);

        lowerBound = 9950; // 0.9950
        upperBound = 10050; // 1.0050
    }

    // Set the total supply of all FBTC
    function setTotalSupplyFbtc(uint256 _totalSupplyFbtc) external onlyRole(OPERATOR_ROLE) {
        require(_totalSupplyFbtc > 0, "Total supply of FBTC must be greater than 0");

        uint256 oldTotalSupplyFbtc = totalSupplyFbtc;
        totalSupplyFbtc = _totalSupplyFbtc;

        emit TotalSupplyFbtcUpdated(oldTotalSupplyFbtc, totalSupplyFbtc);

        _updateRate();
    }

    // Set the total BTC amount in the protocol
    function setTotalBtcInProtocol(uint256 _totalBtcInProtocol) external onlyRole(OPERATOR_ROLE) {
        require(_totalBtcInProtocol > 0, "Total BTC in protocol must be greater than 0");

        uint256 oldTotalBtcInProtocol = totalBtcInProtocol;
        totalBtcInProtocol = _totalBtcInProtocol;

        emit TotalBtcInProtocolUpdated(oldTotalBtcInProtocol, totalBtcInProtocol);

        _updateRate();
    }

    /// @notice Update the lower and upper bounds
    /// @param _lowerBound The new lower bound as a percentage (based on 10000)
    /// @param _upperBound The new upper bound as a percentage (based on 10000)
    function updateBounds(uint256 _lowerBound, uint256 _upperBound) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_lowerBound < 10000 && _upperBound > 10000, "Bounds must straddle 10000 (1.0)");
        require(_lowerBound > 0 && _upperBound < 20000, "Bounds must be realistic");
        lowerBound = _lowerBound;
        upperBound = _upperBound;
    }

    /// @notice Get the ratio between totalSupplyFbtc and totalBtcInProtocol
    function getRate() external view returns (uint256) {
        require(totalSupplyFbtc > 0, "Total supply of FBTC is not set");
        require(totalBtcInProtocol > 0, "Total BTC in protocol is not set");

        uint256 rate = (totalBtcInProtocol * 1e18) / totalSupplyFbtc;

        uint256 lowerLimit = (lowerBound * 1e18) / 10000;
        uint256 upperLimit = (upperBound * 1e18) / 10000;

        if (lastRate != 0 && (rate < lowerLimit || rate > upperLimit)) {
            return lastRate;
        }

        return rate;
    }

    // View the current total supply of FBTC
    function getTotalSupplyFbtc() external view returns (uint256) {
        return totalSupplyFbtc;
    }

    // View the current total BTC in the protocol
    function getTotalBtcInProtocol() external view returns (uint256) {
        return totalBtcInProtocol;
    }

    // Internal function to update the rate
    function _updateRate() internal {

        if (totalSupplyFbtc == 0 || totalBtcInProtocol == 0) {
            lastRate = 1e18;
            return;
        }

        uint256 rate = (totalBtcInProtocol * 1e18) / totalSupplyFbtc;

        uint256 lowerLimit = (lowerBound * 1e18) / 10000;
        uint256 upperLimit = (upperBound * 1e18) / 10000;

        if (lastRate == 0 || (rate >= lowerLimit && rate <= upperLimit)) {
            lastRate = rate;
        }
    }
}