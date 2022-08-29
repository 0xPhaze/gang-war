// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Constants.sol";
import {GangVault} from "./GangVault.sol";
import {GangToken} from "./tokens/GangToken.sol";
import {VRFConsumerV2} from "./lib/VRFConsumerV2.sol";
import {GMCChild as GMC, Offer} from "./tokens/GMCChild.sol";

import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";
import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

import "forge-std/console.sol";

// ------------- error

error NotAuthorized();
error InvalidItemId();

error BaronMustDeclareInitialAttack();
error IdsMustBeOfSameGang();
error ConnectingDistrictNotOwnedByGang();
error GangsterInactionable();
error BaronInactionable();
error InvalidConnectingDistrict();
error AlreadyInDistrict();
error DistrictInvalidState();
error GangsterInvalidState();

error MoveOnCooldown();
error TokenMustBeGangster();
error TokenMustBeBaron();
error BaronAttackAlreadyDeclared();
error CannotAttackDistrictOwnedByGang();
error DistrictNotOwnedByGang();
error InvalidToken();

error InvalidUpkeep();
error InvalidVRFRequest();

error CallerNotOwner();
error ItemAlreadyActive();

contract GangWar is
    UUPSUpgrade,
    OwnableUDS,
    // GangWarBase,
    // GangWarGameLogic,
    // GangWarBase,
    VRFConsumerV2 /*, GMCMarket */
{
    GangWarDS private __storageLayout;

    event BaronAttackDeclared(
        uint256 indexed connectingId,
        uint256 indexed districtId,
        Gang indexed gang,
        uint256 tokenId
    );
    event EnterGangWar(uint256 indexed districtId, Gang indexed gang, uint256 tokenId);
    event ExitGangWar(uint256 indexed districtId, Gang indexed gang, uint256 tokenId);
    event BaronDefenseDeclared(uint256 indexed districtId, Gang indexed gang, uint256 tokenId);
    event GangWarWon(uint256 indexed districtId, Gang indexed losers, Gang indexed winners);
    event CopsLockup(uint256 indexed districtId);

    GMC public immutable gmc;
    GangToken public immutable badges;
    GangVault public immutable vault;

    constructor(
        GMC gmc_,
        GangVault vault_,
        GangToken badges_,
        address coordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit
    ) VRFConsumerV2(coordinator, keyHash, subscriptionId, requestConfirmations, callbackGasLimit) {
        gmc = gmc_;
        vault = vault_;
        badges = badges_;
    }

    /* ------------- init ------------- */

    function init(uint256 connections) external initializer {
        __Ownable_init();

        s().districtConnections = connections;

        // reset(occupants, yields);
    }

    function reset(Gang[21] calldata occupants, uint256[21] calldata yields) public onlyOwner {
        uint256[3] memory initialGangYields;

        District storage district;

        for (uint256 i; i < 21; ++i) {
            district = s().districts[i];

            // initialize rounds
            district.roundId = 1;

            // initialize occupants and yield token
            district.token = occupants[i];
            district.occupants = occupants[i];

            // initialize district yield amount
            district.yield = yields[i];

            initialGangYields[uint256(occupants[i])] += yields[i];
        }

        // initialize yields for gangs
        vault.setYield(0, [initialGangYields[0], uint256(0), uint256(0)]);
        vault.setYield(1, [uint256(0), initialGangYields[1], uint256(0)]);
        vault.setYield(2, [uint256(0), uint256(0), initialGangYields[2]]);
    }

    function purchaseBaronItem(uint256 baronId, uint256 itemId) external {
        _verifyAuthorized(msg.sender, baronId);

        if (!isBaron(baronId)) revert TokenMustBeBaron();

        uint256 price = s().baronItemCost[itemId];
        if (price == 0) revert InvalidItemId();

        Gang gang = gangOf(baronId);

        // 3:2 exchange rate
        price /= 2;

        vault.spendGangVaultBalance(uint256(gang), price, price, price, true);

        s().baronItems[gang][itemId] += 1;
    }

    function useBaronItem(
        uint256 baronId,
        uint256 itemId,
        uint256 districtId
    ) external {
        _verifyAuthorized(msg.sender, baronId);

        if (!isBaron(baronId)) revert TokenMustBeBaron();
        if (itemId == ITEM_SEWER) revert InvalidItemId();

        Gang gang = gangOf(baronId);

        _useBaronItem(gang, itemId, districtId);
    }

    /* ------------- view ------------- */

    function getGangster(uint256 tokenId) external view returns (Gangster memory gangster) {
        gangster = s().gangsters[tokenId];

        gangster.gang = gangOf(tokenId);

        (gangster.state, gangster.stateCountdown) = _gangsterStateAndCountdown(tokenId);
    }

    function getDistrict(uint256 districtId) external view returns (District memory district) {
        District storage sDistrict = s().districts[districtId];

        district = sDistrict;

        (district.state, district.stateCountdown) = _districtStateAndCountdown(sDistrict);

        district.attackForces = s().districtAttackForces[districtId][district.roundId];
        district.defenseForces = s().districtDefenseForces[districtId][district.roundId];
    }

    function gangOf(uint256 id) public pure returns (Gang) {
        return id == 0 ? Gang.NONE : Gang((id < 10000 ? id - 1 : id - (10001 - 3)) % 3);
    }

    function getBaronItemBalances(Gang gang) external view returns (uint256[] memory items) {
        items = new uint256[](NUM_BARON_ITEMS);
        unchecked {
            for (uint256 i; i < NUM_BARON_ITEMS; ++i) items[i] = s().baronItems[gang][i];
        }
    }

    /* ------------- external ------------- */

    function baronDeclareAttack(
        uint256 connectingId,
        uint256 districtId,
        uint256 tokenId,
        bool sewers
    ) external {
        Gang gang = gangOf(tokenId);
        District storage district = s().districts[districtId];

        (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

        _verifyAuthorized(msg.sender, tokenId);

        if (!isConnecting(connectingId, districtId)) {
            if (!sewers) revert InvalidConnectingDistrict();

            _useBaronItem(gang, ITEM_SEWER, districtId);
        }

        if (!isBaron(tokenId)) revert TokenMustBeBaron();
        if (districtState != DISTRICT_STATE.IDLE) revert DistrictInvalidState();
        if (district.occupants == gang) revert CannotAttackDistrictOwnedByGang();
        if (s().districts[connectingId].occupants != gang) revert ConnectingDistrictNotOwnedByGang();

        (PLAYER_STATE baronState, ) = _gangsterStateAndCountdown(tokenId);
        if (baronState != PLAYER_STATE.IDLE) revert BaronInactionable();

        // collect badges from previous gang war
        _collectBadges(tokenId);

        Gangster storage baron = s().gangsters[tokenId];

        baron.location = districtId;
        baron.roundId = district.roundId;

        district.attackers = gang;
        district.baronAttackId = tokenId;

        district.attackDeclarationTime = block.timestamp;

        emit BaronAttackDeclared(connectingId, districtId, gang, tokenId);
    }

    function baronDeclareDefense(uint256 districtId, uint256 tokenId) external {
        Gang gang = gangOf(tokenId);
        District storage district = s().districts[districtId];

        (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

        _verifyAuthorized(msg.sender, tokenId);

        if (!isBaron(tokenId)) revert TokenMustBeBaron();
        if (districtState != DISTRICT_STATE.REINFORCEMENT) revert DistrictInvalidState();
        if (district.occupants != gang) revert DistrictNotOwnedByGang();

        (PLAYER_STATE gangsterState, ) = _gangsterStateAndCountdown(tokenId);
        if (gangsterState != PLAYER_STATE.IDLE) revert BaronInactionable();

        _collectBadges(tokenId);

        Gangster storage baron = s().gangsters[tokenId];

        baron.location = districtId;
        baron.roundId = district.roundId;

        district.baronDefenseId = tokenId;

        emit BaronDefenseDeclared(districtId, gang, tokenId);
    }

    function joinGangAttack(
        uint256 connectingId,
        uint256 districtId,
        uint256[] calldata tokenIds
    ) public {
        Gang gang = gangOf(tokenIds[0]);
        District storage district = s().districts[districtId];

        // @note need to find reliable way to check for attackers
        uint256 baronAttackId = district.baronAttackId;
        if (baronAttackId == 0 || gangOf(baronAttackId) != gang) revert BaronMustDeclareInitialAttack();
        if (!isConnecting(connectingId, districtId)) revert InvalidConnectingDistrict();
        if (s().districts[connectingId].occupants != gang) revert InvalidConnectingDistrict();

        _enterGangWar(districtId, tokenIds, gang, true);
    }

    function joinGangDefense(uint256 districtId, uint256[] calldata tokenIds) public {
        Gang gang = gangOf(tokenIds[0]);

        if (s().districts[districtId].occupants != gang) revert InvalidConnectingDistrict();

        _enterGangWar(districtId, tokenIds, gang, false);
    }

    /* ------------- bribery ------------- */

    function bribery(
        uint256[] calldata tokenIds,
        address token,
        bool isBribery
    ) external {
        uint256 tokenFee = s().briberyFee[token];
        if (tokenFee == 0) revert InvalidToken();

        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];

            if (isBaron(tokenId)) revert TokenMustBeGangster();

            (PLAYER_STATE gangsterState, ) = _gangsterStateAndCountdown(tokenId);

            if (gangsterState != PLAYER_STATE.INJURED && gangsterState != PLAYER_STATE.LOCKUP)
                revert GangsterInvalidState();

            ERC20UDS(token).transferFrom(msg.sender, address(this), tokenFee);

            if (isBribery) s().gangsters[tokenId].bribery += 1;
            else s().gangsters[tokenId].recovery += 1;
        }
    }

    function briberyFee(address token) external view returns (uint256) {
        return s().briberyFee[token];
    }

    function baronItemCost(uint256 id) external view returns (uint256) {
        return s().baronItemCost[id];
    }

    function exitGangWar(uint256[] calldata tokenIds) public {
        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];

            if (isBaron(tokenId)) revert TokenMustBeGangster();

            (PLAYER_STATE state, ) = _gangsterStateAndCountdown(tokenId);

            if (state != PLAYER_STATE.ATTACK && state != PLAYER_STATE.DEFEND) revert GangsterInvalidState();

            bool attacking = state == PLAYER_STATE.ATTACK;

            _verifyAuthorized(msg.sender, tokenId);

            Gangster storage gangster = s().gangsters[tokenId];

            uint256 districtId = gangster.location;
            uint256 roundId = gangster.roundId;

            Gang gang = gangOf(tokenId);

            if (attacking) s().districtAttackForces[districtId][roundId]--;
            else s().districtDefenseForces[districtId][roundId]--;

            _collectBadges(tokenId);

            emit ExitGangWar(districtId, gang, tokenId);

            gangster.roundId = 0;
            gangster.location = 0;
            gangster.bribery = 0;
            gangster.recovery = 0;
        }
    }

    function getGangWarOutcome(uint256 districtId, uint256 roundId) external view returns (uint256) {
        return s().gangWarOutcomes[districtId][roundId];
    }

    /* ------------- internal ------------- */

    function _enterGangWar(
        uint256 districtId,
        uint256[] calldata tokenIds,
        Gang gang,
        bool attack
    ) internal {
        District storage district = s().districts[districtId];

        (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

        if (districtState != DISTRICT_STATE.IDLE && districtState != DISTRICT_STATE.REINFORCEMENT)
            revert DistrictInvalidState();

        uint256 districtRoundId = district.roundId;

        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];

            if (isBaron(tokenId)) revert TokenMustBeGangster();
            if (gang != gangOf(tokenId)) revert IdsMustBeOfSameGang();

            _verifyAuthorized(msg.sender, tokenId);

            Gangster storage gangster = s().gangsters[tokenId];

            (PLAYER_STATE state, ) = _gangsterStateAndCountdown(tokenId);

            if (state != PLAYER_STATE.IDLE && state != PLAYER_STATE.ATTACK && state != PLAYER_STATE.DEFEND)
                revert GangsterInactionable();

            // already attacking/defending in another district
            if (state == PLAYER_STATE.ATTACK || state == PLAYER_STATE.DEFEND) {
                uint256 gangsterLocation = gangster.location;
                if (gangsterLocation == districtId) revert AlreadyInDistrict();

                uint256 oldDistrictRoundId = s().districts[gangsterLocation].roundId;

                // remove from old district
                if (attack) s().districtAttackForces[gangsterLocation][oldDistrictRoundId]--;
                else s().districtDefenseForces[gangsterLocation][oldDistrictRoundId]--;

                emit ExitGangWar(gangsterLocation, gang, tokenId);
            }

            _collectBadges(tokenId);

            gangster.bribery = 0;
            gangster.recovery = 0;
            gangster.location = districtId;
            gangster.roundId = districtRoundId;
            gangster.attack = attack;

            emit EnterGangWar(districtId, gang, tokenId);
        }

        if (attack) s().districtAttackForces[districtId][districtRoundId] += tokenIds.length;
        else s().districtDefenseForces[districtId][districtRoundId] += tokenIds.length;
    }

    function _gangsterStateAndCountdown(uint256 gangsterId) internal view returns (PLAYER_STATE, int256) {
        Gangster storage gangster = s().gangsters[gangsterId];

        uint256 districtId = gangster.location;
        District storage district = s().districts[districtId];

        uint256 districtRoundId = district.roundId;
        uint256 gangsterRoundId = gangster.roundId;

        // gangster not in sync with district => IDLE
        if (districtRoundId > 1 + gangsterRoundId) return (PLAYER_STATE.IDLE, 0);

        int256 stateCountdown;

        // -------- check lockup (takes precedence); if lockupTime is still active, then player must be in round
        uint256 lockupTime = district.lockupTime;

        if (lockupTime != 0) {
            stateCountdown = int256(TIME_LOCKUP / (1 << gangster.bribery)) - int256(block.timestamp - lockupTime);
            if (stateCountdown > 0) return (PLAYER_STATE.LOCKUP, stateCountdown);
        }

        bool isActiveRound = districtRoundId == gangsterRoundId;

        if (isActiveRound) {
            Gang gang = gangOf(gangsterId);

            bool attacking = district.attackers == gang;

            // -------- check gang war outcome
            uint256 attackDeclarationTime = district.attackDeclarationTime;

            if (attackDeclarationTime == 0) return (PLAYER_STATE.IDLE, 0);

            stateCountdown = int256(TIME_REINFORCEMENTS) - int256(block.timestamp - attackDeclarationTime);

            // player in reinforcement phase; not committed yet
            if (stateCountdown > 0) return (attacking ? PLAYER_STATE.ATTACK : PLAYER_STATE.DEFEND, stateCountdown);

            stateCountdown += int256(TIME_GANG_WAR);

            return (attacking ? PLAYER_STATE.ATTACK_LOCKED : PLAYER_STATE.DEFEND_LOCKED, stateCountdown);
        }

        // we assume district.lastOutcomeTime must be non-zero
        // as otherwise the roundIds would match

        // -------- check injury
        bool injured = isInjured(gangsterId, districtId, districtRoundId);

        if (injured) {
            stateCountdown = int256(TIME_RECOVERY / (1 << gangster.recovery)) - int256(block.timestamp - district.lastOutcomeTime); // prettier-ignore

            if (stateCountdown > 0) return (PLAYER_STATE.INJURED, stateCountdown);
        }

        return (PLAYER_STATE.IDLE, 0);
    }

    function _districtStateAndCountdown(District storage district) internal view returns (DISTRICT_STATE, int256) {
        int256 stateCountdown = int256(TIME_LOCKUP) - int256(block.timestamp - district.lockupTime);

        // console.logInt(int256(TIME_LOCKUP));
        // console.logInt(int256(block.timestamp));
        // console.logInt(int256(district.lockupTime));
        // console.logInt(int256(block.timestamp - district.lockupTime));
        // console.logInt(int256(stateCountdown));
        // console.log("----");

        if (stateCountdown > 0) return (DISTRICT_STATE.LOCKUP, stateCountdown);

        stateCountdown = int256(TIME_TRUCE) - int256(block.timestamp - district.lastOutcomeTime);
        if (stateCountdown > 0) return (DISTRICT_STATE.TRUCE, stateCountdown);

        uint256 attackDeclarationTime = district.attackDeclarationTime;
        if (attackDeclarationTime == 0) return (DISTRICT_STATE.IDLE, 0);

        int256 timeReinforcement = int256(TIME_REINFORCEMENTS * (100 - ((district.activeItems >> ITEM_BLITZ) & 1) * ITEM_BLITZ_TIME_REDUCTION) / 100); // prettier-ignore
        stateCountdown = timeReinforcement - int256(block.timestamp - attackDeclarationTime);

        if (stateCountdown > 0) return (DISTRICT_STATE.REINFORCEMENT, stateCountdown);

        stateCountdown += int256(TIME_GANG_WAR);
        if (stateCountdown > 0) return (DISTRICT_STATE.GANG_WAR, stateCountdown);

        return (DISTRICT_STATE.POST_GANG_WAR, stateCountdown);
    }

    /* ------------- hooks ------------- */

    function _collectBadges(uint256 gangsterId) internal {
        Gangster storage gangster = s().gangsters[gangsterId];

        uint256 roundId = gangster.roundId;

        if (roundId != 0) {
            uint256 districtId = gangster.location;

            uint256 outcome = gangWarOutcome(districtId, roundId);

            if (outcome != 0) {
                uint256 badgesEarned = gangWarWon(districtId, roundId) ? BADGES_EARNED_VICTORY : BADGES_EARNED_DEFEAT;

                // @note can we assume msg.sender?
                address owner = gmc.ownerOf(gangsterId);

                Offer memory rental = gmc.getActiveOffer(gangsterId);

                address renter = rental.renter;

                if (renter != address(0)) {
                    uint256 renterAmount = (badgesEarned * rental.renterShare) / 100;

                    badges.mint(renter, renterAmount);

                    badgesEarned -= renterAmount;
                }

                badges.mint(owner, badgesEarned);

                gangster.roundId = 0;
            }
        }
    }

    function _verifyAuthorized(address owner, uint256 tokenId) internal view {
        if (!gmc.isAuthorized(owner, tokenId)) revert NotAuthorized();
    }

    /* ------------- upkeep ------------- */

    function checkUpkeep(bytes calldata) external view returns (bool, bytes memory) {
        uint256 ids;
        District storage district;

        for (uint256 id; id < 21; ++id) {
            district = s().districts[id];

            (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

            if (
                districtState == DISTRICT_STATE.POST_GANG_WAR &&
                block.timestamp - district.lastUpkeepTime > UPKEEP_INTERVAL // at least wait 1 minute for re-run
            ) {
                ids |= 1 << id;
            }
        }

        return (ids > 0, abi.encode(ids));
    }

    function performUpkeep(bytes calldata performData) external {
        uint256 ids = abi.decode(performData, (uint256));
        District storage district;

        uint256 upkeepIds;

        for (uint256 id; id < 21; ++id) {
            if ((ids >> id) & 1 != 0) {
                district = s().districts[id];

                (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

                if (
                    districtState == DISTRICT_STATE.POST_GANG_WAR &&
                    block.timestamp - district.lastUpkeepTime > UPKEEP_INTERVAL // at least wait 1 minute for re-run
                ) {
                    district.lastUpkeepTime = block.timestamp;
                    upkeepIds |= 1 << id;
                }
            }
        }

        if (upkeepIds != 0) {
            uint256 requestId = requestRandomWords(1);
            s().requestIdToDistrictIds[requestId] = upkeepIds;
        }
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 ids = s().requestIdToDistrictIds[requestId];

        if (ids == 0) revert InvalidVRFRequest();

        uint256 rand = randomWords[0];
        District storage district;

        // possible lockup, need to know attackers/defenders
        // before state update. Though the lockup effect will
        // happen afterwards, just to be sure that the VRF request
        // was valid
        bool lockup = uint256(keccak256(abi.encode(rand, 0))) % 100 < LOCKUP_CHANCE;
        uint256 lockupDistrictId = rand % 21;

        bool upkeepTriggered;

        if (lockup) {
            district = s().districts[lockupDistrictId];

            uint256 lockupTime = district.lockupTime;
            if (block.timestamp - lockupTime < TIME_LOCKUP) {
                lockup = false; // already in lockup state
            } else {
                Gang token = district.token;

                uint256 lockupAmount_0;
                uint256 lockupAmount_1;
                uint256 lockupAmount_2;

                if (token == Gang.YAKUZA) lockupAmount_0 = LOCKUP_FINE;
                else if (token == Gang.CARTEL) lockupAmount_1 = LOCKUP_FINE;
                else if (token == Gang.CYBERP) lockupAmount_2 = LOCKUP_FINE;

                uint256 lockupOccupants = uint256(district.occupants);
                uint256 lockupAttackers = uint256(district.attackDeclarationTime != 0 ? district.attackers : Gang.NONE);

                vault.spendGangVaultBalance(lockupOccupants, lockupAmount_0, lockupAmount_1, lockupAmount_2, false);

                // if attackers are present
                if (lockupAttackers != uint256(Gang.NONE)) {
                    vault.spendGangVaultBalance(lockupAttackers, lockupAmount_0, lockupAmount_1, lockupAmount_2, false);
                }
            }
        }

        for (uint256 id; id < 21; ) {
            if ((ids >> id) & 1 != 0) {
                district = s().districts[id];

                (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

                if (districtState == DISTRICT_STATE.POST_GANG_WAR) {
                    Gang attackers = district.attackers;
                    Gang occupants = district.occupants;

                    uint256 roundId = district.roundId++;

                    uint256 r = uint256(keccak256(abi.encode(rand, id)));

                    // advance state
                    s().gangWarOutcomes[id][roundId] = r;
                    district.lastOutcomeTime = block.timestamp;

                    if (gangWarWon(id, roundId)) {
                        vault.transferYield(
                            uint256(occupants),
                            uint256(attackers),
                            uint256(district.token),
                            district.yield
                        );

                        district.occupants = attackers;

                        emit GangWarWon(id, occupants, attackers);
                    } else {
                        emit GangWarWon(id, attackers, occupants);
                    }

                    district.attackers = Gang.NONE;
                    district.attackDeclarationTime = 0;
                    district.baronAttackId = 0;
                    district.baronDefenseId = 0;
                    district.activeItems = 0;
                }

                upkeepTriggered = true;
            }

            unchecked {
                ++id;
            }
        }

        if (!upkeepTriggered) revert InvalidUpkeep();

        if (lockup) {
            // only set state after processing
            s().districts[lockupDistrictId].lockupTime = block.timestamp;
        }

        delete s().requestIdToDistrictIds[requestId];
    }

    /* ------------- private ------------- */

    function isBaron(uint256 tokenId) internal pure returns (bool) {
        return tokenId >= 10_000;
    }

    function _useBaronItem(
        Gang gang,
        uint256 itemId,
        uint256 districtId
    ) internal {
        s().baronItems[gang][itemId] -= 1;

        uint256 items = s().districts[districtId].activeItems;

        if (items & (1 << itemId) != 0) revert ItemAlreadyActive();

        s().districts[districtId].activeItems = items | (1 << itemId);
    }

    function isConnecting(uint256 districtA, uint256 districtB) internal view returns (bool) {
        return LibPackedMap.isConnecting(s().districtConnections, districtA, districtB);
    }

    function gangWarOutcome(uint256 districtId, uint256 roundId) public view returns (uint256) {
        return s().gangWarOutcomes[districtId][roundId];
    }

    function gangWarWon(uint256 districtId, uint256 roundId) public view returns (bool) {
        uint256 gRand = s().gangWarOutcomes[districtId][roundId];

        uint256 p = gangWarWonDistrictProb(districtId, roundId);

        return gRand >> 128 < p;
    }

    function gangWarWonDistrictProb(uint256 districtId, uint256 roundId) private view returns (uint256) {
        uint256 attackForce = s().districtAttackForces[districtId][roundId];
        uint256 defenseForce = s().districtDefenseForces[districtId][roundId];

        District storage district = s().districts[districtId];

        uint256 items = district.activeItems;

        attackForce += ((items >> ITEM_SMOKE) & 1) * attackForce * ITEM_SMOKE_ATTACK_INCREASE;
        defenseForce += ((items >> ITEM_BARRICADES) & 1) * defenseForce * ITEM_BARRICADES_DEFENSE_INCREASE;

        bool baronDefense = district.baronDefenseId != 0;

        return gangWarWonProbFn(attackForce, defenseForce, baronDefense);
    }

    function isInjured(
        uint256 gangsterId,
        uint256 districtId,
        uint256 roundId
    ) public view returns (bool) {
        uint256 gRand = s().gangWarOutcomes[districtId][roundId];

        uint256 wonP = gangWarWonDistrictProb(districtId, roundId);

        bool won = gRand >> 128 < wonP;

        uint256 p = isInjuredProbFn(wonP, won);

        uint256 pRand = uint256(keccak256(abi.encode(gRand, gangsterId)));

        return pRand >> 128 < p;
    }

    /* ------------- owner ------------- */

    function setBaronItemCost(uint256 itemId, uint256 cost) external payable onlyOwner {
        s().baronItemCost[itemId] = cost;
    }

    function setBriberyFee(address token, uint256 amount) external payable onlyOwner {
        s().briberyFee[token] = amount;
    }

    function _authorizeUpgrade() internal override onlyOwner {}
}
