// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {ERC20BurnableUDS} from "UDS/tokens/extensions/ERC20BurnableUDS.sol";
import {AccessControlUDS} from "UDS/auth/AccessControlUDS.sol";

/// @title Gang Token
/// @author phaze (https://github.com/0xPhaze)
contract GangToken is UUPSUpgrade, OwnableUDS, ERC20BurnableUDS, AccessControlUDS {
    uint8 public constant override decimals = 18;

    bytes32 constant AUTHORITY = keccak256("AUTHORITY");

    function init(string calldata name_, string calldata symbol_) external initializer {
        __Ownable_init();
        __AccessControl_init();
        __ERC20_init(name_, symbol_, 18);
    }

    /* ------------- external ------------- */

    function mint(address user, uint256 amount) external onlyRole(AUTHORITY) {
        _mint(user, amount);
    }

    /* ------------- ERC20Burnable ------------- */

    function burnFrom(address from, uint256 amount) public override {
        if (msg.sender == from || hasRole(AUTHORITY, msg.sender)) _burn(from, amount);
        else super.burnFrom(from, amount);
    }

    /* ------------- owner ------------- */

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function airdrop(address[] calldata tos, uint256 amount) external onlyOwner {
        unchecked {
            for (uint256 i; i < tos.length; ++i) {
                _mint(tos[i], amount);
            }
        }
    }

    function airdrop(address[] calldata tos, uint256[] memory amounts) external onlyOwner {
        unchecked {
            for (uint256 i; i < tos.length; ++i) {
                _mint(tos[i], amounts[i]);
            }
        }
    }
}
