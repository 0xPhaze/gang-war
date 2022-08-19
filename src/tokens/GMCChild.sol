// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
// import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
// import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
// import {FxERC721SyncedChildUDS} from "fx-contracts/extensions/FxERC721SyncedChildUDS.sol";

// import "./lib/LibString.sol";

// error Disabled();

// contract GMCChild is UUPSUpgrade, OwnableUDS, FxERC721SyncedChildUDS {
//     using LibString for uint256;

//     string public constant override name = "Gangsta Mice City";
//     string public constant override symbol = "GMC";

//     string private baseURI;

//     constructor(address fxChild) FxERC721SyncedChildUDS(fxChild) {}

//     function init() external initializer {
//         __Ownable_init();
//     }

//     /* ------------- ERC721 ------------- */

//     function tokenURI(uint256 id) public view override returns (string memory) {
//         return string.concat(baseURI, id.toString());
//     }

//     /* ------------- owner ------------- */

//     function setBaseURI(string calldata _baseURI) external onlyOwner {
//         baseURI = _baseURI;
//     }

//     function _authorizeUpgrade() internal override onlyOwner {}
// }
