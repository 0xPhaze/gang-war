// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solmate/test/utils/mocks/MockERC721.sol";

contract MockGenesis is MockERC721 {
    constructor(string memory name, string memory symbol) MockERC721(name, symbol) {}

    function trueOwnerOf(uint256 id) external view returns (address) {
        return ownerOf(id);
    }
}
