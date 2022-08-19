// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
// import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
// import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

// import {FxERC721ChildUDS} from "fx-contracts/FxERC721ChildUDS.sol";

// import "./lib/LibString.sol";

// // ------------- error

// error Disabled();

// contract SafeHouse is UUPSUpgrade, OwnableUDS, FxERC721ChildUDS {
//     using LibString for uint256;

//     string public constant override name = "Safe House";
//     string public constant override symbol = "SAFE";

//     string private baseURI;

//     constructor(address fxChild) FxERC721ChildUDS(fxChild) {}

//     function init() external initializer {
//         __Ownable_init();
//     }

//     function tokenURI(uint256 id) public view override returns (string memory) {
//         return string.concat(baseURI, id.toString());
//     }

//     /* ------------- public ------------- */

//     function delegateOwnership(address to, uint256 id) public {
//         ERC721UDS.transferFrom(msg.sender, to, id);
//     }

//     function approve(address, uint256) public pure override {
//         revert Disabled();
//     }

//     function setApprovalForAll(address, bool) public pure override {
//         revert Disabled();
//     }

//     function transferFrom(address, address, uint256) public pure override {
//         revert Disabled();
//     }

//     function safeTransferFrom(address, address, uint256) public pure override {
//         revert Disabled();
//     }

//     function safeTransferFrom(address, address, uint256, bytes calldata) public pure override {
//         revert Disabled();
//     }

//     function permit(address, address, uint256, uint8, bytes32, bytes32) public pure override {
//         revert Disabled();
//     }

//     /* ------------- owner ------------- */

//     function setBaseURI(string calldata _baseURI) external onlyOwner {
//         baseURI = _baseURI;
//     }

//     function _authorizeUpgrade() internal override onlyOwner {}
// }
