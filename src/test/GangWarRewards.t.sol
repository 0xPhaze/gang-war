// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967VersionedUDS.sol";

import {MockVRFCoordinatorV2} from "./mocks/MockVRFCoordinator.sol";

import "../lib/ArrayUtils.sol";
import "../GangWar.sol";

import {StakingRewards} from "../StakingRewards.sol";

// contract MockGangWar is GangWar {
//     constructor(
//         address coordinator,
//         bytes32 keyHash,
//         uint64 subscriptionId,
//         uint16 requestConfirmations,
//         uint32 callbackGasLimit
//     ) GangWar(coordinator, keyHash, subscriptionId, requestConfirmations, callbackGasLimit) {}
// }

contract TestGangWarRewards is Test {
    using ArrayUtils for *;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    // MockVRFCoordinatorV2 coordinator = new MockVRFCoordinatorV2();
    // GangWar impl = new GangWar(address(coordinator), 0, 0, 0, 0);
    // GangWar game;
    // MockERC721 gmc;

    StakingRewards staking;
    mapping(uint256 => MockERC20) rewards;

    function setUp() public {
        rewards[0] = new MockERC20("Token", "", 18);
        rewards[1] = new MockERC20("Token", "", 18);
        rewards[2] = new MockERC20("Token", "", 18);

        address[] memory rewardsAddress = new address[](3);
        rewardsAddress[0] = address(rewards[0]);
        rewardsAddress[1] = address(rewards[1]);
        rewardsAddress[2] = address(rewards[2]);
        staking = new StakingRewards(rewardsAddress);
    }

    /// single user adds stake twice, claims multiple times
    function test_stake1() public {
        staking.setRewardRate([
            uint256(1 ether) / 1 days, 
            uint256(1 ether) / 1 days, 
            uint256(1 ether) / 1 days].toMemory()
        ); //prettier-ignore

        staking.enter(10_000);

        skip(25 days);

        staking.enter(10_000);

        skip(25 days);

        staking.claim();

        skip(25 days);

        staking.claim();

        skip(25 days);

        staking.claim();

        assertApproxEqAbs(rewards[0].balanceOf(tester), 100 ether, 1e8);
        assertApproxEqAbs(rewards[1].balanceOf(tester), 100 ether, 1e8);
        assertApproxEqAbs(rewards[2].balanceOf(tester), 100 ether, 1e8);
    }

    /// two users stake with different shares
    function test_stake2() public {
        staking.setRewardRate([
            uint256(1 ether) / 1 days, 
            uint256(1 ether) / 1 days, 
            uint256(1 ether) / 1 days].toMemory()
        ); //prettier-ignore

        staking.enter(10_000);

        skip(50 days);

        staking.enter(20_000);

        vm.startPrank(alice);

        staking.enter(10_000);

        skip(50 days);

        staking.claim();

        vm.stopPrank();

        staking.claim();

        assertApproxEqAbs(rewards[0].balanceOf(tester), (100 ether * 7) / 8, 1e8);
        assertApproxEqAbs(rewards[1].balanceOf(tester), (100 ether * 7) / 8, 1e8);
        assertApproxEqAbs(rewards[2].balanceOf(tester), (100 ether * 7) / 8, 1e8);

        assertApproxEqAbs(rewards[0].balanceOf(alice), (100 ether * 1) / 8, 1e8);
        assertApproxEqAbs(rewards[1].balanceOf(alice), (100 ether * 1) / 8, 1e8);
        assertApproxEqAbs(rewards[2].balanceOf(alice), (100 ether * 1) / 8, 1e8);
    }

    /// non-equal rate is changed during stake
    function test_stake3() public {
        staking.setRewardRate([0, 0, 0].toMemory());

        skip(50 days);

        staking.enter(10_000);

        skip(50 days);

        staking.setRewardRate([
            uint256(1 ether) / 1 days, 
            uint256(2 ether) / 1 days, 
            uint256(3 ether) / 1 days].toMemory()
        ); //prettier-ignore

        skip(100 days);

        staking.setRewardRate([
            uint256(2 ether) / 1 days, 
            uint256(4 ether) / 1 days, 
            uint256(6 ether) / 1 days].toMemory()
        ); //prettier-ignore

        skip(100 days);

        staking.setRewardRate([0, 0, 0].toMemory());

        skip(50 days);

        staking.claim();

        assertApproxEqAbs(rewards[0].balanceOf(tester), 300 ether, 1e8);
        assertApproxEqAbs(rewards[1].balanceOf(tester), 600 ether, 1e8);
        assertApproxEqAbs(rewards[2].balanceOf(tester), 900 ether, 1e8);
    }
}
