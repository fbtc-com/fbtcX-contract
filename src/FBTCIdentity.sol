// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
contract FBTCBadge is ERC1155, AccessControl {
    using Strings for uint256;
    string public name = "FBTCBadge";
    string public symbol = "FBTCBADGE";

    /// @notice Base URI for metadata
    string private baseURI;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Event emitted when tokens are minted
    event TokenMinted(address indexed to, uint256 indexed tokenId, uint256 amount);

    constructor(string memory _baseURI, address _owner) ERC1155("") {
        baseURI = _baseURI;
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(MINTER_ROLE, _owner);
    }
    
    /// @notice Override supportsInterface to resolve conflict between ERC1155 and AccessControl
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    ///@notice Function to get the URI for a specific token
    ///@param tokenId The ID of the token
    ///@return The URI for the token
    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }

    ///@notice Owner-only function to mint new tokens to a specific address
    function mint(address to, uint256 tokenId, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, tokenId, amount, new bytes(0));
        emit TokenMinted(to, tokenId, amount);
    }

    ///@notice Owner-only function to mint new tokens to a specific address
    function mintBatch(address to, uint256[] calldata tokenIds, uint256[] calldata amounts) external onlyRole(MINTER_ROLE) {
        _mintBatch(to, tokenIds, amounts, new bytes(0));
        for (uint256 i = 0; i < tokenIds.length; i++) {
            emit TokenMinted(to, tokenIds[i], amounts[i]);
        }
    }

    ///@notice Owner-only function to mint new tokens to multiple addresses
    function mintToMultiAddr(address[] calldata to, uint256[] calldata tokenIds, uint256[] calldata amounts) external onlyRole(MINTER_ROLE) {
        require(to.length == tokenIds.length && to.length == amounts.length, "Invalid input");
        for (uint256 i = 0; i < to.length; i++) {
            _mint(to[i], tokenIds[i], amounts[i], new bytes(0));
            emit TokenMinted(to[i], tokenIds[i], amounts[i]);
        }
    }

    ///@notice Owner-only function to set the base URI for metadata
    function setBaseURI(string memory _baseURI) external onlyRole(MINTER_ROLE) {
        baseURI = _baseURI;
    }

    ///@notice Get the base URI for metadata
    function getBaseURI() external view returns (string memory) {
        return baseURI;
    }
}
