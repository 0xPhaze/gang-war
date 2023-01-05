// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeHouses} from "./SafeHouses.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {VRFConsumerV2} from "../lib/VRFConsumerV2.sol";
import {GMCChild as GMC} from "./GMCChild.sol";
import {ERC721EnumerableUDS} from "UDS/tokens/extensions/ERC721EnumerableUDS.sol";

import "solady/utils/LibString.sol";

// ------------- storage

struct VehicleData {
    uint8 level;
    uint8 districtId; // NOTE: either this is tied to mouse
}

struct VehiclesDS {
    uint16 totalSupply;
    uint16 totalSupplyBikes;
    uint16 totalSupplyVans;
    uint16 totalSupplyHelicopters;
    uint256[] requestQueue;
    mapping(uint256 => VehicleData) vehicleData;
    mapping(uint256 => bool) claimed;
    mapping(uint256 => uint256) vehicleToGangstaId;
    mapping(uint256 => uint256) gangstaToVehicleId;
    string baseURI;
    string postFixURI;
    string unrevealedURI;
}

bytes32 constant DIAMOND_STORAGE_VEHICLES = keccak256("diamond.storage.vehicles");

function s() pure returns (VehiclesDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_VEHICLES;
    assembly {
        diamondStorage.slot := slot
    }
}

// ------------- error

error ExceedsLimit();
error InvalidLevel();
error NotAuthorized();
error AlreadyClaimed();
error InvalidQuantity();
error InvalidGang();
error InvalidDistrictId();

