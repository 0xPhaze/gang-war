
# TODO

- add bribery fee
- baron item cost

- fix collect badges
- fix adding shares (enter/exit gangWar)

- MockGMC enumerable
- MockGMC NFT random gang for Demo?

- market listing

- add validation to using items on districts (attackers / defenders)

- add actual VRF integration!

- add Game pause/reset option
- make enterGangWar/exitGangWar more robust, add resync option

- add shares reset / automated enter mechanics that conform with market

# Frontend
- transform activeItems to array

- add in function getGangAccumulatedBalance() external view returns (uint80[3][3])

# Test
- test purchaseItems (add delay for barons?)
- test badges rewards
- test exchange
- test outcome statistics fuzz

- test all items usage

- recovery/bribery countdown reduction half of remaining time (disable for barons?)
- make sure this state is kept even for exit/enter GangWar

- performUpkeep (gas)
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
