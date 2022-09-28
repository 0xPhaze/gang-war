// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";
import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {VRFConsumerV2} from "../lib/VRFConsumerV2.sol";

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

contract SafeHouse is UUPSUpgrade, OwnableUDS, ERC721UDS, VRFConsumerV2 {
    using LibString for uint256;

    string public constant override name = "Safe House";
    string public constant override symbol = "SAFE";

    address public immutable mice;
    uint256 public immutable cost;

    constructor(
        address mice_,
        uint256 cost_,
        address coordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit
    ) VRFConsumerV2(coordinator, keyHash, subscriptionId, requestConfirmations, callbackGasLimit) {
        mice = mice_;
        cost = cost_;
    }

    function init() external initializer {
        __Ownable_init();
    }

    /* ------------- view ------------- */

    function totalSupply() public view returns (uint256) {
        return s().totalSupply;
    }

    /* ------------- external ------------- */

    function mint() external {
        ERC20UDS(mice).transferFrom(msg.sender, address(this), cost);

        uint256 id = ++s().totalSupply;

        _mint(msg.sender, id);

        s().requestQueue.push(id);

        if (!s().pendingVRFRequest) {
            s().pendingVRFRequest = true;

            requestVRF();
        }
    }

    /* ------------- overrides ------------- */

    function tokenURI(uint256 id) public view override returns (string memory) {
        uint256 districtId = s().districtId[id];

        return
            districtId == 0
              ? s().unrevealedURI
              : string.concat(s().baseURI, districtId.toString(), s().postFixURI); // prettier-ignore
    }

    function fulfillRandomWords(uint256, uint256[] calldata randomWords) internal override {
        s().pendingVRFRequest = false;

        uint256 rand = randomWords[0];

        uint256 numPending = s().requestQueue.length;

        for (uint256 i; i < numPending; ++i) {
            if (i != 0) rand = uint256(keccak256(abi.encode(rand, i)));

            uint256 id = s().requestQueue[i];

            s().districtId[id] = 1 + (rand % 21);
        }

        delete s().requestQueue;
    }

    /* ------------- owner ------------- */

    function setBaseURI(string calldata uri) external onlyOwner {
        s().baseURI = uri;
    }

    function setUnrevealedURI(string calldata uri) external onlyOwner {
        s().unrevealedURI = uri;
    }

    function setPostFixURI(string calldata postFix) external onlyOwner {
        s().postFixURI = postFix;
    }

    function _authorizeUpgrade() internal override onlyOwner {}
}
