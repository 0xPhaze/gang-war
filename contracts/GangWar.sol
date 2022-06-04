// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeV} from "UDS/proxy/UUPSUpgradeV.sol";
import {OwnableUDS} from "UDS/OwnableUDS.sol";
import {ERC721UDS} from "UDS/ERC721UDS.sol";

// import {GangWarBase} from "./GangWarBase.sol";
import {GMCMarket} from "./GMCMarket.sol";
// import {ds, settings, District, Gangster} from
import "./GangWarStorage.sol";
// import "./GangWarBase.sol";

import "./lib/ArrayUtils.sol";

/* ============= Error ============= */

error NotAuthorized();

error BaronMustDeclareInitialAttack();
error IdsMustBeOfSameGang();
error InvalidConnectingDistrict();
error GangsterMustBeIdle();

error MoveOnCooldown();

contract GangWar is UUPSUpgradeV(1), OwnableUDS, GangWarBase, GMCMarket {
    // GMCMarket,
    // ERC721UDS gmc;

    // function init(ERC721UDS gmc_) external initializer {
    //     __Ownable_init();
    //     gmc = gmc_;
    // }

    /* ------------- Public ------------- */

    function joinGangAttack(
        uint256 districtId,
        uint256 connectingId,
        uint256[] calldata tokenIds
    ) public {
        bool attack = true;

        GANG gang = gangOf(tokenIds[0]);

        // validates physical connectedness
        // either districts are the same or there is a connection owned by gang
        if (
            !(districtId == connectingId || ds().connections[districtId][connectingId]) &&
            ds().districts[connectingId].occupants != gang
        ) revert InvalidConnectingDistrict();

        // validate baron attack declaration / (+special items)
        District storage district = ds().districts[districtId];

        if (attack && gangOf(district.baronAttackId) != gang) revert BaronMustDeclareInitialAttack();

        uint256 tokenId;
        Gangster storage gangster;

        for (uint256 i; i < tokenIds.length; ++i) {
            tokenId = tokenIds[i];

            if (gang != gangOf(tokenId)) revert IdsMustBeOfSameGang();

            gangster = ds().gangsters[tokenId];

            gangster.location = districtId;

            (PLAYER_STATE gangsterState, ) = _gangsterStatus(gangster);
            if (gangsterState != PLAYER_STATE.IDLE) revert GangsterMustBeIdle();

            // _validateGangMemberIsActionable(gangster);

            // remove from old district
        }

        district.attackForces[district.roundId][gang] += tokenIds.length;
    }

    function _gangsterStatus(Gangster storage gangster) internal view returns (PLAYER_STATE, int256) {
        District storage district = ds().districts[gangster.location];

        GANG gang = gangster.gang;

        uint256 roundId = district.roundId;

        // gangster not in sync with district => IDLE
        if (gangster.roundId != roundId) return (PLAYER_STATE.IDLE, 0);

        bool attacking;

        if (gangOf(district.baronAttackId) == gang) attacking = true;
        else assert(district.occupants == gang);
        // else if (district.occupants == gang) {
        //     attacking = false;
        // }

        int256 timeLeft;

        // -------- check lockup
        timeLeft = int256(settings().TIME_LOCKUP) - int256(block.timestamp - district.lockupTime);
        if (timeLeft > 0) return (PLAYER_STATE.LOCKUP, timeLeft);

        // -------- check gang war outcome
        timeLeft = int256(settings().TIME_REINFORCEMENTS) - int256(block.timestamp - district.attackDeclarationTime);
        uint256 outcome = district.outcomes[roundId];

        if (outcome == 0) return (attacking ? PLAYER_STATE.ATTACKING : PLAYER_STATE.DEFENDING, timeLeft);

        // -------- check injury
        bool injured = outcome & 1 == 0;

        if (!injured) return (PLAYER_STATE.IDLE, 0);

        timeLeft = int256(settings().TIME_RECOVERY) + timeLeft;
        if (timeLeft > 0) return (PLAYER_STATE.INJURED, timeLeft);

        return (PLAYER_STATE.IDLE, 0);
    }

    function _districtStatus(District storage district) internal view returns (DISTRICT_STATUS) {
        uint256 attackDeclarationTime = district.attackDeclarationTime;

        if (attackDeclarationTime == 0 || attackDeclarationTime < district.lastUpkeepTime) {
            return DISTRICT_STATUS.IDLE;
        }
        if (block.timestamp - attackDeclarationTime < settings().TIME_REINFORCEMENTS) {
            return DISTRICT_STATUS.ATTACKING;
        }
        return DISTRICT_STATUS.POST_ATTACK;
    }

    uint256 public immutable UPKEEP_INTERVAL = 15;

    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view returns (bool, bytes memory) {
        bool upkeepNeeded;
        District storage district;

        uint256[] memory districtUpkeepIds;

        for (uint256 id; id < 21; ++id) {
            district = ds().districts[id];

            if (_districtStatus(district) == DISTRICT_STATUS.POST_ATTACK) {
                upkeepNeeded = true;
                districtUpkeepIds = ArrayUtils.extend(districtUpkeepIds, id);
            }
        }

        return (upkeepNeeded, abi.encode(districtUpkeepIds));
    }

    // @note could exceed gas limits
    // @note should request via VRF
    function performUpkeep(bytes calldata performData) external {
        uint256[] memory districtIds = abi.decode(performData, (uint256[]));

        uint256 length = districtIds.length;

        for (uint256 i; i < length; ++i) {
            uint256 districtId = districtIds[i];
            District storage district = ds().districts[districtId];

            GANG occupants = district.occupants;
            GANG attackers = district.attackers;

            if (_districtStatus(district) == DISTRICT_STATUS.POST_ATTACK) {
                district.attackDeclarationTime = 0;
                district.lastUpkeepTime = block.timestamp;

                uint256 roundId = district.roundId++;

                uint256 rand = uint256(blockhash(block.number - 1));

                district.outcomes[roundId] = rand;

                if (gangWarWon(rand)) {
                    uint256 yield = settings().districtYield[districtId];

                    ds().gangYield[occupants] -= yield;
                    ds().gangYield[attackers] += yield;

                    district.occupants = attackers;
                    district.attackers = GANG.NONE;
                }

                district.baronAttackId = 0;
                district.baronDefenseId = 0;

                // request
            }
        }
    }

    function gangWarWon(uint256 rand) internal pure returns (bool) {
        return (rand & 1) != 0;
    }

    // // function _timeUntilAttack(District storage district) internal view returns (bool, uint256) {
    // //     if (district.lastUpkeepTime < district.attackDeclarationTime)
    // //         if (block.timestamp - district.attackDeclarationTime > settings().TIME_REINFORCEMENTS) {
    // //             return (true, timeDelta);
    // //         }
    // // }

    // // function _gangWarOutCome

    // function _validateGangMemberIsActionable(Gangster storage gangster) internal view {
    //     (PLAYER_STATE status, ) = _gangMemberStatus(gangster);
    //     if (status != PLAYER_STATE.IDLE) revert MoveOnCooldown();
    // }

    // function _setGangMemberStatus(
    //     uint256 districtId,
    //     GANG gang,
    //     uint256 tokenId
    // ) internal view {}

    function _validateMove(
        uint256 districtId,
        uint256 connectingId,
        MOVE_STATE moveState,
        GANG gangId
    ) internal view {}

    function gangOf(uint256 id) public pure returns (GANG) {
        return GANG(id % 3);
    }

    /* ------------- Owner ------------- */

    /* ------------- Internal ------------- */

    modifier validOwner(uint256 id) {
        // if (!gmc.ownerOf(id) == msg.sender) revert NotAuthorized();
        _;
    }

    function _authorizeUpgrade() internal override onlyOwner {}
}
