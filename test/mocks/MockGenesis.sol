// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "solmate/test/utils/mocks/MockERC721.sol";
// import "UDS/tokens/ERC721UDS.sol";
import "UDS/../test/mocks/MockERC721EnumerableUDS.sol";

contract MockGenesis is MockERC721EnumerableUDS {
    constructor(string memory name, string memory symbol) {
        __ERC721_init(name, symbol);
    }

    function tokenIdsOf(address user, uint256) external view returns (uint256[] memory) {
        return getOwnedIds(user);
    }

    function trueOwnerOf(uint256 id) external view returns (address) {
        return ownerOf(id);
    }

    function airdrop(address[] calldata user, uint256 quantity) external {
        for (uint256 u; u < user.length; u++) {
            for (uint256 i; i < quantity; i++) {
                _mint(user[u], totalSupply() + 1);
            }
        }
    }
}
