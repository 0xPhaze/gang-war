// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "solmate/test/utils/mocks/MockERC721.sol";
// import "UDS/tokens/ERC721UDS.sol";
import "UDS/../test/mocks/MockERC721EnumerableUDS.sol";

contract MockGenesis is MockERC721EnumerableUDS {
    constructor(string memory name, string memory symbol) {
        __ERC721_init(name, symbol);
    }

    function trueOwnerOf(uint256 id) external view returns (address) {
        return ownerOf(id);
    }
}
