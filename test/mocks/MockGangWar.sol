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

    function addShares(uint256 gang, uint40 amount) public {
        _addShares(msg.sender, gang, amount);
    }

    function removeShares(uint256 gang, uint40 amount) public {
        _removeShares(msg.sender, gang, amount);
    }

    function spendGangVaultBalance(
        uint256 gang,
        uint256 amount_0,
        uint256 amount_1,
        uint256 amount_2
    ) public {
        _spendGangVaultBalance(gang, amount_0, amount_1, amount_2, true);
    }

    function claimUserBalance() public {
        _claimUserBalance(msg.sender);
    }

    function transferYield(
        uint256 gangFrom,
        uint256 gangTo,
        uint256 token,
        uint256 yield
    ) public {
        _transferYield(gangFrom, gangTo, token, yield);
    }

    function scrambleStorage() public {
        utils.scrambleStorage(0, 100);
    }
}
