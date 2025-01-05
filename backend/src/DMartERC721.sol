// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol';

contract DMartERC721 is ERC721URIStorage {
    address internal owner;
    uint256 id;

    error NotOwner();

    constructor( string memory name_, string memory symbol_) payable ERC721(name_, symbol_) {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    function mint(address to, string memory uri) external onlyOwner returns (uint256) {
        id += 1;
        uint256 newId = id;

        _safeMint(to, newId);
        _setTokenURI(newId, uri); // Set the metadata URI
        return id;
    }

    function _baseURI() internal pure override returns (string memory) {
       return "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/";
    }

    function totalSupply() public view returns (uint256) {
        return id;
    }
}
