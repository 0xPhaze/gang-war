// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GangVault} from "../GangVault.sol";
import {GoudaChild} from "./GoudaChild.sol";
import {Gang, GangWar} from "../GangWar.sol";
import {GMCMarket, Offer} from "../GMCMarket.sol";

import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {FxERC721Child} from "fx-contracts/FxERC721Child.sol";
import {FxERC721EnumerableChild} from "fx-contracts/extensions/FxERC721EnumerableChild.sol";

import "solady/utils/ECDSA.sol";
import "solady/utils/LibString.sol";

bytes32 constant DIAMOND_STORAGE_GMC_CHILD = keccak256("diamond.storage.gmc.child.season.1");

struct GMCDS {
    uint16[4] supplies;
    mapping(uint256 => string) name;
    mapping(address => string) playerName;
    mapping(uint256 => uint256) gang;
}

function s() pure returns (GMCDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_GMC_CHILD;
    assembly { diamondStorage.slot := slot } // forgefmt: disable-line
}

error InvalidName();
error NotAuthorized();
error InvalidChoice();
error InvalidSignature();
error GangstersAlreadyMinted();

/// @title Gangsta Mice City Child
/// @author phaze (https://github.com/0xPhaze)
contract GMCChildDemo is UUPSUpgrade, OwnableUDS, FxERC721EnumerableChild, GMCMarket {
    using ECDSA for bytes32;
    using LibString for uint256;

    address public immutable vault;
    address public immutable gouda;

    string public constant name = "Gangsta Mice City";
    string public constant symbol = "GMC";

    address private constant signer = 0x68442589f40E8Fc3a9679dE62884c85C6E524888;

    constructor(address fxChild, address vault_, address gouda_) FxERC721EnumerableChild(fxChild) {
        vault = vault_;
        gouda = gouda_;
    }

    function init() external initializer {
        __Ownable_init();
    }

    /* ------------- view ------------- */

    function ownerOf(uint256 id) public view override (FxERC721Child, GMCMarket) returns (address) {
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
        uint256 storedGang = s().gang[id];

        if (storedGang == 0) {
            if (id > 0) gang = Gang((id < 10_000 ? id - 1 : id - (10_001 - 3)) % 3);
        } else {
            gang = Gang(storedGang - 1);
        }

        return gang;
    }

    function getName(uint256 id) external view returns (string memory) {
        return s().name[id];
    }

    function getPlayerName(address user) external view returns (string memory) {
        return s().playerName[user];
    }

    function tokenURI(uint256 id) public view returns (string memory uri) {}

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

    function mint(uint256 gang, bytes calldata signature) external {
        uint256 maxGangsters = getMaxGangsters(gang);

        if (!validSignature(signature)) revert InvalidSignature();
        if (erc721BalanceOf(msg.sender) >= maxGangsters) revert GangstersAlreadyMinted();

        uint16 numGangstersToMint = uint16(maxGangsters - erc721BalanceOf(msg.sender));

        _mintGangsters(msg.sender, gang, numGangstersToMint);
    }

    /* ------------- hooks ------------- */

    function _afterStartRent(address, address, uint256, uint256) internal pure override {
        revert NotAuthorized();
    }

    function _afterEndRent(address, address, uint256, uint256) internal pure override {
        revert NotAuthorized();
    }

    function _mintGangsters(address to, uint256 gang, uint16 numGangstersToMint) private {
        uint256 startId = s().supplies[0] + 1;
        uint256 gangSupply = s().supplies[gang] += numGangstersToMint;

        s().supplies[0] += numGangstersToMint;

        if (gang == 0) revert InvalidChoice();
        if (gangSupply > 3333) revert GangstersAlreadyMinted();

        for (uint256 i; i < numGangstersToMint; ++i) {
            _registerId(to, startId + i);

            s().gang[startId + i] = gang;
        }

        if (GoudaChild(gouda).balanceOf(to) == 0) GoudaChild(gouda).mint(to, 100e18);
    }

    /* ------------- owner ------------- */

    function getMaxGangsters(uint256 gang) public pure returns (uint256) {
        if (gang == 1) return 20;
        if (gang == 2) return 40;
        if (gang == 3) return 40;
        return 30;
    }

    function resyncBarons(address[] calldata tos, uint256[] calldata gangs) external onlyOwner {
        uint256 baronId = 10_000;

        for (uint256 i; i < tos.length; i++) {
            // mint baron
            if (++baronId > 10_021) revert GangstersAlreadyMinted();

            _registerId(tos[i], baronId);

            s().gang[baronId] = gangs[i];

            // // mint gangsters
            // uint256 currentBalance = erc721BalanceOf(tos[i]);

            // uint256 maxGangsters = getMaxGangsters(gangs[i]);

            // if (currentBalance < maxGangsters + 1) {
            //     uint16 numGangstersToMint = uint16(maxGangsters + 1 - currentBalance);

            //     if (numGangstersToMint != 0) _mintGangsters(tos[i], gangs[i], numGangstersToMint);
            // }
        }
    }

    function resyncId(address to, uint256 id) external onlyOwner {
        _registerId(to, id);
    }

    function resyncIds(address to, uint256[] calldata ids, uint256 gang) external onlyOwner {
        _registerIds(to, ids);

        for (uint256 i; i < ids.length; ++i) {
            s().gang[ids[i]] = gang + 1;
        }
    }

    function validSignature(bytes calldata signature) private view returns (bool) {
        bytes32 hash = keccak256(abi.encode(address(this), msg.sender));
        address recovered = hash.toEthSignedMessageHash().recover(signature);

        return recovered != address(0) && recovered == signer;
    }

    function setGang(uint256[] calldata ids, uint256[] calldata gang) external onlyOwner {
        for (uint256 i; i < ids.length; ++i) {
            s().gang[ids[i]] = gang[i] + 1;
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

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
            (char > 0x60 && char < 0x7B) //a-z
                || (char > 0x40 && char < 0x5B) //A-Z
                || (char == 0x20 && lastChar != 0x20) //space
                || (char > 0x2F && char < 0x3A) //9-0
        ) {
            lastChar = char;
        } else {
            return false;
        }
    }

    return true;
}
