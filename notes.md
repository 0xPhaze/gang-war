
# TODO



- MockGMC enumerable
- MockGMC NFT random gang for Demo?

- market listing

- add validation to using items on districts (attackers / defenders)

- add Game pause/reset option
- make enterGangWar/exitGangWar more robust, add resync option
- build environment to quickly script/interact with deployed contracts
- add actual VRF integration!


# Frontend

# Test
- test purchaseItems (add delay for barons?)
- test badges rewards
- test exchange
- test outcome statistics fuzz

- test all items usage
- test clean activeItems on state change

- recovery/bribery countdown reduction half of remaining time (disable for barons?)
- make sure this state is kept even for exit/enter GangWar

- test performUpkeep on all districts (gas)
    // 21 cold: gas 1400000
    // 21 warm: gas 800000
    // 10 cold: gas 676532
    // 10 warm: gas 384932

# Final
- restore times (district phases)
- integrate with final VRF
- what is LOCKUP_FINE?

# Not-so-important
- getGangVaultBalance without address(0) call

# XChain Registry???
