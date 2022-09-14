
# TODO

- ability to set gangs
- mass mint to wallets
- add delay for barons to buy/use items
- add vault earnings reset for game start (no accrued fees)
- blitz state countdown reduction relative?
- add name entry for gangster profile
- optimize storage


# Frontend
- add in function getGangAccumulatedBalance() external view returns (uint256[3][3])
- getGangAccumulatedBadges()


# Test
- test purchaseItems (add delay for barons?)
- test outcome statistics fuzz
- test vault season reset

- performUpkeep (gas)
    // 21 cold: gas 1400000
    // 21 warm: gas 800_000
    // 10 cold: gas 676532
    // 10 warm: gas 384932
- add chainlink upkeep partial run

# Final
- restore times (district phases, + RENTAL_ACCEPTANCE_MINIMUM_TIME_DELAY )
- integrate with final VRF
- what is LOCKUP_FINE?

# XChain testing
