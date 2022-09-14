// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import {MockVRFCoordinator} from "./mocks/MockVRFCoordinator.sol";

import "futils/futils.sol";
import "/GangWar.sol";

import "./Base.t.sol";
import {GangVault, DIAMOND_STORAGE_GANG_VAULT, DIAMOND_STORAGE_GANG_VAULT_FX} from "/GangVault.sol";

contract TestGangVault is TestGangWar {
    using futils for *;

    function setUp() public virtual override {
        setUpContracts();

        tokens[0].grantRole(AUTHORITY, tester);
        tokens[1].grantRole(AUTHORITY, tester);
        tokens[2].grantRole(AUTHORITY, tester);

        vault.grantRole(GANG_VAULT_CONTROLLER, address(this));

        vault.setYield(0, [uint256(0), uint256(0), uint256(0)]); //prettier-ignore
        vault.setYield(1, [uint256(0), uint256(0), uint256(0)]); //prettier-ignore
        vault.setYield(2, [uint256(0), uint256(0), uint256(0)]); //prettier-ignore

        // @note add vault scramble
        // vault.scrambleStorage();
    }

    function test_setUp() public override {
        assertEq(DIAMOND_STORAGE_GANG_VAULT, keccak256("diamond.storage.gang.vault"));
        assertEq(DIAMOND_STORAGE_GANG_VAULT_FX, keccak256("diamond.storage.gang.vault.season1"));
    }

    function test_transferYield() public {
        vault.setYield(0, [uint256(100_000_000), uint256(100_000_000), uint256(100_000_000)]); //prettier-ignore
        vault.setYield(1, [uint256(100_000_000), uint256(100_000_000), uint256(100_000_000)]); //prettier-ignore
        vault.setYield(2, [uint256(100_000_000), uint256(100_000_000), uint256(100_000_000)]); //prettier-ignore

        uint256[3][3] memory yields1 = vault.getYield();

        assertEq(yields1[0][0], 100_000_000);
        assertEq(yields1[0][1], 100_000_000);
        assertEq(yields1[0][2], 100_000_000);

        assertEq(yields1[1][0], 100_000_000);
        assertEq(yields1[1][1], 100_000_000);
        assertEq(yields1[1][2], 100_000_000);

        assertEq(yields1[2][0], 100_000_000);
        assertEq(yields1[2][1], 100_000_000);
        assertEq(yields1[2][2], 100_000_000);

        vault.transferYield(0, 1, 1, 500_000);

        uint256[3][3] memory yields2 = vault.getYield();

        assertEq(yields2[0][1], 100_000_000 - 500_000);
        assertEq(yields2[1][1], 100_000_000 + 500_000);
    }

    /// test limits to overflow
    function test_rangeLimit() public {
        vault.setYield(0, [uint256(1e12 * 1), uint256(1e12 * 1), uint256(1e12 * 1)]); //prettier-ignore

        vault.addShares(tester, 0, 1);

        skip(10_000 days);

        vault.removeShares(tester, 0, 1);

        skip(10_000 days);

        for (uint256 token; token < 3; token++) {
            vm.prank(address(0));
            assertApproxEqAbs(vault.getClaimableUserBalance(tester)[token], (10_000 * 1e12 * 1 ether * 80) / 100, 1e1);
        }

        vault.claimUserBalance();

        for (uint256 token; token < 3; token++) {
            assertApproxEqAbs(tokens[0].balanceOf(tester), (10_000 * 1e12 * 1 ether * 80) / 100, 1e1);
        }
    }

    /// test limits to rounding errors
    function test_roundingErrors() public {
        // errors get relatively worse with lower rate (1e6 = approx yield of 1/10 district)
        vault.setYield(0, [uint256(1e6), uint256(1e6), uint256(1e6)]); //prettier-ignore

        vault.addShares(tester, 0, 10_000);

        vault.addShares(alice, 0, 1);

        skip(10 hours);

        vault.claimUserBalance();

        vm.prank(alice);
        vault.claimUserBalance();

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
            // uint256 gang = 0;

            vault.setYield(gang, [uint256(1), uint256(1), uint256(1)]); //prettier-ignore

            // stake for 100 days
            vault.addShares(tester, gang, 10_000);

            skip(25 days);

            vault.addShares(tester, gang, 10_000); // additional shares don't matter for single staker

            skip(25 days);

            vault.claimUserBalance();

            skip(25 days);

            vault.claimUserBalance();

            skip(25 days);

            vault.removeShares(tester, gang, 20_000);

            skip(100 days); // this time won't count, since there are no shares for user

            vault.claimUserBalance();

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
            vault.setYield(gang, [uint256(1), uint256(1), uint256(1)]); //prettier-ignore

            vault.addShares(tester, gang, 10_000);

            skip(50 days);

            vault.addShares(tester, gang, 20_000);

            vault.addShares(alice, gang, 10_000);

            skip(25 days);

            vm.prank(alice);
            vault.claimUserBalance();

            skip(25 days);

            vault.removeShares(alice, gang, 10_000);

            vm.prank(alice);
            vault.claimUserBalance();

            vault.removeShares(tester, gang, 30_000);

            vault.claimUserBalance();

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
            vault.setYield(gang, [uint256(0), uint256(0), uint256(0)]);

            skip(50 days);

            vault.addShares(tester, gang, 10_000);

            skip(50 days);

            vault.setYield(gang, [uint256(1), uint256(2), uint256(3)]); //prettier-ignore

            skip(100 days);

            vault.setYield(gang, [uint256(2), uint256(4), uint256(6)]); //prettier-ignore

            skip(100 days);

            vault.setYield(gang, [uint256(0), uint256(0), uint256(0)]);

            skip(50 days);

            vault.claimUserBalance();

            assertApproxEqAbs(tokens[0].balanceOf(tester), (300 ether * (gang + 1) * 80) / 100, 1e1);
            assertApproxEqAbs(tokens[1].balanceOf(tester), (600 ether * (gang + 1) * 80) / 100, 1e1);
            assertApproxEqAbs(tokens[2].balanceOf(tester), (900 ether * (gang + 1) * 80) / 100, 1e1);
        }
    }

    /// gang vault fees
    function test_stake4() public {
        assertEq(tokens[0].balanceOf(tester), 0);
        assertEq(tokens[1].balanceOf(tester), 0);
        assertEq(tokens[2].balanceOf(tester), 0);

        for (uint256 gang; gang < 3; gang++) {
            vault.setYield(gang, [uint256(1), uint256(1), uint256(1)]);

            vault.addShares(tester, gang, 1);

            uint256[3] memory balances = vault.getGangVaultBalance(gang);

            assertEq(balances[0], 0);
            assertEq(balances[1], 0);
            assertEq(balances[2], 0);

            skip(100 days);

            vault.claimUserBalance();

            assertApproxEqAbs(tokens[0].balanceOf(tester), 80 ether * (gang + 1), 1e1);
            assertApproxEqAbs(tokens[1].balanceOf(tester), 80 ether * (gang + 1), 1e1);
            assertApproxEqAbs(tokens[2].balanceOf(tester), 80 ether * (gang + 1), 1e1);

            balances = vault.getGangVaultBalance(gang);

            assertApproxEqAbs(balances[0], 20 ether, 1e1);
            assertApproxEqAbs(balances[1], 20 ether, 1e1);
            assertApproxEqAbs(balances[2], 20 ether, 1e1);

            vault.spendGangVaultBalance(gang, 4 ether, 3 ether, 20 ether, true);

            balances = vault.getGangVaultBalance(gang);

            assertApproxEqAbs(balances[0], 16 ether, 1e1);
            assertApproxEqAbs(balances[1], 17 ether, 1e1);
            assertApproxEqAbs(balances[2], 0 ether, 1e1);

            vault.spendGangVaultBalance(gang, 4 ether, 5 ether, 0 ether, true);

            balances = vault.getGangVaultBalance(gang);

            assertApproxEqAbs(balances[0], 12 ether, 1e1);
            assertApproxEqAbs(balances[1], 12 ether, 1e1);
            assertApproxEqAbs(balances[2], 0 ether, 1e1);

            tokens[0].burnFrom(tester, tokens[0].balanceOf(tester));
            tokens[1].burnFrom(tester, tokens[1].balanceOf(tester));
            tokens[2].burnFrom(tester, tokens[2].balanceOf(tester));
        }
    }
}
