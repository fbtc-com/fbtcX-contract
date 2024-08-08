// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeploymentParams} from "../script/helpers/Proxy.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {Request, Operation, Status} from "../src/Common.sol";

contract BaseTest is Test {
    address public immutable upgrader = makeAddr("upgrader");

    address public immutable admin = makeAddr("admin");
    address public immutable pauser = makeAddr("pauser");
    address public immutable minter = makeAddr("minter");
    address public immutable safetyCommittee = makeAddr("safetyCommittee");

    address public immutable user = makeAddr("user");

    TimelockController public immutable proxyAdmin;

    constructor() {
        address[] memory operators = new address[](1);
        operators[0] = address(this);
        proxyAdmin =
            new TimelockController({minDelay: 0, proposers: operators, executors: operators, admin: admin});

        vm.warp(2);
    }

    function deploymentParams() internal view returns (DeploymentParams memory) {
        // BTCBridge setup
        return DeploymentParams({
            fbtcAddress: vm.envAddress("FBTC_ADDRESS"),
            fireBrdigeAddress: vm.envAddress("FIRE_BRIDGE_ADDRESS"),
            admin: vm.envAddress("SUPER_ADMIN"),
            proposer: vm.envAddress("PROPOSER_ADDRESS"),
            pauser1: vm.envAddress("PAUSER_ROLE_ADDRESS"),
            pauser2: vm.envAddress("PAUSER_ROLE_ADDRESS"),
            pauser3: vm.envAddress("PAUSER_ROLE_ADDRESS"),
            minter: vm.envAddress("MINTER_ROLE_ADDRESS"),
            safetyCommittee: vm.envAddress("SAFETY_COMMITTEE"),
            name: vm.envAddress("TOKEN_NAME"),
            symbol: vm.envAddress("TOKEN_SYMBOL")
        });
    }

    function missingRoleError(address account, bytes32 role) public pure returns (bytes memory) {
        return bytes(
            string.concat(
                "AccessControl: account ", Strings.toHexString(account), " is missing role ", vm.toString(role)
            )
        );
    }

    function assumeMissingRolePrankAndExpectRevert(address vandal, address target, bytes32 role) public {
        vm.assume(vandal != address(proxyAdmin));
        vm.assume(!IAccessControl(target).hasRole(role, vandal));
        vm.expectRevert(missingRoleError(vandal, role));
        vm.prank(vandal);
    }
}

// Mock FBTC0 token
contract Fbtc0Mock is ERC20 {
    constructor() ERC20("FakeBTC0", "BTC") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}

// Mock FireBridge contract
contract MockFireBridge is Ownable {
    Fbtc0Mock public fbtc0Mock;
    uint128 public nonceCounter;
    mapping(bytes32 => Request) public requests;

    constructor(address _fbtc0Mock) {
        fbtc0Mock = Fbtc0Mock(_fbtc0Mock);
    }

    function _generateHash() private view returns (bytes32) {
        return keccak256(abi.encodePacked(msg.sender));
    }

    function getRequest(bytes32 _hash) public view returns (Request memory) {
        require(requests[_hash].nonce != 0, "Request does not exist.");
        return requests[_hash];
    }

    function addMintRequest(uint256 _amount, bytes32 _depositTxid, uint256 _outputIndex)
        external
        returns (bytes32 _hash, Request memory _r)
    {
        _hash = _generateHash();
        nonceCounter++;

        _r = Request({
            op: Operation.Mint,
            status: Status.Pending,
            nonce: nonceCounter,
            srcChain: bytes32("sourceChain"),
            srcAddress: abi.encode(msg.sender),
            dstChain: bytes32("destinationChain"),
            dstAddress: abi.encode(msg.sender),
            amount: _amount,
            fee: 0,
            extra: abi.encode(_depositTxid, _outputIndex)
        });

        requests[_hash] = _r;
    }

    function addBurnRequest(uint256 _amount) external returns (bytes32 _hash, Request memory _r) {
        _hash = _generateHash();
        nonceCounter++;

        _r = Request({
            op: Operation.Burn,
            status: Status.Pending,
            nonce: nonceCounter,
            srcChain: bytes32("sourceChain"),
            srcAddress: abi.encode(msg.sender),
            dstChain: bytes32("destinationChain"),
            dstAddress: abi.encode(msg.sender),
            amount: _amount,
            fee: 10000,
            extra: ""
        });

        requests[_hash] = _r;

        // Burn the Fbtc0Mock tokens
        fbtc0Mock.burn(msg.sender, _amount);
    }

    function confirmMintRequest(bytes32 _hash) external {
        Request storage _r = requests[_hash];
        require(_r.status == Status.Pending, "Request not pending");

        fbtc0Mock.mint(abi.decode(_r.dstAddress, (address)), _r.amount);

        _r.status = Status.Confirmed;
    }
}
