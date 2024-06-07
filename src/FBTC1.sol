// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IFireBridge} from "./Interfaces/IFireBridge.sol";
import {Request, UserInfo, RequestLib, Operation} from "./Common.sol";

contract FBTC1 is Initializable, ERC20Upgradeable, PausableUpgradeable, AccessControlUpgradeable {
    event MintFbtc1Request(address indexed minter, uint256 receivedAmount, uint256 fee);
    event RedeemFbtcRequest(address indexed owner, bytes32 depositTx, uint256 outputIndex, uint256 amount);
    event ConfirmRedeemFbtc(address indexed owner, uint256 amount);
    event EmergencyBurn(address indexed operator, address indexed from, uint256 amount);

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SAFETY_COMMITTEE_ROLE = keccak256("SAFETY_COMMITTEE_ROLE");

    IFireBridge public fbtcBridge;
    IERC20Upgradeable public fbtc;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _fbtcAddress,
        address _fbtcBridgeAddress,
        address admin,
        address pauser,
        address minter,
        address safetyCommittee
    ) public initializer {
        __ERC20_init("FBTC1 Token", "FBTC1");
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(SAFETY_COMMITTEE_ROLE, safetyCommittee);

        fbtcBridge = IFireBridge(_fbtcBridgeAddress);
        fbtc = IERC20Upgradeable(_fbtcAddress);
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function mintFbtc1Request(uint256 _amount)
        public
        onlyRole(MINTER_ROLE)
        whenNotPaused
        returns (uint256 realAmount)
    {
        require(_amount > 0, "Amount must be greater than zero.");
        require(fbtc.balanceOf(msg.sender) >= _amount, "Insufficient FBTC balance.");

        SafeERC20Upgradeable.safeTransferFrom(fbtc, msg.sender, address(this), _amount);
        (bytes32 _hash, Request memory _r) = IFireBridge(fbtcBridge).addBurnRequest(_amount);
        require(_hash != bytes32(uint256(0)), "Failed to create a valid burn request.");
        realAmount = _amount - _r.fee;
        _mint(msg.sender, realAmount);

        emit MintFbtc1Request(msg.sender, realAmount, _r.fee);
    }

    function redeemFbtcRequest(uint256 _amount, bytes32 _depositTxid, uint256 _outputIndex)
        public
        onlyRole(MINTER_ROLE)
        whenNotPaused
        returns (bytes32 _hash, Request memory _r)
    {
        require(_amount > 0 && _amount < totalSupply(), "Amount out of limit.");

        (_hash, _r) = IFireBridge(fbtcBridge).addMintRequest(_amount, _depositTxid, _outputIndex);
        emit RedeemFbtcRequest(msg.sender, _depositTxid, _outputIndex, _amount);
    }

    function confirmRedeemFbtc(uint256 _amount) public onlyRole(MINTER_ROLE) whenNotPaused {
        require(_amount > 0, "Amount must be greater than zero.");
        require(fbtc.balanceOf(address(this)) >= _amount, "Insufficient FBTC balance in contract.");

        _burn(msg.sender, _amount);
        SafeERC20Upgradeable.safeTransfer(fbtc, msg.sender, _amount);

        emit ConfirmRedeemFbtc(msg.sender, _amount);
    }

    function emergencyBurn(address _from, uint256 _amount) public onlyRole(SAFETY_COMMITTEE_ROLE) {
        _burn(_from, _amount);
        emit EmergencyBurn(msg.sender, _from, _amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        revert("FBTC1: transfers are disabled");
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        revert("FBTC1: transfers are disabled");
    }
}
