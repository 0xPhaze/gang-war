// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {InitializableUDS} from "UDS/InitializableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

import {LibString} from "solmate/utils/LibString.sol";

import {FxERC721ChildUDS, FxBaseChildTunnelUDS} from "./lib/FxERC721ChildUDS.sol";

/* ------------- Storage ------------- */

struct SafeHouseDS {
    string baseURI;
}

// keccak256("diamond.storage.safe.house") == 0x1e344c262d3ee08a73daa9a70ad3ca8745f5523b210a1ed84689374d1a32de15;
bytes32 constant DIAMOND_STORAGE_SAFE_HOUSE = 0x1e344c262d3ee08a73daa9a70ad3ca8745f5523b210a1ed84689374d1a32de15;

function ds() pure returns (SafeHouseDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_SAFE_HOUSE
    }
}

/* ------------- Error ------------- */

error Disabled();

contract SafeHouse is UUPSUpgrade(1), OwnableUDS, FxERC721ChildUDS {
    constructor(address _fxChild) FxBaseChildTunnelUDS(_fxChild) {}

    function init() public initializer {
        __Ownable_init();
        __ERC721UDS_init("Safe House", "SAFE");
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return string.concat(ds().baseURI, LibString.toString(tokenId));
    }

    /* ------------- Public ------------- */

    // function delegateOwnership(address to, uint256 id) public {
    //     ERC721UDS.transferFrom(msg.sender, to, id);
    // }

    function approve(address, uint256) public pure override {
        revert Disabled();
    }

    function setApprovalForAll(address, bool) public pure override {
        revert Disabled();
    }

    function transferFrom(
        address,
        address,
        uint256
    ) public pure override {
        revert Disabled();
    }

    function safeTransferFrom(
        address,
        address,
        uint256
    ) public pure override {
        revert Disabled();
    }

    function safeTransferFrom(
        address,
        address,
        uint256,
        bytes calldata
    ) public pure override {
        revert Disabled();
    }

    function permit(
        address,
        address,
        uint256,
        uint8,
        bytes32,
        bytes32
    ) public pure override {
        revert Disabled();
    }

    /* ------------- UUPSVersioned ------------- */

    function _authorizeUpgrade() internal override onlyOwner {}

    /* ------------- Restricted ------------- */

    function setBaseURI(string calldata uri) external onlyOwner {
        ds().baseURI = uri;
    }
}
