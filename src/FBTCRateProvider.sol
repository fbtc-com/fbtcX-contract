// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract RateProvider is AccessControl {

    // total supply of FBTC in all fbtc token contracts
    uint256 private totalSupplyFbtc;

    // total BTC in fbtc protocol
    uint256 private totalBtcInProtocol;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Event declarations with old and new values
    event TotalSupplyFbtcUpdated(uint256 indexed oldTotalSupplyFbtc, uint256 indexed newTotalSupplyFbtc);
    event TotalBtcInProtocolUpdated(uint256 indexed  oldTotalBtcInProtocol, uint256 indexed newTotalBtcInProtocol);

    constructor(address owner, address operator) {

        require(owner != address(0), "Owner address cannot be 0");
        require(operator != address(0), "Operator address cannot be 0");

        _grantRole(DEFAULT_ADMIN_ROLE,owner);
        _grantRole(OPERATOR_ROLE,operator);
    }

    // Set the total supply of all FBTC
    function setTotalSupplyFbtc(uint256 _totalSupplyFbtc) external onlyRole(OPERATOR_ROLE) {
        require(_totalSupplyFbtc > 0, "Total supply of FBTC must be greater than 0");

        uint256 oldTotalSupplyFbtc = totalSupplyFbtc;
        totalSupplyFbtc = _totalSupplyFbtc;

        emit TotalSupplyFbtcUpdated(oldTotalSupplyFbtc, totalSupplyFbtc);
    }

    // Set the total BTC amount in the protocol
    function setTotalBtcInProtocol(uint256 _totalBtcInProtocol) external onlyRole(OPERATOR_ROLE) {
        require(_totalBtcInProtocol > 0, "Total BTC in protocol must be greater than 0");

        uint256 oldTotalBtcInProtocol = totalBtcInProtocol;
        totalBtcInProtocol = _totalBtcInProtocol;

        emit TotalBtcInProtocolUpdated(oldTotalBtcInProtocol, totalBtcInProtocol);
    }


    // Get the ratio between totalSupplyFbtc and totalBtcInProtocol
    function getRate() external view returns (uint256) {
        require(totalSupplyFbtc > 0, "Total supply of FBTC is not set");
        require(totalBtcInProtocol > 0, "Total BTC in protocol is not set");

        return (totalBtcInProtocol * 1e18) / totalSupplyFbtc;
    }

    // View the current total supply of FBTC
    function getTotalSupplyFbtc() external view returns (uint256) {
        return totalSupplyFbtc;
    }

    // View the current total BTC in the protocol
    function getTotalBtcInProtocol() external view returns (uint256) {
        return totalBtcInProtocol;
    }
}