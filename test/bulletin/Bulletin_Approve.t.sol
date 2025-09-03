// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {BulletinTest} from "test/bulletin/Bulletin_Setup.t.sol";
import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";
import {console} from "lib/forge-std/src/console.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract BulletinTest_Approve is Test, BulletinTest {
    /* -------------------------------------------------------------------------- */
    /*                                  Request.                                  */
    /* -------------------------------------------------------------------------- */

    function test_ApproveWithCurrency_ResponseWithPromise(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);

        // setup request with currency
        uint256 requestId = postRequestWithCurrency(owner, amount, amount);

        // setup trade
        uint256 tradeId = postTradeWithPromise(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            TEST,
            BYTES
        );
        uint256 aliceNumberOfBulletinToken = bulletin.balanceOf(
            alice,
            bulletin.encodeTokenId(
                address(bulletin),
                IBulletin.TradeType.RESPONSE,
                uint40(requestId),
                uint40(tradeId)
            )
        );

        // approve trade
        approveTradeToRequest(owner, requestId, tradeId, amount);

        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, alice);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 0);
        assertEq(trade.duration, 0);
        assertEq(trade.currency, address(mock));
        assertEq(trade.amount, amount);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        assertEq(
            bulletin.balanceOf(
                alice,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.RESPONSE,
                    uint40(requestId),
                    uint40(tradeId)
                )
            ),
            ++aliceNumberOfBulletinToken
        );
    }

    function test_ApproveWithCurrency_ResponseWithPromise_TwoApprovals(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);

        // setup request with currency
        uint256 requestId = postRequestWithCurrency(owner, amount, amount);

        // setup first trade
        uint256 tradeId = postTradeWithPromise(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            TEST,
            BYTES
        );
        uint256 aliceNumberOfBulletinToken = bulletin.balanceOf(
            alice,
            bulletin.encodeTokenId(
                address(bulletin),
                IBulletin.TradeType.RESPONSE,
                uint40(requestId),
                uint40(tradeId)
            )
        );

        // approve first trade
        approveTradeToRequest(owner, requestId, tradeId, amount / 2);

        // verify
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, alice);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 0);
        assertEq(trade.duration, 0);
        assertEq(trade.currency, address(mock));
        assertEq(trade.amount, amount / 2);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        assertEq(
            bulletin.balanceOf(
                alice,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.RESPONSE,
                    uint40(requestId),
                    uint40(tradeId)
                )
            ),
            ++aliceNumberOfBulletinToken
        );

        // setup second trade
        uint256 tradeId2 = postTradeWithPromise(
            IBulletin.TradeType.RESPONSE,
            bob,
            requestId,
            TEST2,
            BYTES2
        );
        uint256 bobNumberOfBulletinToken = bulletin.balanceOf(
            bob,
            bulletin.encodeTokenId(
                address(bulletin),
                IBulletin.TradeType.RESPONSE,
                uint40(requestId),
                uint40(tradeId)
            )
        );

        // approve second trade
        approveTradeToRequest(owner, requestId, tradeId2, amount / 2);

        // verify
        trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId2
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, bob);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 0);
        assertEq(trade.duration, 0);
        assertEq(trade.currency, address(mock));
        assertEq(trade.amount, amount / 2);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST2);
        assertEq(trade.data, BYTES2);

        assertEq(
            bulletin.balanceOf(
                bob,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.RESPONSE,
                    uint40(requestId),
                    uint40(tradeId2)
                )
            ),
            ++bobNumberOfBulletinToken
        );
    }

    function test_ApproveWithCurrency_ResponseWithResource(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

        // setup request with currency
        uint256 requestId = postRequestWithCurrency(owner, 10 ether, amount);

        // setup resource
        uint256 resourceId = postResource(alice);

        // setup trade
        uint256 tradeId = postTradeWithResource(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(bulletin),
            resourceId
        );
        uint256 numberOfBulletinToken = bulletin.balanceOf(
            alice,
            bulletin.encodeTokenId(
                address(bulletin),
                IBulletin.TradeType.RESPONSE,
                uint40(requestId),
                uint40(tradeId)
            )
        );

        // approve trade
        approveTradeToRequest(owner, requestId, tradeId, amount);

        // verify
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, alice);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 0);
        assertEq(trade.duration, 0);
        assertEq(trade.currency, address(mock));
        assertEq(trade.amount, amount);
        assertEq(
            trade.resource,
            bulletin.encodeAsset(address(bulletin), uint96(resourceId))
        );
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        assertEq(
            bulletin.balanceOf(
                alice,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.RESPONSE,
                    uint40(requestId),
                    uint40(tradeId)
                )
            ),
            ++numberOfBulletinToken
        );
    }

    function test_ApproveWithCurrency_ResponseWithCurrency(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);

        // setup request with currency
        uint256 requestId = postRequestWithCurrency(owner, amount, amount);

        // setup first trade
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(mock),
            amount * 10
        );
        uint256 aliceNumberOfBulletinToken = bulletin.balanceOf(
            alice,
            bulletin.encodeTokenId(
                address(bulletin),
                IBulletin.TradeType.RESPONSE,
                uint40(requestId),
                uint40(tradeId)
            )
        );

        // approve first trade
        approveTradeToRequest(owner, requestId, tradeId, amount / 2);

        // verify
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, alice);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 0);
        assertEq(trade.duration, 0);
        assertEq(trade.currency, address(mock));
        assertEq(trade.amount, amount / 2);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        assertEq(
            bulletin.balanceOf(
                alice,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.RESPONSE,
                    uint40(requestId),
                    uint40(tradeId)
                )
            ),
            ++aliceNumberOfBulletinToken
        );
        assertEq(mock.balanceOf(owner), amount * 10);
        assertEq(mock.balanceOf(address(bulletin)), amount);
    }

    function test_ApproveWithCurrency_ResponseWithCredit(
        uint256 amount
    ) public payable {
        vm.assume(20 ether > amount);
        vm.assume(amount > 10_000);

        // setup request with currency
        uint256 requestId = postRequestWithCurrency(owner, amount, amount);

        // setup first trade
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(0xc0d),
            amount * 15
        );
        uint256 aliceNumberOfBulletinToken = bulletin.balanceOf(
            alice,
            bulletin.encodeTokenId(
                address(bulletin),
                IBulletin.TradeType.RESPONSE,
                uint40(requestId),
                uint40(tradeId)
            )
        );

        // approve first trade
        approveTradeToRequest(owner, requestId, tradeId, amount / 2);

        // verify
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, alice);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 0);
        assertEq(trade.duration, 0);
        assertEq(trade.currency, address(mock));
        assertEq(trade.amount, amount / 2);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        assertEq(
            bulletin.balanceOf(
                alice,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.RESPONSE,
                    uint40(requestId),
                    uint40(tradeId)
                )
            ),
            ++aliceNumberOfBulletinToken
        );
        assertEq(mock.balanceOf(address(bulletin)), amount);

        IBulletin.Credit memory c = bulletin.getCredit(owner);
        assertEq(c.amount, amount * 15);
    }

    function test_ApproveWithCredit_ResponseWithPromise(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

        // setup request
        uint256 requestId = postRequestWithCredit(owner, 10 ether, amount);

        // setup trade
        uint256 tradeId = postTradeWithPromise(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            TEST,
            BYTES
        );

        uint256 aliceNumberOfBulletinToken = bulletin.balanceOf(
            alice,
            bulletin.encodeTokenId(
                address(bulletin),
                IBulletin.TradeType.RESPONSE,
                uint40(requestId),
                uint40(tradeId)
            )
        );

        // approve trade
        approveTradeToRequest(owner, requestId, tradeId, amount);

        // verify
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, alice);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 0);
        assertEq(trade.duration, 0);
        assertEq(trade.currency, address(0xc0d));
        assertEq(trade.amount, amount);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        assertEq(
            bulletin.balanceOf(
                alice,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.RESPONSE,
                    uint40(requestId),
                    uint40(tradeId)
                )
            ),
            ++aliceNumberOfBulletinToken
        );
    }

    function test_ApproveWithCredit_ResponseWithPromise_TwoApprovals(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

        // setup request
        uint256 requestId = postRequestWithCredit(owner, 10 ether, amount);

        // setup first trade
        uint256 tradeId = postTradeWithPromise(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            TEST,
            BYTES
        );
        uint256 aliceNumberOfBulletinToken = bulletin.balanceOf(
            alice,
            bulletin.encodeTokenId(
                address(bulletin),
                IBulletin.TradeType.RESPONSE,
                uint40(requestId),
                uint40(tradeId)
            )
        );

        // approve first trade
        approveTradeToRequest(owner, requestId, tradeId, amount / 2);

        // verify
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, alice);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 0);
        assertEq(trade.duration, 0);
        assertEq(trade.currency, address(0xc0d));
        assertEq(trade.amount, amount / 2);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        assertEq(
            bulletin.balanceOf(
                alice,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.RESPONSE,
                    uint40(requestId),
                    uint40(tradeId)
                )
            ),
            ++aliceNumberOfBulletinToken
        );

        // setup second trade
        uint256 tradeId2 = postTradeWithPromise(
            IBulletin.TradeType.RESPONSE,
            bob,
            requestId,
            TEST2,
            BYTES2
        );

        uint256 bobNumberOfBulletinToken = bulletin.balanceOf(
            bob,
            bulletin.encodeTokenId(
                address(bulletin),
                IBulletin.TradeType.RESPONSE,
                uint40(requestId),
                uint40(tradeId2)
            )
        );

        // approve second trades
        approveTradeToRequest(owner, requestId, tradeId2, amount / 2);

        // verify
        trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId2
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, bob);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 0);
        assertEq(trade.duration, 0);
        assertEq(trade.currency, address(0xc0d));
        assertEq(trade.amount, amount / 2);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST2);
        assertEq(trade.data, BYTES2);

        assertEq(
            bulletin.balanceOf(
                bob,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.RESPONSE,
                    uint40(requestId),
                    uint40(tradeId2)
                )
            ),
            ++bobNumberOfBulletinToken
        );
    }

    function test_ApproveWithCredit_ResponseWithCurrency(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

        // setup request
        uint256 requestId = postRequestWithCredit(owner, 10 ether, amount);

        // setup first trade
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(mock),
            amount * 15
        );
        uint256 aliceNumberOfBulletinToken = bulletin.balanceOf(
            alice,
            bulletin.encodeTokenId(
                address(bulletin),
                IBulletin.TradeType.RESPONSE,
                uint40(requestId),
                uint40(tradeId)
            )
        );

        // approve first trade
        approveTradeToRequest(owner, requestId, tradeId, amount / 2);

        // verify
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, alice);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 0);
        assertEq(trade.duration, 0);
        assertEq(trade.currency, address(0xc0d));
        assertEq(trade.amount, amount / 2);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        assertEq(
            bulletin.balanceOf(
                alice,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.RESPONSE,
                    uint40(requestId),
                    uint40(tradeId)
                )
            ),
            ++aliceNumberOfBulletinToken
        );
        assertEq(mock.balanceOf(address(bulletin)), 0);
        assertEq(mock.balanceOf(owner), amount * 15);
    }

    function test_ApproveWithCredit_ResponseWithCredit(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

        // setup request
        uint256 requestId = postRequestWithCredit(owner, 10 ether, amount);

        // setup first trade
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(0xc0d),
            amount * 15
        );
        uint256 aliceNumberOfBulletinToken = bulletin.balanceOf(
            alice,
            bulletin.encodeTokenId(
                address(bulletin),
                IBulletin.TradeType.RESPONSE,
                uint40(requestId),
                uint40(tradeId)
            )
        );

        // approve first trade
        approveTradeToRequest(owner, requestId, tradeId, amount / 2);

        // verify
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 0);
        assertEq(trade.duration, 0);
        assertEq(trade.from, alice);
        assertEq(trade.currency, address(0xc0d));
        assertEq(trade.amount, amount / 2);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        assertEq(
            bulletin.balanceOf(
                alice,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.RESPONSE,
                    uint40(requestId),
                    uint40(tradeId)
                )
            ),
            ++aliceNumberOfBulletinToken
        );

        IBulletin.Credit memory c = bulletin.getCredit(owner);
        assertEq(c.amount, amount * 15 + 10 ether - amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Resource.                                 */
    /* -------------------------------------------------------------------------- */

    function test_Approve_ExchangeWithPromise(uint256 amount) public payable {
        vm.assume(amount > 0);
        vm.assume(20 ether > amount);

        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithPromise(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            TEST2,
            BYTES2
        );

        approveTradeForResource(owner, resourceId, tradeId, 1 weeks);
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 1);
        assertEq(trade.duration, 1 weeks);
        assertEq(trade.from, alice);
        assertEq(trade.resource, 0);
        assertEq(trade.currency, address(0));
        assertEq(trade.amount, 0);
        assertEq(trade.content, TEST2);
        assertEq(trade.data, BYTES2);

        assertEq(
            bulletin.balanceOf(
                owner,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.EXCHANGE,
                    uint40(resourceId),
                    uint40(tradeId)
                )
            ),
            1
        );
        assertEq(
            bulletin.balanceOf(
                alice,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.EXCHANGE,
                    uint40(resourceId),
                    uint40(tradeId)
                )
            ),
            1
        );
    }

    function test_Approve_ExchangeWithResource(uint256 amount) public payable {
        vm.assume(amount > 0);
        vm.assume(20 ether > amount);

        uint256 resourceId = postResource(owner);
        uint256 resourceId2 = postResource(alice);
        uint256 tradeId = postTradeWithResource(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            address(bulletin),
            resourceId2
        );

        approveTradeForResource(owner, resourceId, tradeId, 1 weeks);
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 1);
        assertEq(trade.duration, 1 weeks);
        assertEq(trade.from, alice);
        assertEq(
            trade.resource,
            bulletin.encodeAsset(address(bulletin), uint96(resourceId2))
        );
        assertEq(trade.currency, address(0));
        assertEq(trade.amount, 0);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        assertEq(
            bulletin.balanceOf(
                owner,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.EXCHANGE,
                    uint40(resourceId),
                    uint40(tradeId)
                )
            ),
            1
        );
        assertEq(
            bulletin.balanceOf(
                alice,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.EXCHANGE,
                    uint40(resourceId),
                    uint40(tradeId)
                )
            ),
            1
        );
    }

    function test_Approve_ExchangeWithCredit(uint256 amount) public payable {
        vm.assume(amount > 0);
        vm.assume(20 ether > amount);

        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            address(0xc0d),
            amount
        );

        approveTradeForResource(owner, resourceId, tradeId, 1 weeks);
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 1);
        assertEq(trade.duration, 1 weeks);
        assertEq(trade.from, alice);
        assertEq(trade.resource, 0);
        assertEq(trade.currency, address(0xc0d));
        assertEq(trade.amount, amount);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        assertEq(
            bulletin.balanceOf(
                owner,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.EXCHANGE,
                    uint40(resourceId),
                    uint40(tradeId)
                )
            ),
            1
        );
        assertEq(
            bulletin.balanceOf(
                alice,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.EXCHANGE,
                    uint40(resourceId),
                    uint40(tradeId)
                )
            ),
            1
        );
    }

    function test_Approve_ExchangeWithCurrency(uint256 amount) public payable {
        vm.assume(amount > 0);
        vm.assume(20 ether > amount);

        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            address(mock),
            amount
        );

        approveTradeForResource(owner, resourceId, tradeId, 1 weeks);
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 1);
        assertEq(trade.duration, 1 weeks);
        assertEq(trade.from, alice);
        assertEq(trade.resource, 0);
        assertEq(trade.currency, address(mock));
        assertEq(trade.amount, amount);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        assertEq(
            bulletin.balanceOf(
                owner,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.EXCHANGE,
                    uint40(resourceId),
                    uint40(tradeId)
                )
            ),
            1
        );
        assertEq(
            bulletin.balanceOf(
                alice,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.EXCHANGE,
                    uint40(resourceId),
                    uint40(tradeId)
                )
            ),
            1
        );
    }
}
