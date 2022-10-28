// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";
import {GangToken} from "./GangToken.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {VRFConsumerV2} from "../lib/VRFConsumerV2.sol";
import {FxBaseChildTunnel} from "fx-contracts/base/FxBaseChildTunnel.sol";
import {ERC721EnumerableUDS} from "UDS/tokens/extensions/ERC721EnumerableUDS.sol";
import {CONSECUTIVE_MINT_ERC721_SELECTOR} from "./SafeHouseClaim.sol";

import "solady/utils/LibString.sol";

// ------------- storage

struct SafeHouseData {
    uint8 level;
    uint8 districtId;
    uint40 lastClaim;
}

struct SafeHouseDS {
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
error NotAuthorized();
error InvalidQuantity();
error InvalidSelector();
error InvalidDistrictId();

/// @title Safe Houses
/// @author phaze (https://github.com/0xPhaze)
contract SafeHouses is UUPSUpgrade, OwnableUDS, ERC721EnumerableUDS, VRFConsumerV2, FxBaseChildTunnel {
    using LibString for uint256;

    string public constant override name = "Safe Houses";
    string public constant override symbol = "SAFE";

    uint256 public constant MINT_MICE_COST = 250_000e18;
    uint256 public constant LEVEL_2_MICE_COST = 375_000e18;
    uint256 public constant LEVEL_3_MICE_COST = 550_000e18;

    uint256 public constant MINT_BADGES_COST = 500e18;
    uint256 public constant LEVEL_2_BADGES_COST = 625e18;
    uint256 public constant LEVEL_3_BADGES_COST = 750e18;

    uint256 public constant MAX_SUPPLY = 3333;
    uint256 public constant MAX_SUPPLY_BARRACKS = 2000;
    uint256 public constant MAX_SUPPLY_HEADQUARTERS = 667;

    address public immutable mice;
    address public immutable badges;
    address public immutable gouda;

    address public immutable token0;
    address public immutable token1;
    address public immutable token2;

    uint256 immutable rewardStart = block.timestamp;
    uint256 constant gangEncoding = 0x16a015aa05;

    constructor(
        address mice_,
        address badges_,
        address gouda_,
        address token0_,
        address token1_,
        address token2_,
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
        gouda = gouda_;
        token0 = token0_;
        token1 = token1_;
        token2 = token2_;
    }

    function init() external initializer {
        __Ownable_init();
    }

    /* ------------- view ------------- */

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

    function goudaDailyRate(uint256 level) public pure returns (uint256) {
        if (level == 1) return 2e18;
        if (level == 2) return 4e18;
        if (level == 3) return 7e18;
        return 0;
    }

    function tokenDailyRate(uint256 level) public pure returns (uint256) {
        if (level == 1) return 300e18;
        if (level == 2) return 450e18;
        if (level == 3) return 600e18;
        return 0;
    }

    function districtToGang(uint256 id) public pure returns (uint256) {
        if (id == 0) revert InvalidDistrictId();
        return 3 & (gangEncoding >> ((id - 1) << 1));
    }

    function tokenAddress(uint256 gang) public view returns (address) {
        if (gang == 0) return token0;
        if (gang == 1) return token1;
        if (gang == 2) return token2;
        return address(0);
    }

    function pendingReward(uint256[] calldata ids) external view returns (uint256[4] memory reward) {
        SafeHouseData storage data;

        for (uint256 i; i < ids.length; ++i) {
            data = s().safeHouseData[ids[i]];

            uint256 level = data.level;
            uint256 lastClaim = data.lastClaim;
            uint256 districtId = data.districtId;

            uint256 gang = districtToGang(districtId);

            if (lastClaim == 0) lastClaim = rewardStart;

            reward[3] += ((block.timestamp - lastClaim) * goudaDailyRate(level)) / 1 days;
            reward[gang] += ((block.timestamp - lastClaim) * tokenDailyRate(level)) / 1 days;
        }
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
            if (ownerOf(ids[i]) != msg.sender) revert NotAuthorized();

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

    function claimReward(uint256[] calldata ids) external {
        SafeHouseData storage data;

        uint256 totalGoudaReward;
        uint256[3] memory totalTokenReward;

        for (uint256 i; i < ids.length; ++i) {
            if (ownerOf(ids[i]) != msg.sender) revert NotAuthorized();

            data = s().safeHouseData[ids[i]];

            uint256 level = data.level;
            uint256 lastClaim = data.lastClaim;
            uint256 districtId = data.districtId;

            uint256 gang = districtToGang(districtId);

            if (lastClaim == 0) lastClaim = rewardStart;

            totalGoudaReward += ((block.timestamp - lastClaim) * goudaDailyRate(level)) / 1 days;
            totalTokenReward[gang] += ((block.timestamp - lastClaim) * tokenDailyRate(level)) / 1 days;

            data.lastClaim = uint40(block.timestamp);
        }

        if (totalGoudaReward != 0) GangToken(gouda).mint(msg.sender, totalGoudaReward);
        if (totalTokenReward[0] != 0) GangToken(tokenAddress(0)).mint(msg.sender, totalTokenReward[0]);
        if (totalTokenReward[1] != 0) GangToken(tokenAddress(1)).mint(msg.sender, totalTokenReward[1]);
        if (totalTokenReward[2] != 0) GangToken(tokenAddress(2)).mint(msg.sender, totalTokenReward[2]);
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
        uint256 rand = randomWords[0];
        uint256 numPending = s().requestQueue.length;

        for (uint256 i; i < numPending; ++i) {
            if (i != 0) rand = uint256(keccak256(abi.encode(rand, i)));

            uint256 id = s().requestQueue[i];

            s().safeHouseData[id].districtId = uint8(1 + (rand % 21));
        }

        delete s().requestQueue;
    }

    /* ------------- internal ------------- */

    function _mintInternal(address to, uint256 quantity) internal {
        if (quantity == 0) revert InvalidQuantity();

        SafeHouseData storage data;

        uint256 supply = totalSupply();

        for (uint256 i; i < quantity; ++i) {
            uint256 id = 1 + supply + i;

            if (id > MAX_SUPPLY) revert ExceedsLimit();

            _mint(to, id);

            data = s().safeHouseData[id];
            data.level = 1;
            data.lastClaim = uint40(block.timestamp);

            s().requestQueue.push(id);

            if (s().requestQueue.length == 1) {
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

        if (selector != CONSECUTIVE_MINT_ERC721_SELECTOR) revert InvalidSelector();

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
