// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract FBTCIdentity is ERC1155, Ownable {
    using Strings for uint256;

    /// @notice Base URI for metadata
    string private baseURI;

    /// @notice Event emitted when tokens are minted
    event TokenMinted(address indexed to, uint256 indexed tokenId, uint256 amount);

    constructor(string memory _baseURI, address _initialOwner) ERC1155("") Ownable(_initialOwner) {
        baseURI = _baseURI;
    }

    ///@notice Function to get the URI for a specific token
    ///@param tokenId The ID of the token
    ///@return The URI for the token
    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }

    ///@notice Owner-only function to mint new tokens to a specific address
    function mint(address to, uint256 tokenId, uint256 amount) external onlyOwner {
        _mint(to, tokenId, amount, new bytes(0));
        emit TokenMinted(to, tokenId, amount);
    }

    ///@notice Owner-only function to mint new tokens to a specific address
    function mintBatch(address to, uint256[] calldata tokenIds, uint256[] calldata amounts) external onlyOwner {
        _mintBatch(to, tokenIds, amounts, new bytes(0));
        for (uint256 i = 0; i < tokenIds.length; i++) {
            emit TokenMinted(to, tokenIds[i], amounts[i]);
        }
    }

    ///@notice Owner-only function to set the base URI for metadata
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    ///@notice Owner-only function to get the base URI for metadata
    function getBaseURI() external view returns (string memory) {
        return baseURI;
    }
}
