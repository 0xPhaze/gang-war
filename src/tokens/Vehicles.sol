// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GangWar} from "../GangWar.sol";
import {SafeHouses} from "./SafeHouses.sol";
import {GMCChild as GMC} from "./GMCChild.sol";
import {ERC721EnumerableUDS} from "UDS/tokens/extensions/ERC721EnumerableUDS.sol";

import {LibString} from "solady/utils/LibString.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {VRFConsumerV2} from "../lib/VRFConsumerV2.sol";

// ------------- storage

struct VehicleData {
    uint8 level;
    uint8 districtId;
}

struct VehiclesDS {
    GangWar gangWar;
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
error CannotEquipBarons();
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
    SafeHouses public immutable safeHouses;

    uint256 constant gangEncoding = 0x16a015aa05;

    constructor(
        GMC gmc_,
        SafeHouses safeHouses_,
        address coordinator,
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

    function gangWar() external view returns (GangWar) {
        return s().gangWar;
    }

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

        if (level == 1) return 3;
        if (level == 2) return 7;
        if (level == 3) return 14;

        return 1;
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
        if (id == 0) return 4;

        return 3 & (gangEncoding >> ((id - 1) << 1));
    }

    function gangOf(uint256 id) public view returns (uint256) {
        uint256 districtId = s().vehicleData[id].districtId;

        return districtToGang(districtId);
    }

    function numVehiclesByDistrictId() public view returns (uint256[3][3] memory count) {
        unchecked {
            uint256 supply = totalSupply();

            for (uint256 id = 1; id <= supply; ++id) {
                uint256 gangsterId = s().vehicleToGangsterId[id];

                if (gangsterId == 0) continue;

                uint256 districtId = s().gangWar.getGangsterLocation(gangsterId);

                if (districtId == type(uint256).max) continue;

                uint256 vehicleLvl = s().vehicleData[id].level;
                if (vehicleLvl == 0) continue;

                uint256 gangId = gangOf(id);

                // maxCount = 4096;
                count[vehicleLvl - 1][gangId] += 1 << 12 * districtId;
            }
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

            // uint256 equippedGangsterId = s().vehicleToGangsterId[vehicleId];
            // uint256 districtId = s().gangWar.getGangsterLocation(equippedGangsterId);
            // if (districtId != 0) revert NotAuthorizedDuringGangWar();

            if (gangsterId != 0) {
                uint256 vehicleGang = districtToGang(vehicleDistrictId);
                uint256 gangsterGang = uint8(gmc.gangOf(gangsterId));

                if (gmc.isBaron(gangsterId)) revert CannotEquipBarons();
                if (gangsterGang != vehicleGang) revert InvalidGang();
                if (msg.sender != ownerOf(vehicleId)) revert NotAuthorized();
                if (msg.sender != gmc.ownerOf(gangsterId)) revert NotAuthorized();
            }

            // cleanup prev link from vehicle to gangster
            uint256 prevGangsterId = s().vehicleToGangsterId[vehicleId];
            uint256 prevGangsterDistrictId = s().gangWar.getGangsterLocation(prevGangsterId);

            if (gangsterId == 0 && msg.sender != ownerOf(vehicleId) && msg.sender != gmc.ownerOf(prevGangsterId)) {
                revert NotAuthorized();
            }
            if (prevGangsterDistrictId != type(uint256).max) revert NotAuthorizedDuringGangWar();
            delete s().gangsterToVehicleId[prevGangsterId];

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
        uint256 gang = districtToGang(districtId);

        if (gang == 4) revert InvalidGang();

        return districtId == 0
            ? s().unrevealedURI
            : string.concat(s().baseURI, level.toString(), '/', gang.toString(), s().postFixURI);// forgefmt: disable-line
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

        if (s().requestQueue.length == 1) requestVRF();
    }

    /* ------------- owner ------------- */

    function forceRequestVRF() external onlyOwner {
        if (s().requestQueue.length == 0) revert();

        requestVRF();
    }

    function airdrop(address[] calldata tos, uint256[] calldata ids, uint256 level) external onlyOwner {
        for (uint256 i; i < tos.length; ++i) {
            if (ownerOf(ids[i]) != address(0)) revert AlreadyClaimed();

            _mintInternal(tos[i], ids[i], level);
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

    function setGangWar(GangWar gangWar_) external onlyOwner {
        s().gangWar = gangWar_;
    }

    /* ------------- override ------------- */

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
