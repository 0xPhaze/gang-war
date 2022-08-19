// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {ERC1155UDS} from "UDS/tokens/ERC1155UDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {AccessControlUDS} from "UDS/auth/AccessControlUDS.sol";

import "./lib/LibString.sol";

contract GangWarItems is UUPSUpgrade, OwnableUDS, ERC1155UDS, AccessControlUDS {
    using LibString for uint256;

    bytes32 constant MINT_AUTHORITY = keccak256("MINT_AUTHORITY");
    bytes32 constant BURN_AUTHORITY = keccak256("BURN_AUTHORITY");

    string private baseURI;

    function init(string calldata baseURI_, uint256 numItems) public virtual initializer {
        __Ownable_init();
        __AccessControl_init();
        setBaseURI(baseURI_, numItems);
    }

    function uri(uint256 id) public view override returns (string memory) {
        return string.concat(baseURI, id.toString());
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155UDS, AccessControlUDS) returns (bool) {
        return ERC1155UDS.supportsInterface(interfaceId) || AccessControlUDS.supportsInterface(interfaceId);
    }

    /* ------------- external ------------- */

    function mint(
        address user,
        uint256 id,
        uint256 amount
    ) external onlyRole(MINT_AUTHORITY) {
        _mint(user, id, amount, "");
    }

    function burn(
        address user,
        uint256 id,
        uint256 amount
    ) external onlyRole(BURN_AUTHORITY) {
        _burn(user, id, amount);
    }

    /* ------------- authority ------------- */

    function setBaseURI(string calldata base, uint256 maxId) public onlyOwner {
        baseURI = base;
        for (uint256 i; i < maxId; i++) {
            emit URI(uri(i), i);
        }
    }

    function grantMintAuthority(address operator) external {
        grantRole(MINT_AUTHORITY, operator);
    }

    function grantBurnAuthority(address operator) external {
        grantRole(BURN_AUTHORITY, operator);
    }

    /* ------------- owner ------------- */

    function _authorizeUpgrade() internal override onlyOwner {}
}
