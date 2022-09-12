// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GangToken} from "./GangToken.sol";

/// @title Mice Token
/// @author phaze (https://github.com/0xPhaze)
contract Mice is GangToken {
    string public constant override name = "MICE";
    string public constant override symbol = "MICE";

    address immutable tokenYakuza;
    address immutable tokenCartel;
    address immutable tokenCyberpunk;
    address immutable badges;

    constructor(
        address tokenYakuza_,
        address tokenCartel_,
        address tokenCyberpunk_,
        address badges_
    ) {
        tokenYakuza = tokenYakuza_;
        tokenCartel = tokenCartel_;
        tokenCyberpunk = tokenCyberpunk_;
        badges = badges_;
    }

    /* ------------- owner ------------- */

    function init() external initializer {
        __Ownable_init();
        __AccessControl_init();
    }

    function exchange(uint256 choice, uint256 amount) external {
        if (choice == 0) GangToken(tokenYakuza).burnFrom(msg.sender, amount);
        else if (choice == 1) GangToken(tokenCartel).burnFrom(msg.sender, amount);
        else GangToken(tokenCyberpunk).burnFrom(msg.sender, amount);

        _mint(msg.sender, amount / 3);
    }

    function exchange2(uint256 choice, uint256 amount) external {
        if (choice == 0) {
            GangToken(tokenCartel).burnFrom(msg.sender, amount);
            GangToken(tokenCyberpunk).burnFrom(msg.sender, amount);
        } else if (choice == 1) {
            GangToken(tokenYakuza).burnFrom(msg.sender, amount);
            GangToken(tokenCyberpunk).burnFrom(msg.sender, amount);
        } else {
            GangToken(tokenYakuza).burnFrom(msg.sender, amount);
            GangToken(tokenCartel).burnFrom(msg.sender, amount);
        }

        _mint(msg.sender, amount);
    }

    function exchange3(uint256 amount) external {
        GangToken(tokenYakuza).burnFrom(msg.sender, amount);
        GangToken(tokenCartel).burnFrom(msg.sender, amount);
        GangToken(tokenCyberpunk).burnFrom(msg.sender, amount);

        _mint(msg.sender, amount * 2);
    }

    function exchangeBadges(uint256 amount) external {
        GangToken(badges).burnFrom(msg.sender, amount);

        _mint(msg.sender, amount * 25);
    }
}
