// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GangWar} from "../GangWar.sol";
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
    uint8 districtId;
}

struct VehiclesDS {
    uint16 totalSupply;
    uint16 totalSupplyBikes;
    uint16 totalSupplyVans;
    uint16 totalSupplyHelicopters;
    uint256[] requestQueue;
    mapping(uint256 => VehicleData) vehicleData;
    mapping(uint256 => bool) claimed;
    mapping(uint256 => uint256) vehicleToGangsterId;
    mapping(uint256 => uint256) gangsterToVehicleId;
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

error InvalidGang();
error ExceedsLimit();
error InvalidLevel();
error NotAuthorized();
error AlreadyClaimed();
error InvalidQuantity();
error InvalidDistrictId();
error NotAuthorizedDuringGangWar();

/// @title Vehicles
/// @author phaze (https://github.com/0xPhaze)
contract Vehicles is UUPSUpgrade, OwnableUDS, ERC721EnumerableUDS, VRFConsumerV2 {
    VehiclesDS private __storageLayout;

    using LibString for uint256;

    string public constant override name = "Vehicles";
    string public constant override symbol = "VHCL";

    uint256 public constant MAX_SUPPLY_BIKES = 3333;
    uint256 public constant MAX_SUPPLY_VANS = 1666;
    uint256 public constant MAX_SUPPLY_HELICOPTERS = 667;

    GMC public immutable gmc;
    GangWar public immutable gangWar;
    SafeHouses public immutable safeHouses;

    uint256 constant gangEncoding = 0x16a015aa05;

    constructor(
        GMC gmc_,
        GangWar gangWar_,
        SafeHouses safeHouses_,
        address coordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit
    ) VRFConsumerV2(coordinator, keyHash, subscriptionId, requestConfirmations, callbackGasLimit) {
        gmc = gmc_;
        gangWar = gangWar_;
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

        return ((3 * level - 1) * level + 4) >> 1;
    }

    function getGangsterMultiplier(uint256 gangsterId) public view returns (uint256) {
        uint256 vehicleId = s().gangsterToVehicleId[gangsterId];

        if (vehicleId == 0) return 1;

        return getMultiplier(vehicleId);
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

    function numVehiclessByDistrictId() public view returns (uint256[21][3] memory count) {
        uint256 supply = totalSupply();

        for (uint256 i = 1; i <= supply; ++i) {
            uint256 gangsterId = s().vehicleToGangsterId[i];
            if (gangsterId == 0) continue;

            uint256 districtId = gangWar.getGangsterLocation(gangsterId);
            if (districtId == 0) continue;

            uint256 vehicleLvl = s().vehicleData[i].level;
            if (vehicleLvl == 0) continue;

            ++count[vehicleLvl - 1][districtId - 1];
        }
    }

    function gangsterToVehicleId(uint256 gangsterId) public view returns (uint256) {
        return s().gangsterToVehicleId[gangsterId];
    }

    function vehicleToGangsterId(uint256 vehicleId) public view returns (uint256) {
        return s().vehicleToGangsterId[vehicleId];
    }

    /* ------------- external ------------- */

    function mint(uint256[] calldata safeHouseIds) external {
        if (safeHouseIds.length == 0) revert InvalidQuantity();

        for (uint256 i; i < safeHouseIds.length; ++i) {
            if (s().claimed[safeHouseIds[i]]) revert AlreadyClaimed();
            if (safeHouses.ownerOf(safeHouseIds[i]) != msg.sender) revert NotAuthorized();

            s().claimed[safeHouseIds[i]] = true;
        }

        uint256 supply = totalSupply();

        for (uint256 i; i < safeHouseIds.length; ++i) {
            uint256 id = 1 + supply + i;
            uint256 level = safeHouses.getLevel(safeHouseIds[i]);

            _mintInternal(msg.sender, id, level);
        }
    }

    function equipGangster(uint256[] calldata vehicleIds, uint256[] calldata gangsterIds) external {
        for (uint256 i; i < vehicleIds.length; ++i) {
            uint256 vehicleId = vehicleIds[i];
            uint256 gangsterId = gangsterIds[i];
            uint256 vehicleDistrictId = s().vehicleData[vehicleId].districtId;

            // make sure vehicle has been assigned a district
            if (vehicleDistrictId == 0) revert InvalidGang();
            if (msg.sender != ownerOf(vehicleId)) revert NotAuthorized();

            if (gangsterId != 0) {
                uint256 vehicleGang = districtToGang(vehicleDistrictId);
                uint256 gangsterGang = uint8(gmc.gangOf(gangsterId));
                uint256 districtId = gangWar.getGangsterLocation(gangsterId);

                if (districtId != 0) revert NotAuthorizedDuringGangWar();
                if (gangsterGang != vehicleGang) revert InvalidGang();
                if (msg.sender != gmc.ownerOf(gangsterId)) revert NotAuthorized();
            }

            // cleanup prev link from vehicle to gangster
            uint256 prevGangsterId = s().vehicleToGangsterId[vehicleId];
            delete s().gangsterToVehicleId[prevGangsterId];

            uint256 prevGangsterDistrictId = gangWar.getGangsterLocation(prevGangsterId);
            if (prevGangsterDistrictId != 0) revert NotAuthorizedDuringGangWar();

            // sever old connection of gangster
            uint256 prevVehicleId = s().gangsterToVehicleId[gangsterId];
            delete s().vehicleToGangsterId[prevVehicleId];

            // link vehicle and gangster
            s().gangsterToVehicleId[gangsterId] = vehicleId;
            s().vehicleToGangsterId[vehicleId] = gangsterId;
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
