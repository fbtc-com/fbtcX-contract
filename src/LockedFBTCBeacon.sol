// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LockedFBTCBeacon is UpgradeableBeacon {
    
    constructor(address implementation, address owner) UpgradeableBeacon(implementation) {
        transferOwnership(owner);
    }

    /// @notice Allows the owner to upgrade the implementation of the beacon.
    /// @param newImplementation The address of the new implementation contract.
    function upgradeImplementation(address newImplementation) external onlyOwner {
        upgradeTo(newImplementation);
    }
}
