// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";
import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {VRFConsumerV2} from "../lib/VRFConsumerV2.sol";
import {FxBaseChildTunnel} from "fx-contracts/base/FxBaseChildTunnel.sol";
import {MINT_ERC721_SELECTOR} from "./SafeHouseClaim.sol";

import "solady/utils/LibString.sol";

// ------------- storage

struct SafeHouseData {
    uint8 level;
    uint8 districtId;
}
struct SafeHouseDS {
    bool pendingVRFRequest;
    uint16 totalSupply;
    uint16 totalSupplyBarracks;
    uint16 totalSupplyHeadquarters;
    uint256[] requestQueue;
    mapping(uint256 => SafeHouseData) safeHouseData;
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

error ExceedsLimit();
error InvalidQuantity();
error InvalidSelector();

contract SafeHouses is UUPSUpgrade, OwnableUDS, ERC721UDS, VRFConsumerV2, FxBaseChildTunnel {
    using LibString for uint256;

    string public constant override name = "Safe Houses";
    string public constant override symbol = "SAFE";

    uint256 public constant MINT_MICE_COST = 100_000e18;
    uint256 public constant LEVEL_2_MICE_COST = 150_000e18;
    uint256 public constant LEVEL_3_MICE_COST = 300_000e18;

    uint256 public constant MINT_BADGES_COST = 200;
    uint256 public constant LEVEL_2_BADGES_COST = 250;
    uint256 public constant LEVEL_3_BADGES_COST = 300;

    uint256 public constant MAX_SUPPLY = 3333;
    uint256 public constant MAX_SUPPLY_BARRACKS = 2000;
    uint256 public constant MAX_SUPPLY_HEADQUARTERS = 667;

    address public immutable mice;
    address public immutable badges;

    // Level 1 - Safe House
    // 100,000 MICE and 200 Badges
    // 2 GOUDA & 300 Gang Tokens
    // Level 2 - Barracks
    // 150,000 MICE and 250 Badges
    // 4 GOUDA & 450 Gang Tokens
    // Level 3 - Headquarters
    // 225,000 MICE and 300 Badges
    // 7 Gouda & 600 Gang Tokens

    constructor(
        address mice_,
        address badges_,
        address fxChild,
        address coordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit
    )
        FxBaseChildTunnel(fxChild)
        VRFConsumerV2(coordinator, keyHash, subscriptionId, requestConfirmations, callbackGasLimit)
    {
        mice = mice_;
        badges = badges_;
    }

    function init() external initializer {
        __Ownable_init();
    }

    /* ------------- view ------------- */

    function totalSupply() public view returns (uint256) {
        return s().totalSupply;
    }

    function totalSupplyBarracks() public view returns (uint256) {
        return s().totalSupplyBarracks;
    }

    function totalSupplyHeadquarters() public view returns (uint256) {
        return s().totalSupplyHeadquarters;
    }

    function getSafeHouseData(uint256 id) public view returns (SafeHouseData memory) {
        return s().safeHouseData[id];
    }

    function getLevel(uint256 id) public view returns (uint256) {
        return s().safeHouseData[id].level;
    }

    function getDistrictId(uint256 id) public view returns (uint256) {
        return s().safeHouseData[id].districtId;
    }

    /* ------------- external ------------- */

    function mint(uint256 quantity) external {
        uint256 totalMiceCost = quantity * MINT_MICE_COST;
        uint256 totalBadgesCost = quantity * MINT_BADGES_COST;

        ERC20UDS(mice).transferFrom(msg.sender, address(this), totalMiceCost);
        ERC20UDS(badges).transferFrom(msg.sender, address(this), totalBadgesCost);

        _mintInternal(msg.sender, quantity);
    }

    function levelUp(uint256[] calldata ids) external {
        uint256 totalMiceCost;
        uint256 totalBadgesCost;

        for (uint256 i; i < ids.length; ++i) {
            uint8 level = ++s().safeHouseData[ids[i]].level;

            if (level == 2) {
                uint256 supplyBarracks = ++s().totalSupplyBarracks;

                if (supplyBarracks > MAX_SUPPLY_BARRACKS) revert ExceedsLimit();

                totalMiceCost += LEVEL_2_MICE_COST;
                totalBadgesCost += LEVEL_2_BADGES_COST;
            } else if (level == 3) {
                uint256 supplyHeadquarters = ++s().totalSupplyHeadquarters;

                if (supplyHeadquarters > MAX_SUPPLY_HEADQUARTERS) revert ExceedsLimit();

                totalMiceCost += LEVEL_3_MICE_COST;
                totalBadgesCost += LEVEL_3_BADGES_COST;
            } else {
                revert ExceedsLimit();
            }
        }

        ERC20UDS(mice).transferFrom(msg.sender, address(this), totalMiceCost);
        ERC20UDS(badges).transferFrom(msg.sender, address(this), totalBadgesCost);
    }

    /* ------------- overrides ------------- */

    function tokenURI(uint256 id) public view override returns (string memory) {
        uint256 level = s().safeHouseData[id].level;
        uint256 districtId = s().safeHouseData[id].districtId;

        return
            districtId == 0
              ? s().unrevealedURI
              : string.concat(s().baseURI, level.toString(), '/', districtId.toString(), s().postFixURI); // prettier-ignore
    }

    function fulfillRandomWords(uint256, uint256[] calldata randomWords) internal override {
        s().pendingVRFRequest = false;

        uint256 rand = randomWords[0];

        uint256 numPending = s().requestQueue.length;

        for (uint256 i; i < numPending; ++i) {
            if (i != 0) rand = uint256(keccak256(abi.encode(rand, i)));

            uint256 id = s().requestQueue[i];

            s().safeHouseData[id].level = 1;
            s().safeHouseData[id].districtId = uint8(1 + (rand % 21));
        }

        delete s().requestQueue;
    }

    /* ------------- internal ------------- */

    function _mintInternal(address to, uint256 quantity) internal {
        if (quantity == 0) revert InvalidQuantity();

        for (uint256 i; i < quantity; ++i) {
            uint256 id = ++s().totalSupply;
            if (id > MAX_SUPPLY) revert ExceedsLimit();

            _mint(to, id);

            s().requestQueue.push(id);

            if (!s().pendingVRFRequest) {
                s().pendingVRFRequest = true;

                requestVRF();
            }
        }
    }

    function _processMessageFromRoot(
        uint256,
        address,
        bytes calldata message
    ) internal virtual override {
        bytes4 selector = bytes4(message);

        if (selector != MINT_ERC721_SELECTOR) revert InvalidSelector();

        address to = address(uint160(uint256(bytes32(message[4:36]))));

        _mintInternal(to, 1);
    }

    /* ------------- owner ------------- */

    function airdrop(address[] calldata tos, uint256 quantity) external onlyOwner {
        for (uint256 i; i < quantity; ++i) {
            _mintInternal(tos[i], quantity);
        }
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        s().baseURI = uri;
    }

    function setUnrevealedURI(string calldata uri) external onlyOwner {
        s().unrevealedURI = uri;
    }

    function setPostFixURI(string calldata postFix) external onlyOwner {
        s().postFixURI = postFix;
    }

    /* ------------- override ------------- */

    function _authorizeUpgrade() internal override onlyOwner {}

    function _authorizeTunnelController() internal override onlyOwner {}
}
