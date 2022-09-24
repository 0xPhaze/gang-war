//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {FxERC721MRoot} from "ERC721M/extensions/FxERC721MRoot.sol";
import {ERC20UDS as ERC20} from "UDS/tokens/ERC20UDS.sol";

import "solady/utils/ECDSA.sol";
import "solady/utils/LibString.sol";

error ExceedsLimit();
error TransferFailed();
error IncorrectValue();
error MaxSupplyLocked();
error InvalidSignature();
error NonexistentToken();
error InvalidPriceUnits();
error InvalidMintChoice();
error WhitelistNotActive();
error PublicSaleNotActive();
error SignatureExceedsLimit();
error ContractCallNotAllowed();

/// @title Gangsta Mice City Root
/// @author phaze (https://github.com/0xPhaze)
contract GMC is OwnableUDS, FxERC721MRoot {
    using ECDSA for bytes32;
    using LibString for uint256;

    event SaleStateUpdate();
    event FirstLegendaryRaffleEntered(address user);
    event SecondLegendaryRaffleEntered(address user);

    // 8
    bool public publicSaleActive;

    // 16
    uint8 private publicPriceUnits;
    uint8 private whitelistPriceUnits;

    // 32
    uint16 public maxSupply = 5555;
    uint16 public maxSupplyGangs = 555;
    uint16 public constant MAX_PER_WALLET = 20;

    uint256 private constant PURCHASE_LIMIT = 5;
    uint256 private constant PRICE_UNIT = 0.001 ether;

    // 160
    address private signer = 0x68442589f40E8Fc3a9679dE62884c85C6E524888;

    // 64
    uint16[4] public supplies;

    // 8
    bool public maxSupplyLocked;

    string private baseURI;
    string private unrevealedURI = "ipfs://QmRuQYxmdzqfVfy8ZhZNTvXsmbN9yLnBFPDeczFvWUS2HU/";

    constructor(address checkpointManager, address fxRoot)
        FxERC721MRoot("Gangsta Mice City", "GMC", checkpointManager, fxRoot)
    {
        __Ownable_init();

        publicPriceUnits = toPriceUnits(0.049 ether);
        whitelistPriceUnits = toPriceUnits(0.039 ether);
    }

    /* ------------- view ------------- */

    function totalSupply() public view override returns (uint256) {
        return supplies[0];
    }

    function publicPrice() public view returns (uint256) {
        return toPrice(publicPriceUnits);
    }

    function whitelistPrice() public view returns (uint256) {
        return toPrice(whitelistPriceUnits);
    }

    function getGang(uint256 id) public view returns (uint256) {
        return getAux(id);
    }

    /* ------------- external ------------- */

    function mint(
        uint256 quantity,
        uint256 gang,
        bool lock
    ) external payable onlyEOA requireMintableSupply(quantity, gang) requireMintableByUser(quantity) {
        if (!publicSaleActive) revert PublicSaleNotActive();
        if (msg.value != publicPrice() * quantity) revert IncorrectValue();

        mintUnchecked(msg.sender, quantity, gang, lock);
    }

    function whitelistMint(
        uint256 quantity,
        uint256 gang,
        bool lock,
        uint256 limit,
        bytes calldata signature
    ) external payable onlyEOA requireMintableSupply(quantity, gang) requireMintableByUser(quantity) {
        if (!validSignature(signature, limit)) revert InvalidSignature();
        if (msg.value != whitelistPrice() * quantity) revert IncorrectValue();

        mintUnchecked(msg.sender, quantity, gang, lock);
    }

    function lockAndTransmit(address from, uint256[] calldata tokenIds) external {
        _lockAndTransmit(from, tokenIds);
    }

    function unlockAndTransmit(address from, uint256[] calldata tokenIds) external {
        _unlockAndTransmit(from, tokenIds);
    }

    /* ------------- private ------------- */

    function validSignature(bytes calldata signature, uint256 limit) private view returns (bool) {
        bytes32 hash = keccak256(abi.encode(address(this), msg.sender, limit));

        return hash.toEthSignedMessageHash().recover(signature) == signer;
    }

    function toPrice(uint16 priceUnits) private pure returns (uint256) {
        unchecked {
            return uint256(priceUnits) * PRICE_UNIT;
        }
    }

    function toPriceUnits(uint256 price) private pure returns (uint8) {
        unchecked {
            uint256 units;

            if (price % PRICE_UNIT != 0) revert InvalidPriceUnits();
            if ((units = price / PRICE_UNIT) > type(uint8).max) revert InvalidPriceUnits();

            return uint8(units);
        }
    }

    function mintUnchecked(
        address to,
        uint256 quantity,
        uint256 gang,
        bool lock
    ) private {
        if (quantity > 2) {
            emit FirstLegendaryRaffleEntered(to);
        }
        if (
            quantity > 2 &&
            supplies[0] < 1500 &&
            (gang == 0 || (gang != 0 && supplies[gang] + quantity <= maxSupplyGangs))
        ) {
            ++quantity;
        }

        if (lock) {
            emit SecondLegendaryRaffleEntered(to);
        }

        if (lock) _mintLockedAndTransmit(to, quantity, uint48(gang));
        else _mint(to, quantity, uint48(gang));
    }

    /* ------------- owner ------------- */

    function lockMaxSupply() external onlyOwner {
        maxSupplyLocked = true;
    }

    function setSigner(address addr) external onlyOwner {
        signer = addr;
    }

    function setMaxSupply(uint16 value) external onlyOwner {
        if (maxSupplyLocked) revert MaxSupplyLocked();

        maxSupply = value;
    }

    function setPublicPrice(uint256 value) external onlyOwner {
        publicPriceUnits = toPriceUnits(value);
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    function setPublicSaleActive(bool active) external onlyOwner {
        publicSaleActive = active;

        emit SaleStateUpdate();
    }

    function setWhitelistPrice(uint256 value) external onlyOwner {
        whitelistPriceUnits = toPriceUnits(value);
    }

    function setUnrevealedURI(string calldata uri) external onlyOwner {
        unrevealedURI = uri;
    }

    function airdrop(
        address[] calldata users,
        uint256 quantity,
        uint48 gang,
        bool locked
    ) external onlyOwner requireMintableSupply(quantity * users.length, gang) {
        if (locked) for (uint256 i; i < users.length; ++i) _mintLockedAndTransmit(users[i], quantity, gang);
        else for (uint256 i; i < users.length; ++i) _mint(users[i], quantity, gang);
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");

        if (!success) revert TransferFailed();
    }

    function recoverToken(ERC20 token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));

        token.transfer(msg.sender, balance);
    }

    /* ------------- override ------------- */

    function _authorizeTunnelController() internal override onlyOwner {}

    function _increaseTotalSupply(uint256 amount) internal override {
        supplies[0] += uint16(amount);
    }

    /* ------------- modifier ------------- */

    modifier onlyEOA() {
        if (tx.origin != msg.sender) revert ContractCallNotAllowed();
        _;
    }

    modifier requireMintableByUser(uint256 quantity) {
        unchecked {
            if (quantity > PURCHASE_LIMIT) revert ExceedsLimit();
            if (quantity + numMinted(msg.sender) > MAX_PER_WALLET) revert ExceedsLimit();
        }
        _;
    }

    modifier requireMintableSupply(uint256 quantity, uint256 gang) {
        unchecked {
            if (gang > 3) revert InvalidMintChoice();
            if (quantity + supplies[0] > maxSupply) revert ExceedsLimit();
            if (quantity + supplies[gang] > maxSupplyGangs && gang != 0) revert ExceedsLimit();
        }
        _;
    }

    /* ------------- ERC721 ------------- */

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (!_exists(id)) revert NonexistentToken();

        return 
            bytes(baseURI).length == 0 
            ? unrevealedURI 
            : string.concat(baseURI, id.toString(), ".json"); // prettier-ignore
    }
}
