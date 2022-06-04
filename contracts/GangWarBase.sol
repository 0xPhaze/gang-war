// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract GangWarBase {
    function ownerOrRenterOf(uint256 id) public view virtual returns (address);
}
