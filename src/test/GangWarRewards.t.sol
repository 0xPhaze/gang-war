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
    MockERC20 token;
    MockERC20 rewards;

    function setUp() public {
        token = new MockERC20("Token", "", 18);
        rewards = new MockERC20("Token", "", 18);
        staking = new StakingRewards(address(rewards), address(token));
    }

    function assertEq(Gang a, Gang b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(PLAYER_STATE a, PLAYER_STATE b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(DISTRICT_STATE a, DISTRICT_STATE b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(uint256[] memory a, uint256[] memory b) internal {
        assertEq(a.length, b.length);
        for (uint256 i; i < a.length; ++i) assertEq(a[i], b[i]);
    }

    /// single user gets full stake
    function test_stake() public {
        staking.setRewardRate(uint256(1 ether) / 1 days);

        token.mint(tester, 1 ether);

        token.approve(address(staking), type(uint256).max);
        staking.stake(1 ether);

        skip(66 days);

        staking.claimReward();

        assertApproxEqAbs(rewards.balanceOf(tester), 66 ether, 1e10);
    }

    /// single user adds stake twice
    function test_stake2() public {
        staking.setRewardRate(1 ether);

        token.mint(tester, 2 ether);

        token.approve(address(staking), type(uint256).max);
        staking.stake(1 ether);

        skip(25);

        staking.stake(1 ether);

        skip(25);

        staking.claimReward();

        assertEq(rewards.balanceOf(tester), 50 ether);
    }

    /// two users stake with different shares
    function test_stake3() public {
        staking.setRewardRate(1 ether);

        token.mint(tester, 3 ether);
        token.approve(address(staking), type(uint256).max);

        staking.stake(1 ether);

        skip(50);

        staking.stake(2 ether);

        vm.startPrank(alice);

        token.mint(alice, 1 ether);
        token.approve(address(staking), type(uint256).max);
        staking.stake(1 ether);

        skip(50);

        staking.claimReward();

        vm.stopPrank();

        staking.claimReward();

        assertEq(rewards.balanceOf(tester), (100 ether * 7) / 8);
        assertEq(rewards.balanceOf(alice), (100 ether * 1) / 8);
    }

    /// stake is turned on/off
    function test_stake4() public {
        staking.setRewardRate(0 ether);

        token.mint(tester, 10 ether);
        token.approve(address(staking), type(uint256).max);

        staking.stake(1 ether);

        skip(50);

        staking.claimReward();

        assertEq(rewards.balanceOf(tester), 0);

        staking.setRewardRate(1 ether);

        skip(100);

        staking.setRewardRate(0 ether);

        skip(50);

        staking.claimReward();

        assertEq(rewards.balanceOf(tester), 100 ether);
    }
}
