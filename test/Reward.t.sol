// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import {MockVRFCoordinator} from "./mocks/MockVRFCoordinator.sol";

import "futils/futils.sol";
import "/GangWar.sol";

import {GangWarReward, DIAMOND_STORAGE_GANG_WAR_REWARD} from "/GangWarReward.sol";

contract MockGangReward is GangWarReward {
    constructor(uint256 gangFee, address[3] memory gangTokens) GangWarReward(gangFee) {
        _setGangTokens(gangTokens);
    }

    function enter(uint256 gang, uint40 amount) public {
        _addShares(msg.sender, gang, amount);
    }

    function exit(uint256 gang, uint40 amount) public {
        _removeShares(msg.sender, gang, amount);
    }

    function claim() public {
        _claimUserBalance(msg.sender);
    }

    function spendGangVaultBalance(
        uint256 gang,
        uint256 amount_0,
        uint256 amount_1,
        uint256 amount_2
    ) public {
        _spendGangVaultBalance(gang, amount_0, amount_1, amount_2, true);
    }

    function setYield(uint256 gang, uint256[] calldata rates) external {
        _setYield(gang, 0, rates[0]);
        _setYield(gang, 1, rates[1]);
        _setYield(gang, 2, rates[2]);
    }

    function transferYield(
        uint256 gangFrom,
        uint256 gangTo,
        uint256 token,
        uint256 yield
    ) public {
        _transferYield(gangFrom, gangTo, token, yield);
    }
}

