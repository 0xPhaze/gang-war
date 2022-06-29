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

    // /// single user adds stake twice, claims multiple times
    // function test_stake1() public {
    //     for (uint256 gang; gang < 3; gang++) {
    //         staking.setRewardRate(gang, [
    //             uint256(1 ether) / 1 days,
    //             uint256(1 ether) / 1 days,
    //             uint256(1 ether) / 1 days].toMemory()
    //         ); //prettier-ignore

    //         staking.enter(gang, 10_000);

    //         skip(25 days);

    //         staking.enter(gang, 10_000);

    //         skip(25 days);

    //         staking.claim(gang);

    //         skip(25 days);

    //         staking.claim(gang);

    //         skip(25 days);

    //         staking.exit(gang, 20_000);

    //         staking.claim(0);
    //         // staking.claim(1);
    //         // staking.claim(2);

    //         assertApproxEqAbs(rewards[0].balanceOf(tester), 100 ether, 1e8);
    //         assertApproxEqAbs(rewards[1].balanceOf(tester), 100 ether, 1e8);
    //         assertApproxEqAbs(rewards[2].balanceOf(tester), 100 ether, 1e8);

    //         rewards[0].burn(tester, rewards[0].balanceOf(tester));
    //         rewards[1].burn(tester, rewards[1].balanceOf(tester));
    //         rewards[2].burn(tester, rewards[2].balanceOf(tester));
    //     }
    // }

    // /// two users stake with different shares
    // function test_stake2() public {
    //     for (uint256 gang; gang < 3; gang++) {
    //         staking.setRewardRate(gang, [
    //             uint256(1 ether) / 1 days,
    //             uint256(1 ether) / 1 days,
    //             uint256(1 ether) / 1 days].toMemory()
    //         ); //prettier-ignore

    //         staking.enter(gang, 10_000);

    //         skip(50 days);

    //         staking.enter(gang, 20_000);

    //         vm.startPrank(alice);

    //         staking.enter(gang, 10_000);

    //         skip(50 days);

    //         staking.claim(gang);

    //         vm.stopPrank();

    //         staking.claim(gang);

    //         assertApproxEqAbs(rewards[0].balanceOf(tester), (100 ether * 7) / 8, 1e8);
    //         assertApproxEqAbs(rewards[1].balanceOf(tester), (100 ether * 7) / 8, 1e8);
    //         assertApproxEqAbs(rewards[2].balanceOf(tester), (100 ether * 7) / 8, 1e8);

    //         assertApproxEqAbs(rewards[0].balanceOf(alice), (100 ether * 1) / 8, 1e8);
    //         assertApproxEqAbs(rewards[1].balanceOf(alice), (100 ether * 1) / 8, 1e8);
    //         assertApproxEqAbs(rewards[2].balanceOf(alice), (100 ether * 1) / 8, 1e8);

    //         rewards[0].burn(tester, rewards[0].balanceOf(tester));
    //         rewards[1].burn(tester, rewards[1].balanceOf(tester));
    //         rewards[2].burn(tester, rewards[2].balanceOf(tester));

    //         rewards[0].burn(alice, rewards[0].balanceOf(alice));
    //         rewards[1].burn(alice, rewards[1].balanceOf(alice));
    //         rewards[2].burn(alice, rewards[2].balanceOf(alice));
    //     }
    // }

    // /// variable rate during stake
    // function test_stake3() public {
    //     for (uint256 gang; gang < 3; gang++) {
    //         staking.setRewardRate(gang, [0, 0, 0].toMemory());

    //         skip(50 days);

    //         staking.enter(gang, 10_000);

    //         skip(50 days);

    //         staking.setRewardRate(gang, [
    //             uint256(1 ether) / 1 days,
    //             uint256(2 ether) / 1 days,
    //             uint256(3 ether) / 1 days].toMemory()
    //         ); //prettier-ignore

    //         skip(100 days);

    //         staking.setRewardRate(gang, [
    //             uint256(2 ether) / 1 days,
    //             uint256(4 ether) / 1 days,
    //             uint256(6 ether) / 1 days].toMemory()
    //         ); //prettier-ignore

    //         skip(100 days);

    //         staking.setRewardRate(gang, [0, 0, 0].toMemory());

    //         skip(50 days);

    //         staking.claim(gang);

    //         assertApproxEqAbs(rewards[0].balanceOf(tester), 300 ether, 1e8);
    //         assertApproxEqAbs(rewards[1].balanceOf(tester), 600 ether, 1e8);
    //         assertApproxEqAbs(rewards[2].balanceOf(tester), 900 ether, 1e8);

    //         rewards[0].burn(tester, rewards[0].balanceOf(tester));
    //         rewards[1].burn(tester, rewards[1].balanceOf(tester));
    //         rewards[2].burn(tester, rewards[2].balanceOf(tester));
    //     }
    // }

    /// non-equal rate is changed during stake
    function test_stake3() public {
        uint256 gang = 0;

        staking.setRewardRate(gang, [0, 0, 0].toMemory());

        skip(50 days);

        staking.enter(gang, 10_000);

        skip(50 days);

        staking.setRewardRate(gang, [
                uint256(1 ether) / 1 days,
                uint256(2 ether) / 1 days,
                uint256(3 ether) / 1 days].toMemory()
            ); //prettier-ignore

        skip(100 days);

        staking.exit(gang, 10_000);

        staking.claim(gang);

        // // skip(100 days);

        // staking.setRewardRate(gang, [
        //         uint256(2 ether) / 1 days,
        //         uint256(4 ether) / 1 days,
        //         uint256(6 ether) / 1 days].toMemory()
        //     ); //prettier-ignore

        // skip(100 days);

        // staking.setRewardRate(gang, [0, 0, 0].toMemory());

        // skip(50 days);

        // staking.claim(gang);

        assertApproxEqAbs(rewards[0].balanceOf(tester), 100 ether, 1e8);
        assertApproxEqAbs(rewards[1].balanceOf(tester), 200 ether, 1e8);
        assertApproxEqAbs(rewards[2].balanceOf(tester), 300 ether, 1e8);

        // assertApproxEqAbs(rewards[0].balanceOf(tester), 300 ether, 1e8);
        // assertApproxEqAbs(rewards[1].balanceOf(tester), 600 ether, 1e8);
        // assertApproxEqAbs(rewards[2].balanceOf(tester), 900 ether, 1e8);

        // rewards[0].burn(tester, rewards[0].balanceOf(tester));
        // rewards[1].burn(tester, rewards[1].balanceOf(tester));
        // rewards[2].burn(tester, rewards[2].balanceOf(tester));
    }
}
