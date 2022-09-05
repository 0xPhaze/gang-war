// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "/tokens/GMCRoot.sol";

contract MockGMCRoot is GMC {
    constructor(address checkpointManager, address fxRoot) GMC(checkpointManager, fxRoot) {}

    function freeMint(
        address to,
        uint256 quantity,
        bool lock
    ) public {
        if (lock) _mintLockedAndTransmit(to, quantity);
        else _mint(to, quantity);
    }
}
