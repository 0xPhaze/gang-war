// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "/GangWar.sol";
import "solmate/test/utils/mocks/MockERC721.sol";

import "/utils/utils.sol";

contract MockGMC is MockERC721("Gangsta Mice City", "GMC") {
    address gangWar;
    uint256 gangsterSupply;
    uint256 baronSupply;

    function setGangWar(address gangWar_) public {
        gangWar = gangWar_;
    }

    function mintBatch(address to) public {
        for (uint256 i; i < 10; i++) mint(to, ++gangsterSupply);
        for (uint256 i; i < 5; i++) mint(to, ++baronSupply + 10_000);
    }

    function mint(address to, uint256 id) public override {
        super.mint(to, id);
        GangWar(gangWar).enterGangWar(to, id);
    }

    function getOwnedIds(address user) public view returns (uint256[] memory ids) {
        uint256[] memory gangsters = utils.getOwnedIds(_ownerOf, user, 1, gangsterSupply);
        uint256[] memory barons = utils.getOwnedIds(_ownerOf, user, 10_000, baronSupply);

        uint256 len = gangsters.length + barons.length;
        ids = new uint256[](len);

        for (uint256 i; i < gangsters.length; i++) ids[i] = gangsters[i];
        for (uint256 i; i < barons.length; i++) ids[i + gangsters.length] = barons[i];
    }
}
