// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeV} from "UDS/proxy/UUPSUpgradeV.sol";
import {OwnableUDS} from "UDS/OwnableUDS.sol";

import {IERC721} from "./interfaces/IERC721.sol";

// import {GangWarBase} from "./GangWarBase.sol";
// import {GMCMarket} from "./GMCMarket.sol";
// import {ds, settings, District, Gangster} from
import "./GangWarStorage.sol";
import "./GangWarRewards.sol";
// import {GangWarGameLogic} from "./GangWarGameLogic.sol";
import "./GangWarGameLogic.sol";

/* ============= Error ============= */

contract GangWar is UUPSUpgradeV(1), OwnableUDS, GangWarBase, GangWarGameLogic, GangWarRewards {
    constructor(
        address coordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit
    ) VRFConsumerV2(coordinator, keyHash, subscriptionId, requestConfirmations, callbackGasLimit) {}

    function init(
        address gmc,
        Gang[] calldata initialDistrictOccupants,
        uint256[] calldata initialDistrictYields
    ) external initializer {
        __Ownable_init();
        __GangWarBase_init(gmc);

        constants().TIME_GANG_WAR = 100;
        constants().TIME_LOCKUP = 100;
        constants().TIME_TRUCE = 100;
        constants().TIME_RECOVERY = 100;
        constants().TIME_REINFORCEMENTS = 100;

        constants().DEFENSE_FAVOR_LIM = 150;
        constants().BARON_DEFENSE_FORCE = 50;
        constants().ATTACK_FAVOR = 65;
        constants().DEFENSE_FAVOR = 200;

        initDistrictRoundIds();
        initDistrictOccupantsAndYield(initialDistrictOccupants, initialDistrictYields);
    }

    /* ------------- Internal ------------- */

    function multiCall(bytes[] calldata calldata_) external {
        for (uint256 i; i < calldata_.length; ++i) address(this).delegatecall(calldata_[i]);
    }

    /* ------------- Internal ------------- */

    function _afterDistrictTransfer(
        Gang attackers,
        Gang defenders,
        uint256 id
    ) internal override {}

    function _authorizeUpgrade() internal override onlyOwner {}
}
