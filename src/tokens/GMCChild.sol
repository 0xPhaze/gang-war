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

bytes32 constant DIAMOND_STORAGE_GMC_CHILD = keccak256("diamond.storage.gmc.child");

struct GMCDS {
    mapping(uint256 => string) name;
    mapping(uint256 => uint256) gang;
}

function s() pure returns (GMCDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_GMC_CHILD;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

error InvalidName();
error NotAuthorized();

/// @title Gangsta Mice City Child
/// @author phaze (https://github.com/0xPhaze)
contract GMCChild is UUPSUpgrade, OwnableUDS, FxERC721EnumerableChild, GMCMarket {
    using LibString for uint256;

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    address public vault; // could make immutable
    string private baseURI;

    string public constant name = "Gangsta Mice City";
    string public constant symbol = "GMC";

    constructor(address fxChild) FxERC721EnumerableChild(fxChild) {}

    function init() external initializer {
        __Ownable_init();
    }

    /* ------------- view ------------- */

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

    function gangOf(uint256 id) public view returns (Gang gang) {
        uint256 storedGang = s().gang[id];

        if (storedGang == 0) {
            if (id > 0) gang = Gang((id < 10_000 ? id - 1 : id - (10_001 - 3)) % 3);
        } else gang = Gang(storedGang - 1);

        return gang;
    }

    function getName(uint256 id) external view returns (string memory) {
        return s().name[id];
    }

    /* ------------- external ------------- */

    function setName(uint256 id, string calldata name_) external {
        if (!isValidString(name_, 20)) revert InvalidName();
        if (ownerOf(id) != msg.sender) revert NotAuthorized();

        s().name[id] = name_;
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
            // fail during fxPortal call. Fails when gangVault storage is reset.
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

        GangVault(vault).transferShares(renter, owner, uint256(gang), uint8(renterShares));

        emit Transfer(renter, owner, id);
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

    /* ------------- owner ------------- */

    function resyncId(address to, uint256 id) external onlyOwner {
        _registerId(to, id);
    }

    function resyncIds(address to, uint256[] calldata ids) external onlyOwner {
        _registerIds(to, ids);
    }

    function setGang(uint256[] calldata ids, uint256[] calldata gang) external onlyOwner {
        for (uint256 i; i < ids.length; ++i) s().gang[ids[i]] = gang[i] + 1;
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

function isValidString(string calldata str, uint256 maxLen) pure returns (bool) {
    bytes memory b = bytes(str);
    if (b.length < 1 || b.length > maxLen || b[0] == 0x20 || b[b.length - 1] == 0x20) return false;

    bytes1 lastChar = b[0];

    bytes1 char;
    for (uint256 i; i < b.length; ++i) {
        char = b[i];

        if (
            (char > 0x60 && char < 0x7B) || //a-z
            (char > 0x40 && char < 0x5B) || //A-Z
            (char == 0x20) || //space
            (char > 0x2F && char < 0x3A) //9-0
        ) {
            lastChar = char;
        } else {
            return false;
        }
    }

    return true;
}
