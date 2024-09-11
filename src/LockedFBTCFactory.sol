// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.20;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {LockedFBTC} from "./LockedFBTC.sol";

interface ProtocolEvents {
    /// @notice Emitted when a protocol configuration has been updated.
    /// @param setterSelector The selector of the function that updated the configuration.
    /// @param setterSignature The signature of the function that updated the configuration.
    /// @param value The abi-encoded data passed to the function that updated the configuration. Since this event will
    /// only be emitted by setters, this data corresponds to the updated values in the protocol configuration.
    event ProtocolConfigChanged(bytes4 indexed setterSelector, string setterSignature, bytes value);

    /// @notice Event emitted when a LockedFBTC contract is deployed.
    /// @param minter The address of the account responsible for minting the lockedFBTC in the deployed contract.
    /// @param proxyAddress The address of the proxy that was created and deployed for the LockedFBTC contract.
    event LockedFBTCDeployed(address indexed minter, address indexed proxyAddress);

}

contract LockedFBTCFactory is Initializable, ProtocolEvents, PausableUpgradeable, AccessControlUpgradeable {

    /// @notice The address of the beacon contract responsible for managing upgradeable proxies.
    address public beaconAddress;

    /// @notice The address of the FBTC token contract.
    address public fbtcAddress;

    /// @notice The address of the FBTC bridge contract.
    address public fbtcBridgeAddress;

    /// @notice The address of the admin responsible for managing the LockedFBTC contract.
    address public lockedFbtcAdmin;

    /// @notice An array of addresses that have the pauser role, allowing them to pause contract functions.
    address[] public pausers;

    /// @notice The address of the minter, responsible for minting lockedFBTC.
    address public minter;

    /// @notice The address of the safety committee, responsible for emergency actions such as emergency burns.
    address public safetyCommittee;

    mapping(address => address) public lockedFbtcMinters;


    /// @dev Disables initializer function of the inherited contract.
    constructor() {
        _disableInitializers();
    }

    struct Params {
        address _factoryAdmin;
        address _beaconAddress;
        address _fbtcAddress;
        address _fbtcBridgeAddress;
        address _lockedFbtcAdmin;
        address[] _pausers;
        address _safetyCommittee;
    }

    function initialize(Params memory params) public initializer {
        require(params._factoryAdmin != address(0), "FactoryAdmin cannot be zero address");
        require(params._beaconAddress != address(0), "Beacon cannot be zero address");
        require(params._fbtcAddress != address(0), "FBTC cannot be zero address");
        require(params._fbtcBridgeAddress != address(0), "FBTC Bridge cannot be zero address");
        require(params._lockedFbtcAdmin != address(0), "Admin cannot be zero address");
        require(params._pausers.length != 0, "Pauser amount cannot be zero");
        require(params._safetyCommittee != address(0), "SafetyCommittee cannot be zero address");

        beaconAddress = params._beaconAddress;
        fbtcAddress = params._fbtcAddress;
        fbtcBridgeAddress = params._fbtcBridgeAddress;
        lockedFbtcAdmin = params._lockedFbtcAdmin;
        pausers = params._pausers;
        safetyCommittee = params._safetyCommittee;

        __Pausable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, params._factoryAdmin);
    }

    /// @notice Deploys a new instance of the LockedFBTC contract using a Beacon proxy.
    /// @dev This function deploys a proxy contract linked to the implementation contract managed by the beacon.
    /// It initializes the proxy with the given parameters, which include the minter, token name, and token symbol.
    ///
    /// @param _minter The address of the account that will be responsible for minting LockedFBTC in the deployed
    /// LockedFBTC contract.
    /// @param _name The name of the LockedFBTC token.
    /// @param _symbol The symbol of the LockedFBTC token.
    ///
    /// @return The address of the newly deployed LockedFBTC proxy contract.
    function createLockedFBTC(
        address _minter,
        string memory _name,
        string memory _symbol
    ) external whenNotPaused returns (address) {

        require(_minter != address(0), "minter cannot be zero address");
        BeaconProxy proxy = new BeaconProxy(
            beaconAddress,
            abi.encodeWithSelector(
                LockedFBTC.initialize.selector,
                fbtcAddress,
                fbtcBridgeAddress,
                lockedFbtcAdmin,
                pausers,
                _minter,
                safetyCommittee,
                _name,
                _symbol
            )
        );
        lockedFbtcMinters[_minter] = address(proxy);

        emit LockedFBTCDeployed(_minter, address(proxy));
        return address(proxy);
    }

    /// Owner methods.

    function setFbtcAddress(address _fbtcAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_fbtcAddress != address(0), "FBTC cannot be zero address");
        fbtcAddress = _fbtcAddress;

        emit ProtocolConfigChanged(this.setFbtcAddress.selector, "setFbtcAddress(address)", abi.encode(_fbtcAddress));
    }

    function setFbtcBridgeAddress(address _fbtcBridgeAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_fbtcBridgeAddress != address(0), "FBTC Bridge cannot be zero address");
        fbtcBridgeAddress = _fbtcBridgeAddress;

        emit ProtocolConfigChanged(this.setFbtcBridgeAddress.selector, "setFbtcBridgeAddress(address)", abi.encode(_fbtcBridgeAddress));
    }

    function setAdmin(address _lockedFbtcAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_lockedFbtcAdmin != address(0), "Admin cannot be zero address");
        lockedFbtcAdmin = _lockedFbtcAdmin;

        emit ProtocolConfigChanged(this.setAdmin.selector, "setAdmin(address)", abi.encode(_lockedFbtcAdmin));
    }

    function setPausers(address[] memory _pausers) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_pausers.length > 0, "Pausers array cannot be empty");
        pausers = _pausers;

        emit ProtocolConfigChanged(this.setPausers.selector, "setPausers(address)", abi.encode(_pausers));
    }

    function setMinter(address _minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_minter != address(0), "Minter cannot be zero address");
        minter = _minter;

        emit ProtocolConfigChanged(this.setMinter.selector, "setMinter(address)", abi.encode(_minter));
    }

    function setSafetyCommittee(address _safetyCommittee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_safetyCommittee != address(0), "SafetyCommittee cannot be zero address");
        safetyCommittee = _safetyCommittee;

        emit ProtocolConfigChanged(this.setSafetyCommittee.selector, "setSafetyCommittee(address)", abi.encode(_safetyCommittee));
    }

    /// @notice Pauses deployLockedFBTC function.
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses deployLockedFBTC function.
    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

}
