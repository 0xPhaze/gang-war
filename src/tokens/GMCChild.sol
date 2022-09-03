// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Gang} from "../Constants.sol";
import {GangWar} from "../GangWar.sol";
import {GangVault} from "../GangVault.sol";
import {GMCMarket, Offer} from "../GMCMarket.sol";

import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {FxERC721ChildTunnelUDS} from "fx-contracts/FxERC721ChildTunnelUDS.sol";
import {FxERC721EnumerableChildTunnelUDS} from "fx-contracts/extensions/FxERC721EnumerableChildTunnelUDS.sol";

import "./lib/LibString.sol";

import "forge-std/console.sol";

contract GMCChild is UUPSUpgrade, OwnableUDS, FxERC721EnumerableChildTunnelUDS, GMCMarket {
    using LibString for uint256;

    string public constant name = "Gangsta Mice City";
    string public constant symbol = "GMC";

    address public vault;
    string private baseURI;

    constructor(address fxChild) FxERC721EnumerableChildTunnelUDS(fxChild) {}

    function init() external initializer {
        __Ownable_init();
    }

    /* ------------- public ------------- */

    function ownerOf(uint256 id) public view override(FxERC721ChildTunnelUDS, GMCMarket) returns (address) {
        return FxERC721ChildTunnelUDS.ownerOf(id);
    }

    function isAuthorized(address user, uint256 id) public view override returns (bool) {
        return ownerOf(id) == user || renterOf(id) == user;
    }

    function tokenURI(uint256 id) public view returns (string memory) {
        return string.concat(baseURI, id.toString());
    }

    function gangOf(uint256 id) public pure returns (Gang) {
        return id == 0 ? Gang.NONE : Gang((id < 10000 ? id - 1 : id - (10001 - 3)) % 3);
    }

    // function resyncShares() public {
    //     uint256 idsLength = balanceOf(msg.sender);

    //     uint40[3] memory shares;
    //     for (uint256 i; i < idsLength; ++i) {
    //         uint256 id = tokenOfOwnerByIndex(msg.sender, i);

    //         _endRentAndDeleteOffer(id);

    //         uint256 gang = uint256(gangOf(id));
    //         shares[gang] += 100;
    //     }

    //     GangVault(vault).resetShares(msg.sender, shares);
    // }

    /* ------------- hooks ------------- */

    /// @dev these hooks are called by Polygon's PoS bridge
    /// extra care must be taken such that these calls never fail!
    function _afterIdRegistered(address to, uint256 id) internal override {
        super._afterIdRegistered(to, id);

        // GangVault(vault).addShares(to, uint256(gangOf(id)), 100);
        try GangVault(vault).addShares(to, uint256(gangOf(id)), 100) {} catch {}
    }

    function _afterIdDeregistered(address from, uint256 id) internal override {
        super._afterIdDeregistered(from, id);

        // make sure any active rental is cleaned up
        // so that shares invariant holds.
        // calls `_afterEndRent` if rental is active.
        _endRentAndDeleteOffer(id);

        // GangVault(vault).removeShares(from, uint256(gangOf(id)), 100);
        try GangVault(vault).removeShares(from, uint256(gangOf(id)), 100) {} catch {}
    }

    function _afterStartRent(
        address owner,
        address renter,
        uint256 id,
        uint256 renterShares
    ) internal override {
        Gang gang = gangOf(id);

        GangVault(vault).addShares(renter, uint256(gang), uint8(renterShares));
        GangVault(vault).removeShares(owner, uint256(gang), uint8(renterShares));
    }

    function _afterEndRent(
        address owner,
        address renter,
        uint256 id,
        uint256 renterShares
    ) internal override {
        Gang gang = gangOf(id);

        GangVault(vault).addShares(owner, uint256(gang), uint8(renterShares));
        GangVault(vault).removeShares(renter, uint256(gang), uint8(renterShares));
    }

    /* ------------- owner ------------- */

    function setGangVault(address gangVault) external onlyOwner {
        vault = gangVault;
    }

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function _authorizeUpgrade() internal override onlyOwner {}

    function _authorizeTunnelController() internal override onlyOwner {}
}
