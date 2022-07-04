Compiling 7 files with 0.8.13
Solc 0.8.13 finished in 4.48s
Compiler run successful (with warnings)
warning[9302]: Warning: Return value of low-level calls not used.
  --> src/GangWar.sol:84:52:
   |
84 |         for (uint256 i; i < calldata_.length; ++i) address(this).delegatecall(calldata_[i]);
   |                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^




Running 1 test for src/test/GangWarRewards.t.sol:TestGangWarRewards
[31m[FAIL. Reason: Arithmetic over/underflow][0m test_transferYield() (gas: 355364)
Test result: [31mFAILED[0m. 0 passed; 1 failed; finished in 2.88ms
╭────────────────────────────────────────────────────────┬─────────────────┬────────┬────────┬────────┬─────────╮
│ src/test/GangWarRewards.t.sol:MockGangRewards contract ┆                 ┆        ┆        ┆        ┆         │
╞════════════════════════════════════════════════════════╪═════════════════╪════════╪════════╪════════╪═════════╡
│ Deployment Cost                                        ┆ Deployment Size ┆        ┆        ┆        ┆         │
├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌┤
│ 992541                                                 ┆ 5356            ┆        ┆        ┆        ┆         │
├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌┤
│ Function Name                                          ┆ min             ┆ avg    ┆ median ┆ max    ┆ # calls │
├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌┤
│ setRewardRate                                          ┆ 100808          ┆ 100808 ┆ 100808 ┆ 100808 ┆ 1       │
├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌┤
│ transferYield                                          ┆ 2916            ┆ 9253   ┆ 3644   ┆ 31544  ┆ 25      │
╰────────────────────────────────────────────────────────┴─────────────────┴────────┴────────┴────────┴─────────╯


Failed tests:
[31m[FAIL. Reason: Arithmetic over/underflow][0m test_transferYield() (gas: 355364)

Encountered a total of [31m1[0m failing tests, [32m0[0m tests succeeded
