// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "/tokens/GMCChild.sol";
import "futils/futils.sol";

contract MockGMC is GMCChild {
    using futils for *;

    uint256 gangsterSupply;
    uint256 baronSupply;

    constructor(address fxChild) GMCChild(fxChild) {}

    function mintBatch(address to) public {
        // uint256 baronSupplyStart = baronSupply + 1;
        // uint256 gangsterSupplyStart = gangsterSupply + 1;

        for (uint256 i; i < 7; i++) mint(to, ++baronSupply + 10_000);
        for (uint256 i; i < 10; i++) mint(to, ++gangsterSupply);

        // _registerIds(to, baronSupplyStart.range(baronSupplyStart + 7));
        // _registerIds(to, gangsterSupplyStart.range(gangsterSupplyStart + 10));
    }

    function mint(address to, uint256 id) public {
        _registerIds(to, [id].toMemory());
        // _afterIdRegistered(to, id);
        // GangWar(market).enterGangWar(to, id);
    }
}
