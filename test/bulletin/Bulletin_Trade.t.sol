// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {BulletinTest} from "test/bulletin/Bulletin_Setup.t.sol";
import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

contract BulletinTest_Trade is Test, BulletinTest {
    /* -------------------------------------------------------------------------- */
    /*                                 Post Trade.                                */
    /* -------------------------------------------------------------------------- */

    function test_PostResponseWithPromise(bool byCredit) public payable {
        uint256 requestId = byCredit
            ? postRequestWithCredit(owner, 20 ether, 5 ether)
            : postRequestWithCurrency(owner, 20 ether, 5 ether);
        uint256 tradeId = postTradeWithPromise(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            TEST2,
            BYTES2
        );

        IBulletin.Trade memory t = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );

        assertEq(t.approved, false);
        assertEq(t.paused, false);
        assertEq(t.timestamp, uint40(block.timestamp));
        assertEq(t.duration, 0);
        assertEq(t.from, alice);
        assertEq(t.resource, 0);
        assertEq(t.currency, address(0));
        assertEq(t.amount, 0);
        assertEq(t.content, TEST2);
        assertEq(t.data, BYTES2);
    }

    function test_PostResponseWithResource(bool byCredit) public payable {
        uint256 requestId = byCredit
            ? postRequestWithCredit(owner, 20 ether, 5 ether)
            : postRequestWithCurrency(owner, 20 ether, 5 ether);

        uint256 resourceId = postResource(alice);
        uint256 tradeId = postTradeWithResource(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(bulletin),
            resourceId
        );

        IBulletin.Trade memory t = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );

        assertEq(t.approved, false);
        assertEq(t.paused, false);
        assertEq(t.timestamp, uint40(block.timestamp));
        assertEq(t.duration, 0);
        assertEq(t.from, alice);
        assertEq(
            t.resource,
            bulletin.encodeAsset(address(bulletin), uint96(resourceId))
        );
        assertEq(t.currency, address(0));
        assertEq(t.amount, 0);
        assertEq(t.content, TEST);
        assertEq(t.data, BYTES);
    }

    function test_PostResponseWithCredit(bool byCredit) public payable {
        uint256 requestId = byCredit
            ? postRequestWithCredit(owner, 20 ether, 5 ether)
            : postRequestWithCurrency(owner, 20 ether, 5 ether);

        activate(address(bulletin), owner, alice, 5 ether);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(0xc0d),
            2 ether
        );

        IBulletin.Trade memory t = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );

        assertEq(t.approved, false);
        assertEq(t.paused, false);
        assertEq(t.timestamp, uint40(block.timestamp));
        assertEq(t.duration, 0);
        assertEq(t.from, alice);
        assertEq(t.resource, 0);
        assertEq(t.currency, address(0xc0d));
        assertEq(t.amount, 2 ether);
        assertEq(t.content, TEST);
        assertEq(t.data, BYTES);

        IBulletin.Credit memory credit = bulletin.getCredit(alice);
        assertEq(credit.amount, 3 ether);
    }

    function test_PostResponseWithCurrency(bool byCredit) public payable {
        uint256 requestId = byCredit
            ? postRequestWithCredit(owner, 20 ether, 5 ether)
            : postRequestWithCurrency(owner, 20 ether, 5 ether);

        mock.mint(alice, 5 ether);
        mockApprove(alice, address(bulletin), 5 ether);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(mock),
            2 ether
        );

        IBulletin.Trade memory t = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );

        assertEq(t.approved, false);
        assertEq(t.paused, false);
        assertEq(t.timestamp, uint40(block.timestamp));
        assertEq(t.duration, 0);
        assertEq(t.from, alice);
        assertEq(t.resource, 0);
        assertEq(t.currency, address(mock));
        assertEq(t.amount, 2 ether);
        assertEq(t.content, TEST);
        assertEq(t.data, BYTES);

        assertEq(
            MockERC20(mock).balanceOf(address(bulletin)),
            byCredit ? 2 ether : 7 ether
        );
        assertEq(MockERC20(mock).balanceOf(alice), 3 ether);
    }

    function test_PostResponseWithResourceAndCredit(
        bool byCredit
    ) public payable {
        uint256 requestId = byCredit
            ? postRequestWithCredit(owner, 20 ether, 5 ether)
            : postRequestWithCurrency(owner, 20 ether, 5 ether);

        activate(address(bulletin), owner, alice, 5 ether);
        uint256 resourceId = postResource(alice);
        uint256 tradeId = postTradeWithResourceAndCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(bulletin),
            resourceId,
            address(0xc0d),
            3 ether
        );

        IBulletin.Trade memory t = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );

        assertEq(t.approved, false);
        assertEq(t.paused, false);
        assertEq(t.timestamp, uint40(block.timestamp));
        assertEq(t.duration, 0);
        assertEq(t.from, alice);
        assertEq(
            t.resource,
            bulletin.encodeAsset(address(bulletin), uint96(resourceId))
        );
        assertEq(t.currency, address(0xc0d));
        assertEq(t.amount, 3 ether);
        assertEq(t.content, TEST);
        assertEq(t.data, BYTES);
    }

    function test_PostResponseWithResourceAndCurrency(
        bool byCredit
    ) public payable {
        uint256 requestId = byCredit
            ? postRequestWithCredit(owner, 20 ether, 5 ether)
            : postRequestWithCurrency(owner, 20 ether, 5 ether);

        mock.mint(alice, 5 ether);
        mockApprove(alice, address(bulletin), 5 ether);
        uint256 resourceId = postResource(alice);
        uint256 tradeId = postTradeWithResourceAndCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(bulletin),
            resourceId,
            address(mock),
            3 ether
        );

        IBulletin.Trade memory t = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );

        assertEq(t.approved, false);
        assertEq(t.paused, false);
        assertEq(t.timestamp, uint40(block.timestamp));
        assertEq(t.duration, 0);
        assertEq(t.from, alice);
        assertEq(
            t.resource,
            bulletin.encodeAsset(address(bulletin), uint96(resourceId))
        );
        assertEq(t.currency, address(mock));
        assertEq(t.amount, 3 ether);
        assertEq(t.content, TEST);
        assertEq(t.data, BYTES);
    }

    function test_PostExchangeWithPromise() public payable {
        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithPromise(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            TEST2,
            BYTES2
        );

        IBulletin.Trade memory t = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );

        assertEq(t.approved, false);
        assertEq(t.paused, false);
        assertEq(t.timestamp, uint40(block.timestamp));
        assertEq(t.duration, 0);
        assertEq(t.from, alice);
        assertEq(t.resource, 0);
        assertEq(t.currency, address(0));
        assertEq(t.amount, 0);
        assertEq(t.content, TEST2);
        assertEq(t.data, BYTES2);
    }

    function test_PostExchangeWithResource() public payable {
        uint256 ownerResourceId = postResource(owner);
        uint256 aliceResourceId = postResource(alice);
        uint256 tradeId = postTradeWithResource(
            IBulletin.TradeType.EXCHANGE,
            alice,
            ownerResourceId,
            address(bulletin),
            aliceResourceId
        );

        IBulletin.Trade memory t = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            ownerResourceId,
            tradeId
        );

        assertEq(t.approved, false);
        assertEq(t.paused, false);
        assertEq(t.timestamp, uint40(block.timestamp));
        assertEq(t.duration, 0);
        assertEq(t.from, alice);
        assertEq(
            t.resource,
            bulletin.encodeAsset(address(bulletin), uint96(aliceResourceId))
        );
        assertEq(t.currency, address(0));
        assertEq(t.amount, 0);
        assertEq(t.content, TEST);
        assertEq(t.data, BYTES);
    }

    function test_PostExchangeWithCredit() public payable {
        uint256 resourceId = postResource(owner);

        activate(address(bulletin), owner, alice, 5 ether);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            address(0xc0d),
            2 ether
        );

        IBulletin.Trade memory t = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );

        assertEq(t.approved, false);
        assertEq(t.paused, false);
        assertEq(t.timestamp, uint40(block.timestamp));
        assertEq(t.duration, 0);
        assertEq(t.from, alice);
        assertEq(t.resource, 0);
        assertEq(t.currency, address(0xc0d));
        assertEq(t.amount, 2 ether);
        assertEq(t.content, TEST);
        assertEq(t.data, BYTES);

        IBulletin.Credit memory credit = bulletin.getCredit(alice);
        assertEq(credit.amount, 3 ether);
    }

    function test_PostExchangeWithCurrency() public payable {
        uint256 resourceId = postResource(owner);

        mock.mint(alice, 5 ether);
        mockApprove(alice, address(bulletin), 5 ether);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            address(mock),
            2 ether
        );

        IBulletin.Trade memory t = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );

        assertEq(t.approved, false);
        assertEq(t.paused, false);
        assertEq(t.timestamp, uint40(block.timestamp));
        assertEq(t.duration, 0);
        assertEq(t.from, alice);
        assertEq(t.resource, 0);
        assertEq(t.currency, address(mock));
        assertEq(t.amount, 2 ether);
        assertEq(t.content, TEST);
        assertEq(t.data, BYTES);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 2 ether);
        assertEq(MockERC20(mock).balanceOf(alice), 3 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Update Trade.                               */
    /* -------------------------------------------------------------------------- */

    function test_UpdateResponseWithCredit_IncreaseCredit() public payable {
        uint256 requestId = postRequestWithCredit(owner, 20 ether, 5 ether);

        activate(address(bulletin), owner, alice, 5 ether);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(0xc0d),
            2 ether
        );

        bytes32 r;
        updateTrade(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            r,
            address(0xc0d),
            3 ether
        );

        IBulletin.Trade memory t = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );

        assertEq(t.approved, false);
        assertEq(t.paused, false);
        assertEq(t.timestamp, uint40(block.timestamp));
        assertEq(t.duration, 0);
        assertEq(t.from, alice);
        assertEq(t.resource, 0);
        assertEq(t.currency, address(0xc0d));
        assertEq(t.amount, 3 ether);
        assertEq(t.content, TEST2);
        assertEq(t.data, BYTES2);

        IBulletin.Credit memory credit = bulletin.getCredit(alice);
        assertEq(credit.amount, 2 ether);
    }

    function test_UpdateResponseWithCredit_UpdateToCurrency() public payable {
        uint256 requestId = postRequestWithCredit(owner, 20 ether, 5 ether);

        activate(address(bulletin), owner, alice, 5 ether);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(0xc0d),
            2 ether
        );

        bytes32 r;
        mock.mint(alice, 5 ether);
        mockApprove(alice, address(bulletin), 5 ether);
        updateTrade(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            r,
            address(mock),
            3 ether
        );

        IBulletin.Trade memory t = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );

        assertEq(t.approved, false);
        assertEq(t.paused, false);
        assertEq(t.timestamp, uint40(block.timestamp));
        assertEq(t.duration, 0);
        assertEq(t.from, alice);
        assertEq(t.resource, 0);
        assertEq(t.currency, address(mock));
        assertEq(t.amount, 3 ether);
        assertEq(t.content, TEST2);
        assertEq(t.data, BYTES2);

        IBulletin.Credit memory credit = bulletin.getCredit(alice);
        assertEq(credit.amount, 5 ether);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 3 ether);
        assertEq(MockERC20(mock).balanceOf(alice), 2 ether);
    }

    function test_UpdateResponseWithCurrency_IncreaseCurrency() public payable {
        uint256 requestId = postRequestWithCredit(owner, 20 ether, 5 ether);

        mock.mint(alice, 5 ether);
        mockApprove(alice, address(bulletin), 5 ether);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(mock),
            2 ether
        );

        bytes32 r;
        updateTrade(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            r,
            address(mock),
            3 ether
        );

        IBulletin.Trade memory t = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );

        assertEq(t.approved, false);
        assertEq(t.paused, false);
        assertEq(t.timestamp, uint40(block.timestamp));
        assertEq(t.duration, 0);
        assertEq(t.from, alice);
        assertEq(t.resource, 0);
        assertEq(t.currency, address(mock));
        assertEq(t.amount, 3 ether);
        assertEq(t.content, TEST2);
        assertEq(t.data, BYTES2);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 3 ether);
        assertEq(MockERC20(mock).balanceOf(alice), 2 ether);
    }

    function test_UpdateResponseWithCurrency_UpdateToCredit() public payable {
        uint256 requestId = postRequestWithCredit(owner, 20 ether, 5 ether);

        mock.mint(alice, 5 ether);
        mockApprove(alice, address(bulletin), 5 ether);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(mock),
            2 ether
        );

        bytes32 r;
        activate(address(bulletin), owner, alice, 5 ether);
        updateTrade(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            r,
            address(0xc0d),
            3 ether
        );

        IBulletin.Trade memory t = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );

        assertEq(t.approved, false);
        assertEq(t.paused, false);
        assertEq(t.timestamp, uint40(block.timestamp));
        assertEq(t.duration, 0);
        assertEq(t.from, alice);
        assertEq(t.resource, 0);
        assertEq(t.currency, address(0xc0d));
        assertEq(t.amount, 3 ether);
        assertEq(t.content, TEST2);
        assertEq(t.data, BYTES2);

        IBulletin.Credit memory credit = bulletin.getCredit(alice);
        assertEq(credit.amount, 2 ether);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(alice), 5 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Reverts.                                  */
    /* -------------------------------------------------------------------------- */

    function testRevert_PostTradeWithResource_NotOwnerOfResource()
        public
        payable
    {
        uint256 requestId = postRequestWithCredit(owner, 20 ether, 5 ether);
        postResource(owner);

        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            timestamp: uint40(block.timestamp),
            duration: 2 weeks,
            from: alice,
            resource: bulletin.encodeAsset(address(bulletin), 1),
            currency: address(0),
            amount: 0,
            content: TEST,
            data: BYTES
        });

        vm.expectRevert(IBulletin.NotOwnerOfResource.selector);
        vm.prank(alice);
        bulletin.trade(IBulletin.TradeType.RESPONSE, requestId, trade);
    }

    function testRevert_PostTradeWithResource_InvalidBulletin() public payable {
        uint256 requestId = postRequestWithCredit(owner, 20 ether, 5 ether);

        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            timestamp: uint40(block.timestamp),
            duration: 2 weeks,
            from: alice,
            resource: bulletin.encodeAsset(address(1), 1),
            currency: address(0),
            amount: 0,
            content: TEST,
            data: BYTES
        });

        vm.expectRevert();
        vm.prank(alice);
        bulletin.trade(IBulletin.TradeType.RESPONSE, requestId, trade);
    }
}
