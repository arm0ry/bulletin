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

        IBulletin.Trade memory _trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        assertEq(_trade.approved, true);
        assertEq(_trade.from, alice);
        assertEq(_trade.currency, address(mock));
        assertEq(_trade.amount, amount);
        assertEq(_trade.resource, 0);
        assertEq(_trade.content, TEST);
        assertEq(_trade.data, BYTES);

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

    function test_Approve_ExchangeWithCurrency_ByVendor(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 10_000);

        mock.mint(bob, amount);

        activate(address(bulletin), owner, alice, 10 ether);
        uint256 resourceId = postResource(alice);
        uint256 exchangeId = setupCurrencyExchange(
            bob,
            resourceId,
            address(mock),
            amount
        );

        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            exchangeId
        );
        assertEq(trade.approved, false);
        assertEq(trade.from, bob);
        assertEq(trade.currency, address(mock));
        assertEq(trade.amount, amount);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);
        assertEq(mock.balanceOf(bob), 0);
        assertEq(mock.balanceOf(address(bulletin)), amount);

        // Approve exchange.
        approveTradeForResource(alice, resourceId, exchangeId);

        // Vendor claim and receive currency.
        vm.prank(alice);
        bulletin.claim(IBulletin.TradeType.EXCHANGE, resourceId, exchangeId);

        trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            exchangeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, bob);
        assertEq(trade.currency, address(0));
        assertEq(trade.amount, 0);
        assertEq(mock.balanceOf(alice), amount);
        assertEq(mock.balanceOf(address(bulletin)), 0);
    }

    function test_Approve_ExchangeWithCredit_ByMember(
        uint256 amount
    ) public payable {
        vm.assume(5 ether > amount);
        vm.assume(amount > 10_000);

        IBulletin.Credit memory credit = bulletin.getCredit(alice);
        assertEq(credit.limit, 0 ether);
        assertEq(credit.amount, 0 ether);

        activate(address(bulletin), owner, alice, 10 ether);
        activate(address(bulletin), owner, bob, 10 ether);

        // Bob trades with Alice by spending credits.
        uint256 resourceId = postResource(alice);
        uint256 exchangeId = setupCreditExchange(bob, resourceId, amount);

        credit = bulletin.getCredit(bob);
        assertEq(credit.limit, 10 ether);
        assertEq(credit.amount, 10 ether - amount);

        approveTradeForResource(alice, resourceId, exchangeId);

        vm.prank(alice);
        bulletin.claim(IBulletin.TradeType.EXCHANGE, resourceId, exchangeId);

        credit = bulletin.getCredit(alice);
        assertEq(credit.limit, 10 ether);
        assertEq(credit.amount, 10 ether + amount);
    }

    function test_Approve_ExchangeForResource_BuildCredit(
        uint256 amount
    ) public payable {
        vm.assume(5 ether > amount);
        vm.assume(amount > 10_000);

        // Bob buys Alice's resource with credits.
        test_Approve_ExchangeWithCredit_ByMember(2 ether);

        IBulletin.Credit memory credit = bulletin.getCredit(bob);
        assertEq(credit.limit, 10 ether);
        assertEq(credit.amount, 8 ether);

        // Alice buys Bob's resource with credits.
        uint256 resourceId = postResource(bob);
        uint256 exchangeId = setupCreditExchange(alice, resourceId, amount);
        approveTradeForResource(bob, resourceId, exchangeId);

        vm.prank(bob);
        bulletin.claim(IBulletin.TradeType.EXCHANGE, resourceId, exchangeId);

        credit = bulletin.getCredit(bob);
        assertEq(credit.amount, 8 ether + amount);
        credit = bulletin.getCredit(alice);
        assertEq(credit.limit, 10 ether);
        assertEq(credit.amount, 12 ether - amount);
    }

    function test_Approve_ExchangeForResource_AmountGrtrThanLimit(
        uint256 amount
    ) public payable {
        vm.assume(5 ether > amount);
        vm.assume(amount > 10_000);

        // Bob buys Alice's resource with credits.
        test_Approve_ExchangeWithCredit_ByMember(4 ether);

        // Alice is penalized with credit limit slashed.
        // Alice now has more credit than limit allows.
        vm.prank(owner);
        Bulletin(address(bulletin)).adjust(alice, 2 ether);

        // When penalized, credit amount normalizes/decreases by the amount of reduction in credit limit.
        IBulletin.Credit memory credit = bulletin.getCredit(alice);
        assertEq(credit.limit, 2 ether);
        assertEq(credit.amount, 6 ether);

        activate(address(bulletin), owner, charlie, 5 ether);

        // Alice can still use credits to buy Bob's resource.
        uint256 resourceId = postResource(bob);
        uint256 exchangeId = setupCreditExchange(alice, resourceId, amount);
        approveTradeForResource(bob, resourceId, exchangeId);

        vm.prank(bob);
        bulletin.claim(IBulletin.TradeType.EXCHANGE, resourceId, exchangeId);

        credit = bulletin.getCredit(bob);
        assertEq(credit.amount, 6 ether + amount);
        credit = bulletin.getCredit(alice);
        assertEq(credit.limit, 2 ether);
        assertEq(credit.amount, 6 ether - amount);

        exchangeId = setupCreditExchange(charlie, 1, amount);
        credit = bulletin.getCredit(charlie);
        assertEq(credit.limit, 5 ether);
        assertEq(credit.amount, 5 ether - amount);

        approveTradeForResource(alice, 1, exchangeId);

        vm.prank(alice);
        bulletin.claim(IBulletin.TradeType.EXCHANGE, 1, exchangeId);

        credit = bulletin.getCredit(alice);
        assertEq(credit.limit, 2 ether);
        assertEq(credit.amount, 6 ether);
    }

    function test_ExchangeForResource_ApproveCurrency(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        activate(address(bulletin), owner, alice, 10 ether);
        uint256 resourceId = postResource(alice);

        mock.mint(bob, amount);
        mockApprove(bob, address(bulletin), amount);
        uint256 exchangeId = setupCurrencyExchange(
            bob,
            resourceId,
            address(mock),
            amount
        );

        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            exchangeId
        );
        assertEq(trade.approved, false);
        assertEq(trade.from, bob);
        assertEq(trade.currency, address(mock));
        assertEq(trade.amount, amount);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);
        assertEq(mock.balanceOf(bob), 0);
        assertEq(mock.balanceOf(address(bulletin)), amount);

        uint256 id = bulletin.getUnapprovedTradeIdByUser(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            bob
        );
        IBulletin.Trade memory _trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            id
        );
        assertEq(id, exchangeId);
        assertEq(_trade.approved, false);
        assertEq(_trade.from, bob);
        assertEq(_trade.currency, address(mock));
        assertEq(_trade.amount, amount);
        assertEq(_trade.resource, 0);
        assertEq(_trade.content, TEST);
        assertEq(_trade.data, BYTES);

        approveTradeForResource(alice, resourceId, exchangeId);

        vm.prank(alice);
        bulletin.claim(IBulletin.TradeType.EXCHANGE, resourceId, exchangeId);

        trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            exchangeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, bob);
        assertEq(trade.currency, address(0));
        assertEq(trade.amount, 0);
        assertEq(mock.balanceOf(alice), amount);
        assertEq(mock.balanceOf(address(bulletin)), 0);
    }

    function test_ExchangeForResource_ApproveResource() public payable {
        activate(address(bulletin), owner, alice, 10 ether);
        activate(address(bulletin), owner, bob, 10 ether);

        uint256 resourceId = postResource(alice);
        uint256 bobResourceId = postResource(bob);
        uint256 exchangeId = setupResourceExchange(
            bob,
            resourceId,
            address(bulletin),
            bobResourceId
        );

        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            exchangeId
        );
        assertEq(trade.approved, false);
        assertEq(trade.from, bob);
        assertEq(trade.currency, address(0));
        assertEq(trade.amount, 0);
        assertEq(
            trade.resource,
            bulletin.encodeAsset(address(bulletin), uint96(bobResourceId))
        );
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        uint256 id = bulletin.getUnapprovedTradeIdByUser(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            bob
        );
        IBulletin.Trade memory _trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            id
        );
        assertEq(id, exchangeId);
        assertEq(_trade.approved, false);
        assertEq(_trade.from, bob);
        assertEq(_trade.currency, address(0));
        assertEq(_trade.amount, 0);
        assertEq(
            _trade.resource,
            bulletin.encodeAsset(address(bulletin), uint96(bobResourceId))
        );
        assertEq(_trade.content, TEST);
        assertEq(_trade.data, BYTES);

        approveTradeForResource(alice, resourceId, exchangeId);
        trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            exchangeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, bob);
        assertEq(trade.currency, address(0));
        assertEq(trade.amount, 0);
    }

    function test_ApproveWithCurrency_ExchangeWithCredit() public payable {}
    function test_ApproveWithCurrency_ExchangeWithCurrency() public payable {}
    function test_ApproveWithCredit_ExchangeWithCurrency() public payable {}
    function test_ApproveWithCredit_ExchangeWithCredit() public payable {}
}
