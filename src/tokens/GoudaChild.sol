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
    string public constant override name = "Gouda";
    string public constant override symbol = "GOUDA";
    uint8 public constant override decimals = 18;

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

    function airdrop(address[] calldata tos, uint256[] memory amounts) external onlyRole(AUTHORITY) {
        unchecked {
            for (uint256 i; i < tos.length; ++i) {
                _mint(tos[i], amounts[i]);
            }
        }
    }

    function airdrop(address[] calldata tos, uint256 amount) external onlyRole(AUTHORITY) {
        unchecked {
            for (uint256 i; i < tos.length; ++i) {
                _mint(tos[i], amount);
            }
        }
    }

    /* ------------- ERC20Burnable ------------- */

    function burnFrom(address from, uint256 amount) public override {
        if (hasRole(AUTHORITY, msg.sender)) _burn(from, amount);
        else super.burnFrom(from, amount);
    }

    /* ------------- owner ------------- */

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _authorizeTunnelController() internal override onlyOwner {}
}
