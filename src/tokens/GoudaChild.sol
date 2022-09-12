// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {FxERC20UDSChild} from "fx-contracts/FxERC20UDSChild.sol";
import {AccessControlUDS} from "UDS/auth/AccessControlUDS.sol";
import {ERC20BurnableUDS} from "UDS/tokens/extensions/ERC20BurnableUDS.sol";

/// @title Gouda Child
/// @author phaze (https://github.com/0xPhaze/fx-contracts)
contract GoudaChild is UUPSUpgrade, OwnableUDS, ERC20BurnableUDS, FxERC20UDSChild, AccessControlUDS {
    uint8 public constant override decimals = 18;

    string public constant override name = "Gouda";
    string public constant override symbol = "GOUDA";

    bytes32 private constant AUTHORITY = keccak256("AUTHORITY");

    constructor(address fxChild) FxERC20UDSChild(fxChild) {}

    function init() public initializer {
        __Ownable_init();
        __AccessControl_init();
    }

    /* ------------- external ------------- */

    function mint(address user, uint256 amount) external onlyRole(AUTHORITY) {
        _mint(user, amount);
    }

    /* ------------- ERC20Burnable ------------- */

    function burnFrom(address from, uint256 amount) public override {
        if (hasRole(AUTHORITY, msg.sender)) _burn(from, amount);
        else super.burnFrom(from, amount);
    }

    /* ------------- authority ------------- */

    function grantAuthority(address operator) external {
        grantRole(AUTHORITY, operator);
    }

    /* ------------- owner ------------- */

    function _authorizeUpgrade() internal override onlyOwner {}

    function _authorizeTunnelController() internal override onlyOwner {}
}
