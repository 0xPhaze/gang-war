// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "/GangWar.sol";
import "/GangWar.sol";
import "../utils.sol";

contract MockGangWar is GangWar {
    constructor(
        address coordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit
    ) GangWar(coordinator, keyHash, subscriptionId, requestConfirmations, callbackGasLimit) {}

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
        return s().districtConnections;
    }

    function setYield(
        uint256 gang,
        uint256 token,
        uint256 yield
    ) public {
        _setYield(gang, token, yield);
    }

    function setYield(uint256 gang, uint256[] calldata rates) external {
        _setYield(gang, 0, rates[0]);
        _setYield(gang, 1, rates[1]);
        _setYield(gang, 2, rates[2]);
    }

    function scrambleStorage() public {
        utils.scrambleStorage(0, 100);
    }
}
