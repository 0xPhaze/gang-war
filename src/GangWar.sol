// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeV} from "UDS/proxy/UUPSUpgradeV.sol";
import {OwnableUDS as Ownable} from "UDS/OwnableUDS.sol";

import {IERC721} from "./interfaces/IERC721.sol";

// import {GangWarBase} from "./GangWarBase.sol";
// import {GMCMarket} from "./GMCMarket.sol";
// import {ds, settings, District, Gangster} from
import {GangWarBase, s} from "./GangWarBase.sol";
import {GangWarRewards, s as GangWarRewardsDS} from "./GangWarRewards.sol";
// import {GangWarGameLogic} from "./GangWarGameLogic.sol";
import "./GangWarGameLogic.sol";

/* ============= Error ============= */

contract GangWar is UUPSUpgradeV(1), Ownable, GangWarBase, GangWarGameLogic, GangWarRewards {
    constructor(
        address coordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit
    ) VRFConsumerV2(coordinator, keyHash, subscriptionId, requestConfirmations, callbackGasLimit) GangWarRewards(0) {}

    function init(
        address gmc,
        address[3] memory gangTokens,
        Gang[] calldata initialDistrictGangs,
        uint256[] calldata initialDistrictYields
    ) external initializer {
        __Ownable_init();

        constants().TIME_GANG_WAR = 100;
        constants().TIME_LOCKUP = 100;
        constants().TIME_TRUCE = 100;
        constants().TIME_RECOVERY = 100;
        constants().TIME_REINFORCEMENTS = 100;

        constants().DEFENSE_FAVOR_LIM = 150;
        constants().BARON_DEFENSE_FORCE = 50;
        constants().ATTACK_FAVOR = 65;
        constants().DEFENSE_FAVOR = 200;

        s().gmc = gmc;

        District storage district;

        uint256[3] memory initialGangYields;

        for (uint256 i; i < 21; ++i) {
            district = s().districts[i];

            // initialize rounds
            district.roundId = 1;

            Gang gang = initialDistrictGangs[i];
            uint256 yield = initialDistrictYields[i];

            // initialize occupants and yield token
            district.token = gang;
            district.occupants = gang;

            // initialize district yield amount
            district.yield = yield;

            initialGangYields[uint256(gang)] += yield;
        }

        // initialize gang tokens
        _setGangTokens(gangTokens);

        // initialize yields for gangs
        _setYield(0, 0, initialGangYields[0]);
        _setYield(1, 1, initialGangYields[1]);
        _setYield(2, 2, initialGangYields[2]);
    }

    /* ------------- Internal ------------- */

    function multiCall(bytes[] calldata calldata_) external {
        for (uint256 i; i < calldata_.length; ++i) address(this).delegatecall(calldata_[i]);
    }

    /* ------------- Internal ------------- */

    function _afterDistrictTransfer(
        Gang attackers,
        Gang defenders,
        District storage district
    ) internal override {
        uint256 yield = district.yield;
        Gang token = district.token;

        _transferYield(uint256(defenders), uint256(attackers), uint256(token), yield);
    }

    function _authorizeUpgrade() internal override onlyOwner {}
}
