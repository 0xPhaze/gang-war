// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
// import "../ERC721UDS.sol";

// // ------------- storage

// bytes32 constant DIAMOND_STORAGE_ERC721 = keccak256("diamond.storage.erc721");

// function s() pure returns (ERC721DS storage diamondStorage) {
//     bytes32 slot = DIAMOND_STORAGE_ERC721;
//     assembly { diamondStorage.slot := slot } // prettier-ignore
// }

// import {FxERC721Child} from "../FxERC721Child.sol";
import {LibEnumerableSet, Uint256Set} from "UDS/lib/LibEnumerableSet.sol";

// ------------- storage

bytes32 constant DIAMOND_STORAGE_ERC721_ENUMERABLE = keccak256("diamond.storage.erc721.enumerable");

function s() pure returns (ERC721EnumerableDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_ERC721_ENUMERABLE;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

struct ERC721EnumerableDS {
    mapping(address => Uint256Set) ownedIds;
}

abstract contract ERC721Enumerable is ERC721UDS {
    using LibEnumerableSet for Uint256Set;

    /* ------------- virtual ------------- */

    function tokenURI(uint256 id) public view virtual override returns (string memory);

    /* ------------- public ------------- */

    function tokenOfOwnerByIndex(address user, uint256 index) public view virtual returns (uint256) {
        return s().ownedIds[user].at(index);
    }

    function getOwnedIds(address user) public view virtual returns (uint256[] memory) {
        return s().ownedIds[user].values();
    }

    function userOwnsId(address user, uint256 id) public view virtual returns (bool) {
        return s().ownedIds[user].includes(id);
    }

    /* ------------- override ------------- */

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual override {
        ERC721UDS.transferFrom(from, to, id);

        s().ownedIds[from].remove(id);
        s().ownedIds[to].add(id);
    }

    function _mint(address to, uint256 id) internal virtual override {
        ERC721UDS._mint(to, id);

        s().ownedIds[to].add(id);
    }

    function _burn(uint256 id) internal virtual override {
        address owner = ownerOf(id);

        ERC721UDS._burn(id);

        s().ownedIds[owner].remove(id);
    }
}
