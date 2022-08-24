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
import "./Base.t.sol";

contract TestGangWarReward is TestGangWar {
    using futils for *;

    function setUp() public virtual override {
        // super.setUp();
        __DEPLOY_SCRIPTS_BYPASS = true;

        setUpContractsTEST();
        initContractsTEST();

        tokens[0].grantBurnAuthority(tester);
        tokens[1].grantBurnAuthority(tester);
        tokens[2].grantBurnAuthority(tester);

        game.scrambleStorage();
    }

    function test_setUp() public override {
        assertEq(DIAMOND_STORAGE_GANG_WAR_REWARD, keccak256("diamond.storage.gang.war.reward"));
    }

    function test_transferYield() public {
        game.setYield(0, [uint256(100_000_000), uint256(100_000_000), uint256(100_000_000)].toMemory()); //prettier-ignore
        game.setYield(1, [uint256(100_000_000), uint256(100_000_000), uint256(100_000_000)].toMemory()); //prettier-ignore
        game.setYield(2, [uint256(100_000_000), uint256(100_000_000), uint256(100_000_000)].toMemory()); //prettier-ignore

        uint256[3][3] memory yields1 = game.getYield();

        assertEq(yields1[0][0], 100_000_000);
        assertEq(yields1[0][1], 100_000_000);
        assertEq(yields1[0][2], 100_000_000);

        assertEq(yields1[1][0], 100_000_000);
        assertEq(yields1[1][1], 100_000_000);
        assertEq(yields1[1][2], 100_000_000);

        assertEq(yields1[2][0], 100_000_000);
        assertEq(yields1[2][1], 100_000_000);
        assertEq(yields1[2][2], 100_000_000);

        game.transferYield(0, 1, 1, 500_000);

        uint256[3][3] memory yields2 = game.getYield();

        assertEq(yields2[0][1], 100_000_000 - 500_000);
        assertEq(yields2[1][1], 100_000_000 + 500_000);
    }

    /// test limits to overflow
    function test_rangeLimit() public {
        game.setYield(0, [uint256(1e12 * 1), uint256(1e12 * 1), uint256(1e12 * 1)].toMemory()); //prettier-ignore

        game.addShares(0, 1);

        skip(10_000 days);

        game.removeShares(0, 1);

        skip(10_000 days);

        // console.log("atests", game.getClaimableUserBalance(tester)[0]);

        for (uint256 token; token < 3; token++) {
            vm.prank(address(0));
            assertApproxEqAbs(game.getClaimableUserBalance(tester)[token], (10_000 * 1e12 * 1 ether * 80) / 100, 1e1);
        }

        game.claimUserBalance();

        for (uint256 token; token < 3; token++) {
            assertApproxEqAbs(tokens[0].balanceOf(tester), (10_000 * 1e12 * 1 ether * 80) / 100, 1e1);
        }
    }

    /// test limits to rounding errors
    function test_roundingErrors() public {
        // errors get relatively worse with lower rate (1e6 = approx yield of 1/10 district)
        game.setYield(0, [uint256(1e6), uint256(1e6), uint256(1e6)].toMemory()); //prettier-ignore

        game.addShares(0, 10_000);

        vm.prank(alice);
        game.addShares(0, 1);

        skip(10 hours);

        game.claimUserBalance();

        vm.prank(alice);
        game.claimUserBalance();

        assertApproxEqAbs(
            tokens[0].balanceOf(tester),
            uint256(10_000 * 1e6 * 1 ether * 10 hours * 80) / (10_001 * 1 days * 100),
            0.0001 ether
        );

        assertApproxEqAbs(
            tokens[0].balanceOf(alice),
            uint256(1e6 * 1 ether * 10 hours * 80) / (10_001 * 1 days * 100),
            0.0000001 ether
        );
    }

    /// single user adds stake twice, claims multiple times
    function test_stake1() public {
        for (uint256 gang; gang < 3; gang++) {
            game.setYield(gang, [uint256(1), uint256(1), uint256(1)].toMemory()); //prettier-ignore

            // stake for 100 days
            game.addShares(gang, 10_000);

            skip(25 days);

            game.addShares(gang, 10_000); // additional shares don't matter for single staker

            skip(25 days);

            game.claimUserBalance();

            skip(25 days);

            game.claimUserBalance();

            skip(25 days);

            game.removeShares(gang, 20_000);

            skip(100 days); // this time won't count, since there are no shares for user

            game.claimUserBalance();

            assertApproxEqAbs(tokens[0].balanceOf(tester), (100 ether * (gang + 1) * 80) / 100, 1e1);
            assertApproxEqAbs(tokens[1].balanceOf(tester), (100 ether * (gang + 1) * 80) / 100, 1e1);
            assertApproxEqAbs(tokens[2].balanceOf(tester), (100 ether * (gang + 1) * 80) / 100, 1e1);

            // tokens[0].burnFrom(tester, tokens[0].balanceOf(tester));
            // tokens[1].burnFrom(tester, tokens[1].balanceOf(tester));
            // tokens[2].burnFrom(tester, tokens[2].balanceOf(tester));
        }
    }

    /// two users stake with different shares
    function test_stake2() public {
        for (uint256 gang; gang < 3; gang++) {
            game.setYield(gang, [uint256(1), uint256(1), uint256(1)].toMemory()); //prettier-ignore

            game.addShares(gang, 10_000);

            skip(50 days);

            game.addShares(gang, 20_000);

            vm.startPrank(alice);

            game.addShares(gang, 10_000);

            skip(25 days);

            game.claimUserBalance();

            skip(25 days);

            game.removeShares(gang, 10_000);

            game.claimUserBalance();

            vm.stopPrank();

            game.removeShares(gang, 30_000);

            game.claimUserBalance();

            assertApproxEqAbs(tokens[0].balanceOf(tester), (((100 ether * 7) / 8) * 80) / 100, 1e1);
            assertApproxEqAbs(tokens[1].balanceOf(tester), (((100 ether * 7) / 8) * 80) / 100, 1e1);
            assertApproxEqAbs(tokens[2].balanceOf(tester), (((100 ether * 7) / 8) * 80) / 100, 1e1);

            assertApproxEqAbs(tokens[0].balanceOf(alice), (((100 ether * 1) / 8) * 80) / 100, 1e1);
            assertApproxEqAbs(tokens[1].balanceOf(alice), (((100 ether * 1) / 8) * 80) / 100, 1e1);
            assertApproxEqAbs(tokens[2].balanceOf(alice), (((100 ether * 1) / 8) * 80) / 100, 1e1);

            tokens[0].burnFrom(tester, tokens[0].balanceOf(tester));
            tokens[1].burnFrom(tester, tokens[1].balanceOf(tester));
            tokens[2].burnFrom(tester, tokens[2].balanceOf(tester));

            tokens[0].burnFrom(alice, tokens[0].balanceOf(alice));
            tokens[1].burnFrom(alice, tokens[1].balanceOf(alice));
            tokens[2].burnFrom(alice, tokens[2].balanceOf(alice));
        }
    }

    /// variable rate during stake
    function test_stake3() public {
        for (uint256 gang; gang < 3; gang++) {
            game.setYield(gang, [0, 0, 0].toMemory());

            skip(50 days);

            game.addShares(gang, 10_000);

            skip(50 days);

            game.setYield(gang, [uint256(1), uint256(2), uint256(3)].toMemory()); //prettier-ignore

            skip(100 days);

            game.setYield(gang, [uint256(2), uint256(4), uint256(6)].toMemory()); //prettier-ignore

            skip(100 days);

            game.setYield(gang, [0, 0, 0].toMemory());

            skip(50 days);

            game.claimUserBalance();

            assertApproxEqAbs(tokens[0].balanceOf(tester), (300 ether * (gang + 1) * 80) / 100, 1e1);
            assertApproxEqAbs(tokens[1].balanceOf(tester), (600 ether * (gang + 1) * 80) / 100, 1e1);
            assertApproxEqAbs(tokens[2].balanceOf(tester), (900 ether * (gang + 1) * 80) / 100, 1e1);
        }
    }

    /// gang vault fees
    function test_stake4() public {
        for (uint256 gang; gang < 3; gang++) {
            game.setYield(gang, [uint256(1), uint256(1), uint256(1)].toMemory()); //prettier-ignore

            game.addShares(gang, 1);

            skip(100 days);

            game.claimUserBalance();

            assertApproxEqAbs(tokens[0].balanceOf(tester), 80 ether * (gang + 1), 1e1);
            assertApproxEqAbs(tokens[1].balanceOf(tester), 80 ether * (gang + 1), 1e1);
            assertApproxEqAbs(tokens[2].balanceOf(tester), 80 ether * (gang + 1), 1e1);

            vm.prank(address(0));
            uint256[3] memory balances = game.getGangVaultBalance(gang);

            assertApproxEqAbs(balances[0], 20 ether, 1e1);
            assertApproxEqAbs(balances[1], 20 ether, 1e1);
            assertApproxEqAbs(balances[2], 20 ether, 1e1);

            game.spendGangVaultBalance(gang, 4 ether, 3 ether, 20 ether);

            vm.prank(address(0));
            balances = game.getGangVaultBalance(gang);

            assertApproxEqAbs(balances[0], 16 ether, 1e1);
            assertApproxEqAbs(balances[1], 17 ether, 1e1);
            assertApproxEqAbs(balances[2], 0 ether, 1e1);

            game.spendGangVaultBalance(gang, 4 ether, 5 ether, 0 ether);

            vm.prank(address(0));
            balances = game.getGangVaultBalance(gang);

            assertApproxEqAbs(balances[0], 12 ether, 1e1);
            assertApproxEqAbs(balances[1], 12 ether, 1e1);
            assertApproxEqAbs(balances[2], 0 ether, 1e1);

            tokens[0].burnFrom(tester, tokens[0].balanceOf(tester));
            tokens[1].burnFrom(tester, tokens[1].balanceOf(tester));
            tokens[2].burnFrom(tester, tokens[2].balanceOf(tester));
        }
    }
}