/// @title Vehicles
/// @author phaze (https://github.com/0xPhaze)
contract Vehicles is UUPSUpgrade, OwnableUDS, ERC721EnumerableUDS, VRFConsumerV2 {
    using LibString for uint256;

    string public constant override name = "Vehicles";
    string public constant override symbol = "VHCL";

    uint256 public constant MAX_SUPPLY_BIKES = 3333;
    uint256 public constant MAX_SUPPLY_VANS = 1666;
    uint256 public constant MAX_SUPPLY_HELICOPTERS = 667;

    address public immutable gmc;
    address public immutable safeHouses;

    uint256 constant gangEncoding = 0x16a015aa05;

    constructor(
        address gmc_,
        address safeHouses_,
        address coordinator, // NOTE removed fxBaseChild
        bytes32 keyHash,
        uint64 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit
    ) VRFConsumerV2(coordinator, keyHash, subscriptionId, requestConfirmations, callbackGasLimit) {
        gmc = gmc_;
        safeHouses = safeHouses_;
    }

    function init() external initializer {
        __Ownable_init();
    }

    /* ------------- view ------------- */

    function claimed(uint256 id) public view returns (bool) {
        return s().claimed[id];
    }

    function totalSupplyVans() public view returns (uint256) {
        return s().totalSupplyVans;
    }

    function totalSupplyHelicopters() public view returns (uint256) {
        return s().totalSupplyHelicopters;
    }

    function getVehicleData(uint256 id) public view returns (VehicleData memory) {
        return s().vehicleData[id];
    }

    function getLevel(uint256 id) public view returns (uint256) {
        return s().vehicleData[id].level;
    }

    function getMultiplier(uint256 id) public view returns (uint256) {
        uint256 level = getLevel(id);

        return level * 7 / 2;
    }

    function getDistrictId(uint256 id) public view returns (uint256) {
        return s().vehicleData[id].districtId;
    }

    function districtToGang(uint256 id) public pure returns (uint256) {
        if (id == 0) revert InvalidDistrictId();

        return 3 & (gangEncoding >> ((id - 1) << 1));
    }

    function gangOf(uint256 id) public view returns (uint256) {
        uint256 districtId = s().vehicleData[id].districtId;

        return districtToGang(districtId);
    }

    function numVehiclessByDistrictId() public view returns (uint256[21] memory count) {
        uint256 supply = totalSupply();

        for (uint256 i = 1; i <= supply; ++i) {
            // TODO fix this
            uint256 districtId = s().vehicleData[i].districtId;

            if (districtId != 0) {
                ++count[districtId - 1];
            }
        }
    }

    /* ------------- external ------------- */

    function mint(uint256[] calldata safeHouseIds) external {
        if (safeHouseIds.length == 0) revert InvalidQuantity();

        for (uint256 i; i < safeHouseIds.length; ++i) {
            if (s().claimed[safeHouseIds[i]]) revert AlreadyClaimed();

            s().claimed[safeHouseIds[i]] = true;
        }

        uint256 supply = totalSupply();

        for (uint256 i; i < safeHouseIds.length; ++i) {
            uint256 id = 1 + supply + i;
            uint256 level = SafeHouses(safeHouses).getLevel(safeHouseIds[i]);

            _mintInternal(msg.sender, id, level);
        }
    }

    function equipGangsta(uint256[] calldata vehicleIds, uint256[] calldata gangstaIds) external {
        for (uint256 i; i < vehicleIds.length; ++i) {
            uint256 vehicleId = vehicleIds[i];
            uint256 gangstaId = gangstaIds[i];

            // make sure vehicle has been assigned a district
            uint256 districtId = s().vehicleData[vehicleId].districtId;
            uint256 vehicleGang = districtToGang(districtId);
            uint256 gangstaGang = uint8(GMC(gmc).gangOf(gangstaId));

            if (districtId == 0) revert InvalidGang();
            if (gangstaGang != vehicleGang) revert InvalidGang();
            if (msg.sender != ownerOf(vehicleId)) revert NotAuthorized();
            if (msg.sender != GMC(gmc).ownerOf(gangstaId)) revert NotAuthorized();

            // cleanup prev link from vehicle to gangsta
            uint256 prevGangstaId = s().vehicleToGangstaId[vehicleId];
            delete s().gangstaToVehicleId[prevGangstaId];

            // sever old connection of gangsta
            uint256 prevVehicleId = s().gangstaToVehicleId[gangstaId];

            delete s().vehicleToGangstaId[prevVehicleId];
            delete s().gangstaToVehicleId[gangstaId];

            // link vehicle and gangsta
            s().gangstaToVehicleId[gangstaId] = vehicleId;
            s().vehicleToGangstaId[vehicleId] = gangstaId;
        }
    }

    /* ------------- overrides ------------- */

    function tokenURI(uint256 id) public view override returns (string memory) {
        uint256 level = s().vehicleData[id].level;
        uint256 districtId = s().vehicleData[id].districtId;

        return districtId == 0
            ? s().unrevealedURI
            : string.concat(s().baseURI, level.toString(), '/', districtToGang(districtId).toString(), s().postFixURI);// forgefmt: disable-line
    }

    function fulfillRandomWords(uint256, uint256[] calldata randomWords) internal override {
        uint256 rand = randomWords[0];
        uint256 numPending = s().requestQueue.length;

        for (uint256 i; i < numPending && i < 50; ++i) {
            if (i != 0) rand = uint256(keccak256(abi.encode(rand, i)));

            uint256 id = s().requestQueue[numPending - i - 1];

            s().requestQueue.pop();
            s().vehicleData[id].districtId = uint8(1 + (rand % 21));
        }
    }

    /* ------------- internal ------------- */

    function _mintInternal(address to, uint256 id, uint256 level) internal {
        if (level == 1 && ++s().totalSupplyBikes > MAX_SUPPLY_BIKES) revert ExceedsLimit();
        else if (level == 2 && ++s().totalSupplyVans > MAX_SUPPLY_VANS) revert ExceedsLimit();
        else if (level == 3 && ++s().totalSupplyHelicopters > MAX_SUPPLY_HELICOPTERS) revert ExceedsLimit();
        else if (level < 1 || level > 3) revert InvalidLevel();

        _mint(to, id);

        s().vehicleData[id].level = uint8(level);
        s().requestQueue.push(id);

        if (s().requestQueue.length == 1) {
            requestVRF();
        }
    }

    /* ------------- owner ------------- */

    function forceRequestVRF() external onlyOwner {
        if (s().requestQueue.length == 0) revert();

        requestVRF();
    }

    function airdrop(address[] calldata tos, uint256 level) external onlyOwner {
        uint256 supply = totalSupply();

        for (uint256 i; i < tos.length; ++i) {
            uint256 id = 1 + supply + i;

            _mintInternal(tos[i], id, level);
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

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
