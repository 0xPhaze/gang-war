// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "futils/futils.sol";
import "/tokens/GMCRoot.sol";
import {SetupRoot} from "../src/SetupRoot.sol";

contract TestGMCRoot is Test, SetupRoot {
    using futils for *;
    using ECDSA for bytes32;
    using LibString for *;

    address alice = makeAddr("alice");
    address self = address(this);
    address bob = makeAddr("bob");
    address eve = makeAddr("eve");

    uint256 price;
    uint256 signerPK;
    address signer;

    function setUp() public virtual {
        setUpContracts();

        vm.label(self, "self");

        gmc.setSigner(self);
        gmc.setMintStart(uint32(block.timestamp));

        price = gmc.publicPrice();

        gmc.setFxChildTunnel(address(123));

        signerPK = 0x133737;
        signer = vm.addr(signerPK);
    }

    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_BYPASS = true;
    }

    /* ------------- setup() ------------- */

    function test_setUp() public {
        assertEq(gmc.maxSupply(), 6666);
        assertEq(gmc.mintStart(), block.timestamp);
        assertEq(gmc.publicPrice(), 0.049 ether);
        assertEq(gmc.whitelistPrice(), 0.039 ether);
    }

    /* ------------- mint() ------------- */

    function test_mint(uint256 quantity) public {
        self.balanceDiff();

        uint256 totalSupply = gmc.totalSupply();
        uint256 numMinted = gmc.numMinted(self);

        quantity = bound(quantity, 1, gmc.PURCHASE_LIMIT());

        uint256 value = gmc.publicPrice() * quantity;

        vm.prank(self, self);
        gmc.mint{value: value}(quantity, false);

        if (quantity > 2 && totalSupply + quantity < 1500) quantity++;

        assertEq(self.balanceDiff(), -int256(value));
        assertEq(gmc.totalSupply(), totalSupply + quantity);
        assertEq(gmc.numMinted(self), numMinted + quantity);

        for (uint256 i; i < quantity; ++i) {
            assertEq(gmc.ownerOf(1 + totalSupply + i), self);
        }
    }

    // function test_mint_full_supply() public {
    //     gmc.airdrop([self].toMemory(), gmc.maxSupply(), false);

    //     vm.expectRevert(ExceedsLimit.selector);
    //     vm.prank(self, self);

    //     gmc.mint{value: price}(1, false);

    //     for (uint256 i; i < gmc.maxSupply(); ++i) {
    //         assertEq(gmc.ownerOf(1 + i), self);
    //     }
    // }

    function test_mint_revert_PublicSaleNotActive() public {
        gmc.setMintStart(uint32(block.timestamp + 1 minutes));

        vm.expectRevert(PublicSaleNotActive.selector);
        vm.prank(self, self);

        gmc.mint{value: price}(1, false);
    }

    function test_mint_revert_ExceedsLimit() public {
        uint256 quantity = gmc.PURCHASE_LIMIT() + 1;
        uint256 value = gmc.publicPrice() * quantity;

        vm.expectRevert(ExceedsLimit.selector);
        vm.prank(self, self);

        gmc.mint{value: value}(quantity, false);
    }

    function test_mint_revert_ExceedsLimit2() public {
        // 3 => 4 because of stupid bound results....
        // + 1 because of bonus
        test_mint(3);
        test_mint(3);
        test_mint(3);
        test_mint(3);

        assertEq(gmc.numMinted(self), 20);

        vm.prank(self, self);
        vm.expectRevert(ExceedsLimit.selector);

        gmc.mint{value: price}(1, false);
    }

    function test_mint_revert_ExceedsLimit3() public {
        gmc.setMaxSupply(4);

        vm.expectRevert(ExceedsLimit.selector);
        vm.prank(self, self);

        gmc.mint{value: price * 5}(5, false);
    }

    /* ------------- whitelistMint() ------------- */

    function whitelist(uint256 quantity) internal returns (bytes memory signature) {
        gmc.setSigner(signer);

        bytes32 digest = keccak256(abi.encode(address(gmc), self, quantity));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPK, digest.toEthSignedMessageHash());
        signature = abi.encodePacked(r, s, v);
    }

    function test_whitelistMint(uint256 quantity) public {
        self.balanceDiff();

        uint256 totalSupply = gmc.totalSupply();
        uint256 numMinted = gmc.numMinted(self);

        quantity = bound(quantity, 1, gmc.PURCHASE_LIMIT());

        bytes memory signature = whitelist(quantity);

        uint256 value = gmc.whitelistPrice() * quantity;

        vm.prank(self, self);
        gmc.whitelistMint{value: value}(quantity, false, quantity, signature);

        if (quantity > 2 && totalSupply + quantity < 1500) quantity++;

        assertEq(self.balanceDiff(), -int256(value));
        assertEq(gmc.totalSupply(), totalSupply + quantity);
        assertEq(gmc.numMinted(self), numMinted + quantity);

        for (uint256 i; i < quantity; ++i) {
            assertEq(gmc.ownerOf(1 + totalSupply + i), self);
        }
    }

    function test_whitelistMint_revert_ExceedsLimit() public {
        uint256 limit = 5;
        uint256 quantity = 3;

        bytes memory signature = whitelist(limit);

        uint256 value = gmc.whitelistPrice() * quantity;

        vm.prank(self, self);
        gmc.whitelistMint{value: value}(quantity, false, limit, signature);

        vm.expectRevert(ExceedsLimit.selector);

        vm.prank(self, self);
        gmc.whitelistMint{value: value}(quantity, false, limit, signature);
    }

    function test_whitelistMint_revert_ExceedsLimit2() public {
        uint256 limit = 10;
        uint256 quantity = 10;

        bytes memory signature = whitelist(limit);

        uint256 value = gmc.whitelistPrice() * quantity;

        vm.prank(self, self);
        vm.expectRevert(ExceedsLimit.selector);

        gmc.whitelistMint{value: value}(quantity, false, limit, signature);
    }

    function test_whitelistMint_revert_ExceedsLimit3() public {
        gmc.setMaxSupply(4);

        uint256 limit = 5;
        uint256 quantity = 5;

        bytes memory signature = whitelist(limit);

        uint256 value = gmc.whitelistPrice() * quantity;

        vm.prank(self, self);
        vm.expectRevert(ExceedsLimit.selector);

        gmc.whitelistMint{value: value}(quantity, false, limit, signature);
    }

    /* ------------- lock() ------------- */

    function test_mintAndLock() public {
        vm.prank(self, self);

        gmc.mint{value: 4 * price}(4, true);

        for (uint256 i; i < 4; ++i) {
            assertEq(gmc.ownerOf(1 + i), address(gmc));
            assertEq(gmc.trueOwnerOf(1 + i), self);
        }
    }

    function test_mintThenLock() public {
        uint256 startId = gmc.totalSupply() + 1;

        test_mint(4);

        for (uint256 i; i < 4; ++i) {
            assertEq(gmc.ownerOf(startId + i), self);
            assertEq(gmc.trueOwnerOf(startId + i), self);
        }

        gmc.lockAndTransmit(self, startId.range(startId + 5));
    }

    function test_mintAndLock_unlock() public {
        skip(10 hours);

        test_mintAndLock();
        test_mintThenLock();

        skip(gmc.BRIDGE_RAFFLE_LOCK_DURATION());

        gmc.unlockAndTransmit(self, 1.range(5));
        gmc.unlockAndTransmit(self, 5.range(10));
    }

    function test_mintAndLock_unlock_revert_TimelockActive() public {
        test_mintAndLock();

        for (uint256 i; i < 4; ++i) {
            vm.expectRevert(TimelockActive.selector);

            gmc.unlockAndTransmit(self, [i].toMemory());
        }
    }

    function test_mintThenLock_unlock_revert_TimelockActive() public {
        test_mintThenLock();

        for (uint256 i; i < 4; ++i) {
            vm.expectRevert(TimelockActive.selector);

            gmc.unlockAndTransmit(self, [i].toMemory());
        }
    }

    /* ------------- set() ------------- */

    function test_setSigner() public {
        gmc.setSigner(signer);
    }

    function test_setUnrevealedURI() public {
        string memory uri = "ipfs://1234/";

        gmc.setUnrevealedURI(uri);

        assertEq(gmc.tokenURI(3), uri);
    }

    function test_setURI() public {
        string memory uri = "ipfs://1234/";

        gmc.setBaseURI(uri);

        assertEq(gmc.tokenURI(1), string.concat(uri, 1.toString(), ".json"));
    }

    function test_setMintStart() public {
        gmc.setMintStart(uint32(block.timestamp));

        assertEq(gmc.mintStart(), block.timestamp);
    }

    function test_setPublicPrice() public {
        gmc.setPublicPrice(0.001 ether);

        assertEq(gmc.publicPrice(), 0.001 ether);

        test_mint(2);

        gmc.setPublicPrice(0.234 ether);

        assertEq(gmc.publicPrice(), 0.234 ether);

        test_mint(3);
    }

    /* ------------- withdraw() ------------- */

    function test_withdraw() public {
        test_mint(4);

        self.balanceDiff();

        gmc.withdraw();

        assertEq(self.balanceDiff(), 5 * int256(gmc.publicPrice()));
    }

    receive() external payable {}
}
