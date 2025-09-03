// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {BulletinTest} from "test/bulletin/Bulletin_Setup.t.sol";
import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract BulletinTest_Engage is Test, BulletinTest {
    function calculateAmountStreamedAndRemainingTime(
        uint40 blockTimeStamp,
        uint40 tradeTimeStamp,
        uint40 duration,
        uint256 tradeAmount
    ) internal pure returns (uint256 amountStreamed, uint40 remainingTime) {
        uint40 timeStreamed = blockTimeStamp - tradeTimeStamp;
        amountStreamed = ((tradeAmount * 100 * timeStreamed) / duration) / 100;
        if (timeStreamed > duration) remainingTime = 0;
        else remainingTime = duration - timeStreamed;
        if (amountStreamed > tradeAmount) amountStreamed = tradeAmount;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Access.                                  */
    /* -------------------------------------------------------------------------- */

    function test_AccessResource() public payable {
        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithPromise(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            TEST2,
            BYTES2
        );
        approveTradeForResource(owner, resourceId, tradeId, 1 weeks);

        vm.prank(alice);
        vm.expectEmit(address(bulletin));
        emit IBulletin.Accessed(resourceId, tradeId);
        bulletin.access(resourceId, tradeId);
    }

    function testRevert_Access_Unauthorized() public payable {
        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithPromise(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            TEST2,
            BYTES2
        );

        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        bulletin.access(resourceId, tradeId);
    }

    function testRevert_Access_ExpiredDenied(uint40 timestamp) public payable {
        uint40 duration = 1 weeks;

        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithPromise(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            TEST2,
            BYTES2
        );

        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        vm.assume(timestamp > duration + trade.timestamp);
        approveTradeForResource(owner, resourceId, tradeId, duration);

        vm.warp(timestamp);
        vm.prank(alice);
        vm.expectRevert(IBulletin.Denied.selector);
        bulletin.access(resourceId, tradeId);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Claim Request Drop.                            */
    /* -------------------------------------------------------------------------- */

    function test_ClaimCurrency_RequestDrop() public payable {}
    function test_ClaimCredit_RequestDrop() public payable {}

    /* -------------------------------------------------------------------------- */
    /*                      Claim Resource Currency Payment.                      */
    /* -------------------------------------------------------------------------- */

    function test_ClaimCurrency_ResourcePayment(
        uint256 amount,
        uint40 timestamp
    ) public payable {
        // data setup
        uint40 duration = 1 weeks;
        vm.assume(amount > 0);
        vm.assume(20 ether > amount);
        vm.assume(timestamp > 0);
        vm.assume(duration > timestamp);

        // pre-claim flow
        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            address(mock),
            amount
        );
        approveTradeForResource(owner, resourceId, tradeId, duration);

        // verification prep
        vm.warp(timestamp);
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        (
            uint256 amountStreamed,
            uint40 remainingTime
        ) = calculateAmountStreamedAndRemainingTime(
                timestamp,
                trade.timestamp,
                trade.duration,
                trade.amount
            );

        // claim
        vm.prank(owner);
        bulletin.claim(IBulletin.TradeType.EXCHANGE, resourceId, tradeId);

        // verify
        assertEq(mock.balanceOf(owner), amountStreamed);

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

        trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        assertEq(trade.amount, amount - amountStreamed);
        assertEq(trade.duration, remainingTime);
        assertEq(trade.timestamp, timestamp);
    }

    function test_MultiClaimCurrency_ResourcePayment(
        uint256 amount,
        uint8 interval
    ) public payable {
        // data prep
        uint40 duration = 1 weeks;
        vm.assume(amount > 0);
        vm.assume(20 ether > amount);
        vm.assume(interval > 3);
        vm.assume(10 > interval);
        uint40 timeInterval = duration / interval;

        // pre-claim flow
        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            address(mock),
            amount
        );
        approveTradeForResource(owner, resourceId, tradeId, duration);

        uint40 timestamp;
        for (uint256 i; i < interval; i++) {
            // verification prep
            uint256 preWarpCreditAmount = mock.balanceOf(owner);
            IBulletin.Trade memory trade = bulletin.getTrade(
                IBulletin.TradeType.EXCHANGE,
                resourceId,
                tradeId
            );
            uint256 preWarpTradeAmount = trade.amount;

            // warp
            timestamp = uint40(block.timestamp) + timeInterval;
            vm.warp(timestamp);

            (
                uint256 amountStreamed,
                uint40 remainingTime
            ) = calculateAmountStreamedAndRemainingTime(
                    timestamp,
                    trade.timestamp,
                    trade.duration,
                    trade.amount
                );

            // claim
            vm.prank(owner);
            bulletin.claim(IBulletin.TradeType.EXCHANGE, resourceId, tradeId);

            // verify
            assertEq(
                mock.balanceOf(owner),
                preWarpCreditAmount + amountStreamed
            );

            trade = bulletin.getTrade(
                IBulletin.TradeType.EXCHANGE,
                resourceId,
                tradeId
            );
            assertEq(trade.amount, preWarpTradeAmount - amountStreamed);
            assertEq(trade.duration, remainingTime);
            assertEq(trade.timestamp, timestamp);
        }

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

    function test_ClaimCurrencyAfterExpiration_ResourcePayment(
        uint256 amount,
        uint40 timestamp
    ) public payable {
        // data prep
        uint40 duration = 1 weeks;
        vm.assume(amount > 0);
        vm.assume(20 ether > amount);
        vm.assume(timestamp > duration);

        // pre-claim flow
        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            address(mock),
            amount
        );
        approveTradeForResource(owner, resourceId, tradeId, duration);

        // verification prep
        vm.warp(timestamp);
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        (
            uint256 amountStreamed,
            uint40 remainingTime
        ) = calculateAmountStreamedAndRemainingTime(
                timestamp,
                trade.timestamp,
                trade.duration,
                trade.amount
            );

        // claim
        vm.prank(owner);
        bulletin.claim(IBulletin.TradeType.EXCHANGE, resourceId, tradeId);

        // verify
        assertEq(mock.balanceOf(owner), amountStreamed);

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
            0
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
            0
        );

        trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        assertEq(trade.amount, amount - amountStreamed);
        assertEq(trade.duration, remainingTime);
        assertEq(trade.timestamp, timestamp);
    }

    /* -------------------------------------------------------------------------- */
    /*                       Claim Resource Credit Payment.                       */
    /* -------------------------------------------------------------------------- */

    function test_ClaimCredit_ResourcePayment(
        uint256 amount,
        uint40 timestamp
    ) public payable {
        // data setup
        uint40 duration = 1 weeks;
        vm.assume(amount > 0);
        vm.assume(20 ether > amount);
        vm.assume(timestamp > 0);
        vm.assume(duration > timestamp);

        // pre-claim flow
        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            address(0xc0d),
            amount
        );
        approveTradeForResource(owner, resourceId, tradeId, duration);

        // verification prep
        vm.warp(timestamp);
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        (
            uint256 amountStreamed,
            uint40 remainingTime
        ) = calculateAmountStreamedAndRemainingTime(
                timestamp,
                trade.timestamp,
                trade.duration,
                trade.amount
            );

        // claim
        vm.prank(owner);
        bulletin.claim(IBulletin.TradeType.EXCHANGE, resourceId, tradeId);

        // verify
        IBulletin.Credit memory c = bulletin.getCredit(owner);
        assertEq(c.limit, 0);
        assertEq(c.amount, amountStreamed);

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

        trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        assertEq(trade.amount, amount - amountStreamed);
        assertEq(trade.duration, remainingTime);
        assertEq(trade.timestamp, timestamp);
    }

    function test_MultiClaimCredit_ResourcePayment(
        uint256 amount,
        uint8 interval
    ) public payable {
        // data prep
        uint40 duration = 1 weeks;
        vm.assume(amount > 0);
        vm.assume(20 ether > amount);
        vm.assume(interval > 3);
        vm.assume(10 > interval);
        uint40 timeInterval = duration / interval;

        // pre-claim flow
        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            address(0xc0d),
            amount
        );
        approveTradeForResource(owner, resourceId, tradeId, duration);

        uint40 timestamp;
        for (uint256 i; i < interval; i++) {
            // verification prep
            IBulletin.Credit memory c = bulletin.getCredit(owner);
            uint256 preWarpCreditAmount = c.amount;
            IBulletin.Trade memory trade = bulletin.getTrade(
                IBulletin.TradeType.EXCHANGE,
                resourceId,
                tradeId
            );
            uint256 preWarpTradeAmount = trade.amount;

            // warp
            timestamp = uint40(block.timestamp) + timeInterval;
            vm.warp(timestamp);

            (
                uint256 amountStreamed,
                uint40 remainingTime
            ) = calculateAmountStreamedAndRemainingTime(
                    timestamp,
                    trade.timestamp,
                    trade.duration,
                    trade.amount
                );

            // claim
            vm.prank(owner);
            bulletin.claim(IBulletin.TradeType.EXCHANGE, resourceId, tradeId);

            // verify
            c = bulletin.getCredit(owner);
            assertEq(c.amount, preWarpCreditAmount + amountStreamed);

            trade = bulletin.getTrade(
                IBulletin.TradeType.EXCHANGE,
                resourceId,
                tradeId
            );
            assertEq(trade.amount, preWarpTradeAmount - amountStreamed);
            assertEq(trade.duration, remainingTime);
            assertEq(trade.timestamp, timestamp);
        }

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

    function test_ClaimCreditAfterExpiration_ResourcePayment(
        uint256 amount,
        uint40 timestamp
    ) public payable {
        // data prep
        uint40 duration = 1 weeks;
        vm.assume(amount > 0);
        vm.assume(20 ether > amount);
        vm.assume(timestamp > duration);

        // pre-claim flow
        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            address(0xc0d),
            amount
        );
        approveTradeForResource(owner, resourceId, tradeId, duration);

        // verification prep
        vm.warp(timestamp);
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        (
            uint256 amountStreamed,
            uint40 remainingTime
        ) = calculateAmountStreamedAndRemainingTime(
                timestamp,
                trade.timestamp,
                trade.duration,
                trade.amount
            );

        // claim
        vm.prank(owner);
        bulletin.claim(IBulletin.TradeType.EXCHANGE, resourceId, tradeId);

        // verify
        IBulletin.Credit memory c = bulletin.getCredit(owner);
        assertEq(c.limit, 0);
        assertEq(c.amount, amountStreamed);

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
            0
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
            0
        );

        trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        assertEq(trade.amount, amount - amountStreamed);
        assertEq(trade.duration, remainingTime);
        assertEq(trade.timestamp, timestamp);
    }

    function test_ApproveWithCurrency_ResponseWithPromise(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);

        // setup request
        uint256 requestId = postRequestWithCurrency(owner, amount, amount);

        // setup first trade
        uint256 responseId = postTradeWithPromise(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            TEST,
            BYTES
        );

        // approve first trade
        approveTradeToRequest(owner, requestId, responseId, amount);

        vm.prank(alice);
        bulletin.claim(IBulletin.TradeType.RESPONSE, requestId, responseId);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(alice), amount);

        uint256 lastTrade = bulletin.getUnapprovedTradeIdByUser(
            IBulletin.TradeType.RESPONSE,
            requestId,
            alice
        );
        IBulletin.Trade memory _trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            lastTrade
        );

        assertEq(lastTrade, responseId);
        assertEq(_trade.approved, true);
        assertEq(_trade.from, alice);
        assertEq(_trade.currency, address(0));
        assertEq(_trade.amount, 0);
        assertEq(_trade.resource, 0);
        assertEq(_trade.content, TEST);
        assertEq(_trade.data, BYTES);
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

        approveTradeForResource(alice, resourceId, exchangeId, 1 weeks);

        vm.warp(10000000);
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
        approveTradeForResource(bob, resourceId, exchangeId, 1 weeks);

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
        approveTradeForResource(bob, resourceId, exchangeId, 1 weeks);

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

        approveTradeForResource(alice, 1, exchangeId, 1 weeks);

        vm.prank(alice);
        bulletin.claim(IBulletin.TradeType.EXCHANGE, 1, exchangeId);

        credit = bulletin.getCredit(alice);
        assertEq(credit.limit, 2 ether);
        assertEq(credit.amount, 6 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Pause.                                   */
    /* -------------------------------------------------------------------------- */
}
