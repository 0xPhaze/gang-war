// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Gang} from "../Constants.sol";
import {GangWar} from "../GangWar.sol";
import {GangVault} from "../GangVault.sol";
import {GMCMarket, Offer} from "../GMCMarket.sol";

import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {FxERC721Child} from "fx-contracts/FxERC721Child.sol";
import {FxERC721EnumerableChild} from "fx-contracts/extensions/FxERC721EnumerableChild.sol";

import "solady/utils/LibString.sol";

/// @title Gangsta Mice City Child
/// @author phaze (https://github.com/0xPhaze)
contract GMCChild is UUPSUpgrade, OwnableUDS, FxERC721EnumerableChild, GMCMarket {
    using LibString for uint256;

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    address public vault;
    string private baseURI;

    string public constant name = "Gangsta Mice City";
    string public constant symbol = "GMC";

    constructor(address fxChild) FxERC721EnumerableChild(fxChild) {}

    function init() external initializer {
        __Ownable_init();
    }

    /* ------------- public ------------- */

    function ownerOf(uint256 id) public view override(FxERC721Child, GMCMarket) returns (address) {
        return FxERC721Child.ownerOf(id);
    }

    function isAuthorized(address user, uint256 id) public view override returns (bool) {
        return ownerOf(id) == user || renterOf(id) == user;
    }

    function isAuthorizedUser(address user, uint256 id) public view returns (bool) {
        address renter = renterOf(id);

        // first check renter (active user), and only if 0, check owner
        return (renter != address(0)) ? user == renter : user == ownerOf(id);
    }

    function tokenURI(uint256 id) public view returns (string memory) {
        return string.concat(baseURI, id.toString());
    }

    function gangOf(uint256 id) public pure returns (Gang) {
        return id == 0 ? Gang.NONE : Gang((id < 10_000 ? id - 1 : id - (10_001 - 3)) % 3);
    }

    /// @dev resets and re-calculates shares
    function resyncShares() internal {
        uint256 idsLength = erc721BalanceOf(msg.sender);

        uint40[3] memory shares;

        for (uint256 i; i < idsLength; ++i) {
            uint256 id = tokenOfOwnerByIndex(msg.sender, i);

            _cleanUpOffer(msg.sender, id);

            uint256 gang = uint256(gangOf(id));
            shares[gang] += 100;
        }

        GangVault(vault).resetShares(msg.sender, shares);
    }

    /* ------------- hooks ------------- */

    /// @dev these hooks are called by Polygon's PoS bridge
    /// extra care must be taken such that these calls never fail!
    /// called when `from` != `to` (3 cases):
    /// - `from` = 0
    /// - `to` = 0
    /// - `from`, `to` != 0
    function _afterIdRegistered(
        address from,
        address to,
        uint256 id
    ) internal override {
        super._afterIdRegistered(from, to, id);

        if (from != address(0)) {
            // make sure any active rental is cleaned up
            // so that shares invariant holds.
            // calls `_afterEndRent` if rental is active.
            _cleanUpOffer(from, id);

            // @dev: this call seems like a danger point that could possibly
            // fail in rare cases. Wrapping in try...catch since bridge call should not fail.
            // Fails when resetting the gang vault and all its shares (here it's fine).
            try GangVault(vault).removeShares(from, uint256(gangOf(id)), 100) {} catch {}
        }

        if (to != address(0)) {
            GangVault(vault).addShares(to, uint256(gangOf(id)), 100);
        }

        emit Transfer(from, to, id);
    }

    function _afterStartRent(
        address owner,
        address renter,
        uint256 id,
        uint256 renterShares
    ) internal override {
        Gang gang = gangOf(id);

        GangVault(vault).transferShares(owner, renter, uint256(gang), uint8(renterShares));

        emit Transfer(owner, renter, id);
    }

    function _afterEndRent(
        address owner,
        address renter,
        uint256 id,
        uint256 renterShares
    ) internal override {
        Gang gang = gangOf(id);

        // @dev: really don't like the use of try...catch for vault resets
        try GangVault(vault).transferShares(renter, owner, uint256(gang), uint8(renterShares)) {} catch {}

        emit Transfer(renter, owner, id);
    }

    /* ------------- owner ------------- */

    function resyncId(address to, uint256 id) external onlyOwner {
        _registerId(to, id);
    }

    function resyncIds(address to, uint256[] calldata ids) external onlyOwner {
        _registerIds(to, ids);
    }

    function setGangVault(address gangVault) external onlyOwner {
        vault = gangVault;
    }

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function _authorizeUpgrade() internal override onlyOwner {}

    function _authorizeTunnelController() internal override onlyOwner {}
}
