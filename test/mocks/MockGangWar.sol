// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "/GangWar.sol";
import "futils/futils.sol";

contract MockGangWar is GangWar {
    constructor(
        GMC gmc,
        GangVault vault,
        GangToken badges,
        uint256 connections,
        address coordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit
    )
        GangWar(
            gmc,
            vault,
            badges,
            connections,
            coordinator,
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit
        )
    {}

    function setGangWarOutcome(
        uint256 districtId,
        uint256 roundId,
        uint256 outcome
    ) public {
        s().gangWarOutcomes[districtId][roundId] = outcome;
    }

    function setAttackForce(
        uint256 districtId,
        uint256 roundId,
        uint256 force
    ) public {
        s().districtAttackForces[districtId][roundId] = force;
    }

    function setDefenseForces(
        uint256 districtId,
        uint256 roundId,
        uint256 force
    ) public {
        s().districtDefenseForces[districtId][roundId] = force;
    }

    function getDistrictConnections() external view returns (uint256) {
        return districtConnections;
    }

    function scrambleStorage() public {
        futils.scrambleStorage(0, 100);
    }
}
