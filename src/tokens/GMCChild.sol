// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GangVault} from "../GangVault.sol";
import {LibCrumbMap} from "../lib/LibCrumbMap.sol";
import {Gang, GangWar} from "../GangWar.sol";
import {GMCMarket, Offer} from "../GMCMarket.sol";

import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {FxERC721Child} from "fx-contracts/FxERC721Child.sol";
import {FxERC721EnumerableChild} from "fx-contracts/extensions/FxERC721EnumerableChild.sol";

import "solady/utils/ECDSA.sol";
import "solady/utils/LibString.sol";

// @note fked the naming of this one up; needs to stay "rumble" for now
bytes32 constant DIAMOND_STORAGE_GMC_CHILD = keccak256("diamond.storage.gmc.child.season.rumble");

struct GMCDS {
    string baseURI;
    string postFixURI;
    string unrevealedURI;
    mapping(uint256 => string) name;
    mapping(address => string) playerName;
    mapping(uint256 => uint256) gangMap;
}

function s() pure returns (GMCDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_GMC_CHILD;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

error GangUnset();
error InvalidName();
error NotAuthorized();
error InvalidChoice();
error InvalidSignature();
error ChunkDataAlreadySet();
error GangstersAlreadyMinted();

/// @title Gangsta Mice City Child
/// @author phaze (https://github.com/0xPhaze)
contract GMCChild is UUPSUpgrade, OwnableUDS, FxERC721EnumerableChild, GMCMarket {
    using ECDSA for bytes32;
    using LibString for uint256;
    using LibCrumbMap for mapping(uint256 => uint256);
    // using LibCrumbMap for LibCrumbMap.CrumbMap; // we want to avoid nested structs

    address public immutable vault;

    string public constant name = "Gangsta Mice City";
    string public constant symbol = "GMC";

    constructor(address fxChild, address vault_) FxERC721EnumerableChild(fxChild) {
        vault = vault_;
    }

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

    function gangOf(uint256 id) public view returns (Gang gang) {
        if (id > 10_000) return Gang((id - 2) % 3);

        uint256 gangEnc = s().gangMap.get(id - 1);

        // enum Gang has convention of Gang.NONE (= 4) being invalid
        // more natural in a mapping to assume 0 (unset) is invalid
        // that's why we're making converting 0 <=> 4 (Gang.None)
        if (gangEnc == 0) gang = Gang.NONE;
        else gang = Gang(gangEnc - 1);
    }

    function gangBalancesOf(address user) public view returns (uint256[3] memory balances) {
        uint256 numOwned = erc721BalanceOf(user);

        for (uint256 i; i < numOwned; ++i) {
            uint256 id = tokenOfOwnerByIndex(user, i);

            balances[uint8(gangOf(id))] += 1;
        }
    }

    function getName(uint256 id) external view returns (string memory) {
        return s().name[id];
    }

    function getPlayerName(address user) external view returns (string memory) {
        return s().playerName[user];
    }

    function tokenURI(uint256 id) public view returns (string memory) {
        return 
            bytes(s().baseURI).length == 0 
            ? s().unrevealedURI 
            : string.concat(s().baseURI, id.toString(), s().postFixURI); // prettier-ignore
    }

    /* ------------- external ------------- */

    function setName(uint256 id, string calldata name_) external {
        if (!isValidString(name_, 20)) revert InvalidName();
        if (ownerOf(id) != msg.sender) revert NotAuthorized();

        s().name[id] = name_;
    }

    function setPlayerName(string calldata name_) external {
        if (!isValidString(name_, 20)) revert InvalidName();

        s().playerName[msg.sender] = name_;
    }

    /* ------------- hooks ------------- */

    /// @dev these hooks are called by Polygon's PoS bridge
    /// extra care must be taken such that these calls never fail!
    /// Only called when `from != to` (3 cases):
    /// - `from` = 0
    /// - `to` = 0
    /// - `from`, `to` != 0
    function _afterIdRegistered(
        address from,
        address to,
        uint256 id
    ) internal override {
        super._afterIdRegistered(from, to, id);

        Gang gang = gangOf(id);

        // allow users to transfer the token, but
        // without adding any shares. These will be
        // added as soon as the gangs are known.
        if (gang != Gang.NONE) {
            if (from != address(0)) {
                // make sure any active rental is cleaned up
                // so that shares invariant holds.
                // calls `_afterEndRent` if rental is active.
                _cleanUpOffer(from, id);

                // @dev: this call seems like a danger point that could possibly
                // fail during fxPortal call. Fails when gangVault storage is reset.
                // try GangVault(vault).removeShares(from, uint256(gang), 100) {} catch {}
                GangVault(vault).removeShares(from, uint256(gang), 100);
            }

            if (to != address(0)) {
                GangVault(vault).addShares(to, uint256(gangOf(id)), 100);
            }
        }
    }

    function _afterStartRent(
        address owner,
        address renter,
        uint256 id,
        uint256 renterShares
    ) internal override {
        Gang gang = gangOf(id);

        if (gang == Gang.NONE) revert GangUnset();

        GangVault(vault).transferShares(owner, renter, uint256(gang), uint8(renterShares));

        // Mock a transfer
        emit Transfer(owner, renter, id);
    }

    function _afterEndRent(
        address owner,
        address renter,
        uint256 id,
        uint256 renterShares
    ) internal override {
        Gang gang = gangOf(id);

        if (gang == Gang.NONE) revert GangUnset();

        GangVault(vault).transferShares(renter, owner, uint256(gang), uint8(renterShares));

        emit Transfer(renter, owner, id);
    }

    /// @dev resets and re-calculates shares
    function _resyncShares() internal {
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

    function resyncBarons(address[] calldata tos, uint256[] calldata gangs) external onlyOwner {
        uint256 baronId = 10_000;

        for (uint256 i; i < tos.length; i++) {
            // mint baron
            if (++baronId > 10_021) revert GangstersAlreadyMinted();

            _registerId(tos[i], baronId);

            // s().gang[baronId] = gangs[i];
            s().gangMap.set(baronId, gangs[i] + 1);
        }
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        s().baseURI = uri;
    }

    function setPostFixURI(string calldata postFix) external onlyOwner {
        s().postFixURI = postFix;
    }

    function setUnrevealedURI(string calldata uri) external onlyOwner {
        s().unrevealedURI = uri;
    }

    function resyncId(address to, uint256 id) external onlyOwner {
        _registerId(to, id);
    }

    // function resyncIds(
    //     address to,
    //     uint256[] calldata ids,
    //     uint256 gang
    // ) external onlyOwner {
    //     _registerIds(to, ids);

    //     for (uint256 i; i < ids.length; ++i) s().gang[ids[i]] = gang + 1;
    // }

    function setGangsInChunks(uint256 chunkIndex, uint256 chunkData) external onlyOwner {
        if (chunkData == 0) return;
        if (s().gangMap.get32BytesChunk(chunkIndex) != 0) revert ChunkDataAlreadySet();

        s().gangMap.set32BytesChunk(chunkIndex, chunkData);

        uint256 id;
        uint256 gang;
        address owner;

        unchecked {
            for (uint256 i; i < 128; i++) {
                // ids start at 1
                id = (chunkIndex << 7) + i + 1; // << 7 == * 128
                gang = (chunkData >> (i << 1)) & 3;

                owner = ownerOf(id);
                if (gang != 0 && owner != address(0)) {
                    // storing gangs in crumbMap uses convention 0 = invalid, 1 = Yakuza, ....
                    // gangwar uses convention 0 = Yakuza, .... 4 = invalid
                    GangVault(vault).addShares(owner, gang - 1, 100);
                }
            }
        }
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
            (char == 0x20 && lastChar != 0x20) || //space
            (char > 0x2F && char < 0x3A) //9-0
        ) {
            lastChar = char;
        } else {
            return false;
        }
    }

    return true;
}
