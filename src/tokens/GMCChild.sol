// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GangWar} from "../GangWar.sol";

import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {FxERC721EnumerableChildTunnelUDS} from "fx-contracts/extensions/FxERC721EnumerableChildTunnelUDS.sol";

import "./lib/LibString.sol";

error Disabled();

contract GMCChild is UUPSUpgrade, OwnableUDS, FxERC721EnumerableChildTunnelUDS {
    using LibString for uint256;

    string public constant name = "Gangsta Mice City";
    string public constant symbol = "GMC";

    string private baseURI;

    address public gangWar;

    constructor(address fxChild, address gangWar_) FxERC721EnumerableChildTunnelUDS(fxChild) {
        gangWar = gangWar_;
    }

    function init() external initializer {
        __Ownable_init();
    }

    function gmc() public view returns (address) {
        return fxRootTunnel();
    }

    /* ------------- public ------------- */

    function ownerOf(uint256 id) public view returns (address) {
        return rootOwnerOf(gmc(), id);
    }

    function balanceOf(address user) public view returns (uint256) {
        return balanceOf(gmc(), user);
    }

    function getOwnedIds(address user) public view returns (uint256[] memory) {
        return getOwnedIds(gmc(), user);
    }

    function tokenURI(uint256 id) public view returns (string memory) {
        return string.concat(baseURI, id.toString());
    }

    /* ------------- owner ------------- */

    function setGangWar(address gangWar_) external onlyOwner {
        gangWar = gangWar_;
    }

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function _authorizeUpgrade() internal override onlyOwner {}

    function _authorizeTunnelController() internal override onlyOwner {}

    /* ------------- hooks ------------- */

    function _afterIdRegistered(
        address collection,
        address to,
        uint256 id
    ) internal override {
        super._afterIdRegistered(collection, to, id);
        GangWar(gangWar).enterGangWar(to, id);
    }

    function _afterIdDeregistered(
        address collection,
        address from,
        uint256 id
    ) internal override {
        super._afterIdDeregistered(collection, from, id);
        GangWar(gangWar).exitGangWar(from, id);
    }

    // TODO add resync option
}