contract TestGangWarReward is Test {
    using futils for *;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    // MockVRFCoordinator coordinator = new MockVRFCoordinator();
    // GangWar impl = new GangWar(address(coordinator), 0, 0, 0, 0);
    // GangWar game;
    // MockERC721 gmc;

    MockGangReward staking;
    mapping(uint256 => MockERC20) reward;

    function _setUp(uint256 gangFee) internal {
        reward[0] = new MockERC20("Token", "", 18);
        reward[1] = new MockERC20("Token", "", 18);
        reward[2] = new MockERC20("Token", "", 18);

        address[3] memory rewardAddress;
        rewardAddress[0] = address(reward[0]);
        rewardAddress[1] = address(reward[1]);
        rewardAddress[2] = address(reward[2]);

        staking = new MockGangReward(gangFee, rewardAddress);
    }

    function test_setUp() public {
        assertEq(DIAMOND_STORAGE_GANG_WAR_REWARD, keccak256("diamond.storage.gang.war.reward"));
    }

    function test_transferYield() public {
        _setUp(20);

        staking.setYield(0, [uint256(100_000_000), uint256(100_000_000), uint256(100_000_000)].toMemory()); //prettier-ignore
        staking.setYield(1, [uint256(100_000_000), uint256(100_000_000), uint256(100_000_000)].toMemory()); //prettier-ignore
        staking.setYield(2, [uint256(100_000_000), uint256(100_000_000), uint256(100_000_000)].toMemory()); //prettier-ignore

        uint256[3][3] memory yields1 = staking.getYield();

        assertEq(yields1[0][0], 100_000_000);
        assertEq(yields1[0][1], 100_000_000);
        assertEq(yields1[0][2], 100_000_000);

        assertEq(yields1[1][0], 100_000_000);
        assertEq(yields1[1][1], 100_000_000);
        assertEq(yields1[1][2], 100_000_000);

        assertEq(yields1[2][0], 100_000_000);
        assertEq(yields1[2][1], 100_000_000);
        assertEq(yields1[2][2], 100_000_000);

        staking.transferYield(0, 1, 1, 500_000);

        uint256[3][3] memory yields2 = staking.getYield();

        assertEq(yields2[0][1], 100_000_000 - 500_000);
        assertEq(yields2[1][1], 100_000_000 + 500_000);
    }

    /// test limits to overflow
    function test_rangeLimit() public {
        _setUp(20);

        staking.setYield(0, [uint256(1e12 * 1), uint256(1e12 * 1), uint256(1e12 * 1)].toMemory()); //prettier-ignore

        staking.enter(0, 1);

        skip(10_000 days);

        staking.exit(0, 1);

        skip(10_000 days);

        // console.log("atests", staking.getClaimableUserBalance(tester)[0]);

        for (uint256 token; token < 3; token++) {
            vm.prank(address(0));
            assertApproxEqAbs(
                staking.getClaimableUserBalance(tester)[token],
                (10_000 * 1e12 * 1 ether * 80) / 100,
                1e1
            );
        }

        staking.claim();

        for (uint256 token; token < 3; token++) {
            assertApproxEqAbs(reward[0].balanceOf(tester), (10_000 * 1e12 * 1 ether * 80) / 100, 1e1);
        }
    }

    /// test limits to rounding errors
    function test_roundingErrors() public {
        _setUp(20);

        // errors get relatively worse with lower rate (1e6 = approx yield of 1/10 district)
        staking.setYield(0, [uint256(1e6), uint256(1e6), uint256(1e6)].toMemory()); //prettier-ignore

        staking.enter(0, 10_000);

        vm.prank(alice);
        staking.enter(0, 1);

        skip(10 hours);

        staking.claim();

        vm.prank(alice);
        staking.claim();

        assertApproxEqAbs(
            reward[0].balanceOf(tester),
            uint256(10_000 * 1e6 * 1 ether * 10 hours * 80) / (10_001 * 1 days * 100),
            0.0001 ether
        );

        assertApproxEqAbs(
            reward[0].balanceOf(alice),
            uint256(1e6 * 1 ether * 10 hours * 80) / (10_001 * 1 days * 100),
            0.0000001 ether
        );
    }

    /// single user adds stake twice, claims multiple times
    function test_stake1() public {
        _setUp(20);

        for (uint256 gang; gang < 3; gang++) {
            staking.setYield(gang, [uint256(1), uint256(1), uint256(1)].toMemory()); //prettier-ignore

            // stake for 100 days
            staking.enter(gang, 10_000);

            skip(25 days);

            staking.enter(gang, 10_000); // additional shares don't matter for single staker

            skip(25 days);

            staking.claim();

            skip(25 days);

            staking.claim();

            skip(25 days);

            staking.exit(gang, 20_000);

            skip(100 days); // this time won't count, since there are no shares for user

            staking.claim();

            assertApproxEqAbs(reward[0].balanceOf(tester), (100 ether * (gang + 1) * 80) / 100, 1e1);
            assertApproxEqAbs(reward[1].balanceOf(tester), (100 ether * (gang + 1) * 80) / 100, 1e1);
            assertApproxEqAbs(reward[2].balanceOf(tester), (100 ether * (gang + 1) * 80) / 100, 1e1);

            // reward[0].burn(tester, reward[0].balanceOf(tester));
            // reward[1].burn(tester, reward[1].balanceOf(tester));
            // reward[2].burn(tester, reward[2].balanceOf(tester));
        }
    }

    /// two users stake with different shares
    function test_stake2() public {
        _setUp(20);

        for (uint256 gang; gang < 3; gang++) {
            staking.setYield(gang, [uint256(1), uint256(1), uint256(1)].toMemory()); //prettier-ignore

            staking.enter(gang, 10_000);

            skip(50 days);

            staking.enter(gang, 20_000);

            vm.startPrank(alice);

            staking.enter(gang, 10_000);

            skip(25 days);

            staking.claim();

            skip(25 days);

            staking.exit(gang, 10_000);

            staking.claim();

            vm.stopPrank();

            staking.exit(gang, 30_000);

            staking.claim();

            assertApproxEqAbs(reward[0].balanceOf(tester), (((100 ether * 7) / 8) * 80) / 100, 1e1);
            assertApproxEqAbs(reward[1].balanceOf(tester), (((100 ether * 7) / 8) * 80) / 100, 1e1);
            assertApproxEqAbs(reward[2].balanceOf(tester), (((100 ether * 7) / 8) * 80) / 100, 1e1);

            assertApproxEqAbs(reward[0].balanceOf(alice), (((100 ether * 1) / 8) * 80) / 100, 1e1);
            assertApproxEqAbs(reward[1].balanceOf(alice), (((100 ether * 1) / 8) * 80) / 100, 1e1);
            assertApproxEqAbs(reward[2].balanceOf(alice), (((100 ether * 1) / 8) * 80) / 100, 1e1);

            reward[0].burn(tester, reward[0].balanceOf(tester));
            reward[1].burn(tester, reward[1].balanceOf(tester));
            reward[2].burn(tester, reward[2].balanceOf(tester));

            reward[0].burn(alice, reward[0].balanceOf(alice));
            reward[1].burn(alice, reward[1].balanceOf(alice));
            reward[2].burn(alice, reward[2].balanceOf(alice));
        }
    }

    /// variable rate during stake
    function test_stake3() public {
        _setUp(20);

        for (uint256 gang; gang < 3; gang++) {
            staking.setYield(gang, [0, 0, 0].toMemory());

            skip(50 days);

            staking.enter(gang, 10_000);

            skip(50 days);

            staking.setYield(gang, [uint256(1), uint256(2), uint256(3)].toMemory()); //prettier-ignore

            skip(100 days);

            staking.setYield(gang, [uint256(2), uint256(4), uint256(6)].toMemory()); //prettier-ignore

            skip(100 days);

            staking.setYield(gang, [0, 0, 0].toMemory());

            skip(50 days);

            staking.claim();

            assertApproxEqAbs(reward[0].balanceOf(tester), (300 ether * (gang + 1) * 80) / 100, 1e1);
            assertApproxEqAbs(reward[1].balanceOf(tester), (600 ether * (gang + 1) * 80) / 100, 1e1);
            assertApproxEqAbs(reward[2].balanceOf(tester), (900 ether * (gang + 1) * 80) / 100, 1e1);
        }
    }

    /// gang vault fees
    function test_stake4() public {
        _setUp(20);

        for (uint256 gang; gang < 3; gang++) {
            staking.setYield(gang, [uint256(1), uint256(1), uint256(1)].toMemory()); //prettier-ignore

            staking.enter(gang, 1);

            skip(100 days);

            staking.claim();

            assertApproxEqAbs(reward[0].balanceOf(tester), 80 ether * (gang + 1), 1e1);
            assertApproxEqAbs(reward[1].balanceOf(tester), 80 ether * (gang + 1), 1e1);
            assertApproxEqAbs(reward[2].balanceOf(tester), 80 ether * (gang + 1), 1e1);

            vm.prank(address(0));
            uint256[3] memory balances = staking.getGangVaultBalance(gang);

            assertApproxEqAbs(balances[0], 20 ether, 1e1);
            assertApproxEqAbs(balances[1], 20 ether, 1e1);
            assertApproxEqAbs(balances[2], 20 ether, 1e1);

            staking.spendGangVaultBalance(gang, 4 ether, 3 ether, 20 ether);

            vm.prank(address(0));
            balances = staking.getGangVaultBalance(gang);

            assertApproxEqAbs(balances[0], 16 ether, 1e1);
            assertApproxEqAbs(balances[1], 17 ether, 1e1);
            assertApproxEqAbs(balances[2], 0 ether, 1e1);

            staking.spendGangVaultBalance(gang, 4 ether, 5 ether, 0 ether);

            vm.prank(address(0));
            balances = staking.getGangVaultBalance(gang);

            assertApproxEqAbs(balances[0], 12 ether, 1e1);
            assertApproxEqAbs(balances[1], 12 ether, 1e1);
            assertApproxEqAbs(balances[2], 0 ether, 1e1);

            reward[0].burn(tester, reward[0].balanceOf(tester));
            reward[1].burn(tester, reward[1].balanceOf(tester));
            reward[2].burn(tester, reward[2].balanceOf(tester));
        }
    }
}
