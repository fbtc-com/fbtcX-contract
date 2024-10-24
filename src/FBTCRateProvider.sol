// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract RateProvider is AccessControl {

    // total supply of FBTC in all fbtc token contracts
    uint256 private totalSupplyFbtc;

    // total BTC in fbtc protocol
    uint256 private totalBtcInProtocol;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    event TotalSupplyFbtcUpdated(uint256 newTotalSupplyFbtc);
    event TotalBtcInProtocolUpdated(uint256 newTotalBtcInProtocol);

    constructor(address owner, address operator) {

        _grantRole(DEFAULT_ADMIN_ROLE,owner);
        _grantRole(OPERATOR_ROLE,operator);
    }

    // Set the total supply of FBTC
    function setTotalSupplyFbtc(uint256 _totalSupplyFbtc) external onlyRole(OPERATOR_ROLE) {
        require(_totalSupplyFbtc > 0, "Total supply of FBTC must be greater than 0");
        totalSupplyFbtc = _totalSupplyFbtc;
        emit TotalSupplyFbtcUpdated(totalSupplyFbtc);
    }

    // Set the total BTC amount in the protocol
    function setTotalBtcInProtocol(uint256 _totalBtcInProtocol) external onlyRole(OPERATOR_ROLE) {
        require(_totalBtcInProtocol > 0, "Total BTC in protocol must be greater than 0");
        totalBtcInProtocol = _totalBtcInProtocol;
        emit TotalBtcInProtocolUpdated(totalBtcInProtocol);
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