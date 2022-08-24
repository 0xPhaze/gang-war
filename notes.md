
# TODO

- make enterGangWar/exitGangWar more robust, add resync option
- add Game pause/reset option

- add actual VRF integration!

- MockGMC enumerable
- MockGMC NFT random gang for Demo?

- market listing
- build environment to quickly script/interact with deployed contracts

# Frontend
- add getBaronItemBalances(Gang gang) to frontend
- update ABI (BaronItems)

# Test
- test purchaseItems (add delay for barons?)
- test badges rewards
- test exchange
- test outcome stats
- test GangWarReward on actual GangWar
- add scramble

- test clean activeItems on state change

- test cops lockup activating
- make sure cops don't lockup same district twice
- test lockup yield taken
- test lockup state (district, player)
- test bribery durations

- recovery/bribery countdown reduction half of remaining time (disable for barons?)
- make sure this state is kept even for exit/enter GangWar

- test performUpkeep on all districts (gas)
    // 21 cold: gas 1400000
    // 21 warm: gas 800000
    // 10 cold: gas 676532
    // 10 warm: gas 384932

# Final
- finalize prices for items
- restore times
- integrate with final VRF

# Not-so-important
- getGangVaultBalance without address(0) call

# XChain Registry???
