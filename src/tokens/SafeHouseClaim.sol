// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {FxBaseRootTunnel} from "fx-contracts/base/FxBaseRootTunnel.sol";

bytes4 constant CONSECUTIVE_MINT_ERC721_SELECTOR = bytes4(keccak256("conescutiveMint(address)"));

import "solady/utils/LibString.sol";

// ------------- storage

struct SafeHouseDS {
    bool pendingVRFRequest;
    uint256 totalSupply;
    uint256[] requestQueue;
    mapping(uint256 => uint256) districtId;
    string baseURI;
    string postFixURI;
    string unrevealedURI;
}

bytes32 constant DIAMOND_STORAGE_SAFE_HOUSE = keccak256("diamond.storage.safe.house");

function s() pure returns (SafeHouseDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_SAFE_HOUSE;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

// ------------- error

error InvalidBurnAmount();

contract SafeHouseClaim is UUPSUpgrade, OwnableUDS, FxBaseRootTunnel {
    string public constant name = "Safe Houses Claim";
    string public constant symbol = "SAFE";

    address public immutable troupe;
    address public constant burnAddress = 0x000000000000000000000000000000000000dEaD;

    uint256 public constant burnRequirement = 5;

    constructor(
        address troupe_,
        address checkpointManager,
        address fxRoot
    ) FxBaseRootTunnel(checkpointManager, fxRoot) {
        troupe = troupe_;
    }

    /* ------------- internal ------------- */

    function init() external initializer {
        __Ownable_init();
    }

    /* ------------- external ------------- */

    function claim(uint256[][] calldata ids) external {
        for (uint256 c; c < ids.length; c++) {
            if (ids[c].length != burnRequirement) revert InvalidBurnAmount();

            for (uint256 i; i < ids[c].length; ++i) {
                ERC721UDS(troupe).transferFrom(msg.sender, burnAddress, ids[c][i]);
            }

            _sendMessageToChild(abi.encodeWithSelector(CONSECUTIVE_MINT_ERC721_SELECTOR, msg.sender));
        }
    }

    /* ------------- overrides ------------- */

    function _authorizeUpgrade() internal override onlyOwner {}

    function _authorizeTunnelController() internal override onlyOwner {}
}
