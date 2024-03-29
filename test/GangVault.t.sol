// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Base.t.sol";
import "/GangWar.sol";
import {GangVault} from "/GangVault.sol";
import {MockVRFCoordinator} from "./mocks/MockVRFCoordinator.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "forge-std/Test.sol";
import "futils/futils.sol";

contract TestGangVault is TestGangWar {
    using futils for *;

    uint256 fee;
    uint256 baseShares;

    function setUp() public virtual override {
        setUpContracts();

        tokens[0].grantRole(AUTHORITY, self);
        tokens[1].grantRole(AUTHORITY, self);
        tokens[2].grantRole(AUTHORITY, self);

        vault.grantRole(GANG_VAULT_CONTROLLER, address(this));

        vault.setYield(0, [uint256(0), uint256(0), uint256(0)]); //prettier-ignore
        vault.setYield(1, [uint256(0), uint256(0), uint256(0)]); //prettier-ignore
        vault.setYield(2, [uint256(0), uint256(0), uint256(0)]); //prettier-ignore

        vault.setSeason(uint40(block.timestamp), type(uint40).max, false);

        fee = vault.gangVaultFeePercent();
        baseShares = 100 - fee;

        // @note add vault scramble
        // vault.scrambleStorage();
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

        vault.addShares(self, 0, 1);

        skip(10_000 days);

        vault.removeShares(self, 0, 1);

        skip(10_000 days);

        for (uint256 token; token < 3; token++) {
            assertApproxEqAbs(
                vault.getClaimableUserBalance(self)[token], (10_000 * 1e12 * 1 ether * baseShares) / 100, 1e1
            );
        }

        vault.claimUserBalance();

        for (uint256 token; token < 3; token++) {
            assertApproxEqAbs(tokens[0].balanceOf(self), (10_000 * 1e12 * 1 ether * baseShares) / 100, 1e1);
        }
    }

    /// test limits to rounding errors
    function test_roundingErrors() public {
        // errors get relatively worse with lower rate (1e6 = approx yield of 1/10 district)
        vault.setYield(0, [uint256(1e6), uint256(1e6), uint256(1e6)]); //prettier-ignore

        vault.addShares(self, 0, 10_000);

        vault.addShares(alice, 0, 1);

        skip(10 hours);

        vault.claimUserBalance();

        vm.prank(alice);
        vault.claimUserBalance();

        assertApproxEqAbs(
            tokens[0].balanceOf(self),
            uint256(10_000 * 1e6 * 1 ether * 10 hours * baseShares) / (10_001 * 1 days * 100),
            0.0001 ether
        );

        assertApproxEqAbs(
            tokens[0].balanceOf(alice),
            uint256(1e6 * 1 ether * 10 hours * baseShares) / (10_001 * 1 days * 100),
            0.0000001 ether
        );
    }

    /// single user adds stake twice, claims multiple times
    function test_stake1() public {
        for (uint256 gang; gang < 3; gang++) {
            // uint256 gang = 0;

            vault.setYield(gang, [uint256(1), uint256(1), uint256(1)]); //prettier-ignore

            // stake for 100 days
            vault.addShares(self, gang, 10_000);

            skip(25 days);

            vault.addShares(self, gang, 10_000); // additional shares don't matter for single staker

            skip(25 days);

            vault.claimUserBalance();

            skip(25 days);

            vault.claimUserBalance();

            skip(25 days);

            vault.removeShares(self, gang, 20_000);

            skip(100 days); // this time won't count, since there are no shares for user

            vault.claimUserBalance();

            assertApproxEqAbs(tokens[0].balanceOf(self), (100 ether * (gang + 1) * baseShares) / 100, 1e1);
            assertApproxEqAbs(tokens[1].balanceOf(self), (100 ether * (gang + 1) * baseShares) / 100, 1e1);
            assertApproxEqAbs(tokens[2].balanceOf(self), (100 ether * (gang + 1) * baseShares) / 100, 1e1);

            // tokens[0].burnFrom(self, tokens[0].balanceOf(self));
            // tokens[1].burnFrom(self, tokens[1].balanceOf(self));
            // tokens[2].burnFrom(self, tokens[2].balanceOf(self));
        }
    }

    /// two users stake with different shares
    function test_stake2() public {
        for (uint256 gang; gang < 3; gang++) {
            vault.setYield(gang, [uint256(1), uint256(1), uint256(1)]); //prettier-ignore

            vault.addShares(self, gang, 10_000);

            skip(50 days);

            vault.addShares(self, gang, 20_000);

            vault.addShares(alice, gang, 10_000);

            skip(25 days);

            vm.prank(alice);
            vault.claimUserBalance();

            skip(25 days);

            vault.removeShares(alice, gang, 10_000);

            vm.prank(alice);
            vault.claimUserBalance();

            vault.removeShares(self, gang, 30_000);

            vault.claimUserBalance();

            assertApproxEqAbs(tokens[0].balanceOf(self), (((100 ether * 7) / 8) * baseShares) / 100, 1e1);
            assertApproxEqAbs(tokens[1].balanceOf(self), (((100 ether * 7) / 8) * baseShares) / 100, 1e1);
            assertApproxEqAbs(tokens[2].balanceOf(self), (((100 ether * 7) / 8) * baseShares) / 100, 1e1);

            assertApproxEqAbs(tokens[0].balanceOf(alice), (((100 ether * 1) / 8) * baseShares) / 100, 1e1);
            assertApproxEqAbs(tokens[1].balanceOf(alice), (((100 ether * 1) / 8) * baseShares) / 100, 1e1);
            assertApproxEqAbs(tokens[2].balanceOf(alice), (((100 ether * 1) / 8) * baseShares) / 100, 1e1);

            tokens[0].burnFrom(self, tokens[0].balanceOf(self));
            tokens[1].burnFrom(self, tokens[1].balanceOf(self));
            tokens[2].burnFrom(self, tokens[2].balanceOf(self));

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

            vault.addShares(self, gang, 10_000);

            skip(50 days);

            vault.setYield(gang, [uint256(1), uint256(2), uint256(3)]);

            skip(100 days);

            vault.setYield(gang, [uint256(2), uint256(4), uint256(6)]);

            skip(100 days);

            vault.setYield(gang, [uint256(0), uint256(0), uint256(0)]);

            skip(50 days);

            vault.claimUserBalance();

            assertApproxEqAbs(tokens[0].balanceOf(self), (300 ether * (gang + 1) * baseShares) / 100, 1e1);
            assertApproxEqAbs(tokens[1].balanceOf(self), (600 ether * (gang + 1) * baseShares) / 100, 1e1);
            assertApproxEqAbs(tokens[2].balanceOf(self), (900 ether * (gang + 1) * baseShares) / 100, 1e1);
        }
    }

    /// gang vault fees
    function test_stake4() public {
        assertEq(tokens[0].balanceOf(self), 0);
        assertEq(tokens[1].balanceOf(self), 0);
        assertEq(tokens[2].balanceOf(self), 0);

        uint256[3] memory accrued;
        uint256[3] memory balances;
        uint256[3] memory claimable;

        for (uint256 gang; gang < 3; gang++) {
            vault.setYield(gang, [uint256(1), uint256(1), uint256(1)]);

            vault.addShares(self, gang, 1);

            balances = vault.getGangVaultBalance(gang);
            claimable = vault.getClaimableUserBalance(self);

            assertEq(balances[0], 0);
            assertEq(balances[1], 0);
            assertEq(balances[2], 0);

            assertEq(claimable[0], 0);
            assertEq(claimable[1], 0);
            assertEq(claimable[2], 0);

            skip(100 days);

            claimable = vault.getClaimableUserBalance(self);

            assertEq(claimable[0], 1 ether * baseShares * (gang + 1));
            assertEq(claimable[1], 1 ether * baseShares * (gang + 1));
            assertEq(claimable[2], 1 ether * baseShares * (gang + 1));

            vault.claimUserBalance();

            balances = vault.getGangVaultBalance(gang);
            claimable = vault.getClaimableUserBalance(self);

            assertApproxEqAbs(tokens[0].balanceOf(self), 1 ether * baseShares * (gang + 1), 1e1);
            assertApproxEqAbs(tokens[1].balanceOf(self), 1 ether * baseShares * (gang + 1), 1e1);
            assertApproxEqAbs(tokens[2].balanceOf(self), 1 ether * baseShares * (gang + 1), 1e1);

            assertApproxEqAbs(balances[0], 1 ether * fee, 1e1);
            assertApproxEqAbs(balances[1], 1 ether * fee, 1e1);
            assertApproxEqAbs(balances[2], 1 ether * fee, 1e1);

            assertEq(claimable[0], 0);
            assertEq(claimable[1], 0);
            assertEq(claimable[2], 0);

            vault.spendGangVaultBalance(gang, 4 ether, 3 ether, 1 ether * fee, true);
            balances = vault.getGangVaultBalance(gang);

            assertApproxEqAbs(balances[0], 1 ether * fee - 4 ether, 1e1);
            assertApproxEqAbs(balances[1], 1 ether * fee - 3 ether, 1e1);
            assertApproxEqAbs(balances[2], 0 ether, 1e1);

            vault.spendGangVaultBalance(gang, 4 ether, 5 ether, 0 ether, true);
            balances = vault.getGangVaultBalance(gang);

            assertApproxEqAbs(balances[0], 1 ether * fee - 8 ether, 1e1);
            assertApproxEqAbs(balances[1], 1 ether * fee - 8 ether, 1e1);
            assertApproxEqAbs(balances[2], 0 ether, 1e1);

            tokens[0].burnFrom(self, tokens[0].balanceOf(self));
            tokens[1].burnFrom(self, tokens[1].balanceOf(self));
            tokens[2].burnFrom(self, tokens[2].balanceOf(self));

            // gang 0
            accrued = vault.getAccruedGangVaultBalances(0);

            assertEq(accrued[0], 1 ether * fee * (gang + 1));
            assertEq(accrued[1], 1 ether * fee * (gang + 1));
            assertEq(accrued[2], 1 ether * fee * (gang + 1));

            // gang 1
            accrued = vault.getAccruedGangVaultBalances(1);

            assertEq(accrued[0], 1 ether * fee * (gang + 0));
            assertEq(accrued[1], 1 ether * fee * (gang + 0));
            assertEq(accrued[2], 1 ether * fee * (gang + 0));

            // gang 2
            if (gang > 0) {
                accrued = vault.getAccruedGangVaultBalances(2);

                assertEq(accrued[0], 1 ether * fee * (gang - 1));
                assertEq(accrued[1], 1 ether * fee * (gang - 1));
                assertEq(accrued[2], 1 ether * fee * (gang - 1));
            }
        }
    }

    /// future start/end date
    function test_dates() public {
        uint256 startDate = block.timestamp + 10 days;
        uint256 endDate = block.timestamp + 110 days;

        vault.setYield(0, [uint256(1), uint256(2), uint256(3)]);
        vault.setSeason(uint40(startDate), uint40(endDate), false);

        assertEq(vault.seasonStart(), startDate);
        assertEq(vault.seasonEnd(), endDate);

        skip(5 days);

        vault.addShares(self, 0, 1);

        skip(5 days);

        uint256[3] memory balances = vault.getGangVaultBalance(0);
        uint256[3] memory accrued = vault.getAccruedGangVaultBalances(0);
        uint256[3] memory claimable = vault.getClaimableUserBalance(self);

        assertEq(accrued[0], 0 ether);
        assertEq(accrued[1], 0 ether);
        assertEq(accrued[2], 0 ether);
        assertEq(balances[0], 0 ether);
        assertEq(balances[1], 0 ether);
        assertEq(balances[2], 0 ether);
        assertEq(claimable[0], 0 ether);
        assertEq(claimable[1], 0 ether);
        assertEq(claimable[2], 0 ether);

        skip(200 days);

        // vault.spendGangVaultBalance(0, 0, 0, 0, false);

        balances = vault.getGangVaultBalance(0);
        accrued = vault.getAccruedGangVaultBalances(0);
        claimable = vault.getClaimableUserBalance(self);

        assertEq(accrued[0], 1 ether * fee);
        assertEq(accrued[1], 2 ether * fee);
        assertEq(accrued[2], 3 ether * fee);
        assertEq(balances[0], 1 ether * fee);
        assertEq(balances[1], 2 ether * fee);
        assertEq(balances[2], 3 ether * fee);
        assertEq(claimable[0], 1 ether * baseShares);
        assertEq(claimable[1], 2 ether * baseShares);
        assertEq(claimable[2], 3 ether * baseShares);

        startDate = block.timestamp + 10 days;
        endDate = block.timestamp + 110 days;

        vault.claimUserBalance();
        vault.setSeason(uint40(startDate), uint40(endDate), true);

        balances = vault.getGangVaultBalance(0);
        accrued = vault.getAccruedGangVaultBalances(0);
        claimable = vault.getClaimableUserBalance(self);

        assertEq(accrued[0], 0);
        assertEq(accrued[1], 0);
        assertEq(accrued[2], 0);
        assertEq(balances[0], 0);
        assertEq(balances[1], 0);
        assertEq(balances[2], 0);
        assertEq(claimable[0], 0);
        assertEq(claimable[1], 0);
        assertEq(claimable[2], 0);

        skip(20 days);

        balances = vault.getGangVaultBalance(0);
        accrued = vault.getAccruedGangVaultBalances(0);
        claimable = vault.getClaimableUserBalance(self);

        assertEq(accrued[0], 0.1 ether * fee);
        assertEq(accrued[1], 0.2 ether * fee);
        assertEq(accrued[2], 0.3 ether * fee);
        assertEq(balances[0], 0.1 ether * fee);
        assertEq(balances[1], 0.2 ether * fee);
        assertEq(balances[2], 0.3 ether * fee);
        assertEq(claimable[0], 0.1 ether * baseShares);
        assertEq(claimable[1], 0.2 ether * baseShares);
        assertEq(claimable[2], 0.3 ether * baseShares);

        skip(200 days);

        balances = vault.getGangVaultBalance(0);
        accrued = vault.getAccruedGangVaultBalances(0);
        claimable = vault.getClaimableUserBalance(self);

        assertEq(accrued[0], 1 ether * fee);
        assertEq(accrued[1], 2 ether * fee);
        assertEq(accrued[2], 3 ether * fee);
        assertEq(balances[0], 1 ether * fee);
        assertEq(balances[1], 2 ether * fee);
        assertEq(balances[2], 3 ether * fee);
        assertEq(claimable[0], 1 ether * baseShares);
        assertEq(claimable[1], 2 ether * baseShares);
        assertEq(claimable[2], 3 ether * baseShares);

        startDate = block.timestamp + 10 days;
        endDate = block.timestamp + 110 days;

        vault.setSeason(uint40(startDate), uint40(endDate), false);

        skip(200 days);

        balances = vault.getGangVaultBalance(0);
        accrued = vault.getAccruedGangVaultBalances(0);
        claimable = vault.getClaimableUserBalance(self);

        assertEq(accrued[0], 2 * 1 ether * fee);
        assertEq(accrued[1], 2 * 2 ether * fee);
        assertEq(accrued[2], 2 * 3 ether * fee);
        assertEq(balances[0], 2 * 1 ether * fee);
        assertEq(balances[1], 2 * 2 ether * fee);
        assertEq(balances[2], 2 * 3 ether * fee);
        assertEq(claimable[0], 2 * 1 ether * baseShares);
        assertEq(claimable[1], 2 * 2 ether * baseShares);
        assertEq(claimable[2], 2 * 3 ether * baseShares);
    }
}
