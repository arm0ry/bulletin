// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {BulletinTest} from "test/bulletin/Bulletin_Setup.t.sol";
import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";
import {BERC6909} from "src/BERC6909.sol";

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

    function test_ClaimCurrency_RequestDrop(uint256 amount) public payable {
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

        // approve first trade
        approveTradeToRequest(owner, requestId, tradeId, amount / 2);

        vm.prank(alice);
        bulletin.claim(IBulletin.TradeType.RESPONSE, requestId, tradeId);

        assertEq(mock.balanceOf(alice), amount / 2);
    }

    function test_ClaimCurrency_RequestDrop_TwoApprovals(
        uint256 amount
    ) public payable {
        vm.assume(20 ether > amount);
        vm.assume(amount > 10_000);

        // setup request with currency
        uint256 requestId = postRequestWithCurrency(owner, amount, amount);

        // setup trades
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(0xc0d),
            amount * 15
        );
        uint256 tradeId2 = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            bob,
            requestId,
            address(0xc0d),
            amount * 5
        );

        // approve trades
        approveTradeToRequest(owner, requestId, tradeId, amount / 2);
        approveTradeToRequest(owner, requestId, tradeId2, amount / 3);

        vm.prank(alice);
        bulletin.claim(IBulletin.TradeType.RESPONSE, requestId, tradeId);
        assertEq(mock.balanceOf(alice), amount / 2);

        vm.prank(bob);
        bulletin.claim(IBulletin.TradeType.RESPONSE, requestId, tradeId2);
        assertEq(mock.balanceOf(bob), amount / 3);

        assertEq(
            mock.balanceOf(address(bulletin)),
            amount - amount / 2 - amount / 3
        );
    }

    function test_ClaimCredit_RequestDrop(uint256 amount) public payable {
        vm.assume(20 ether > amount);
        vm.assume(amount > 10_000);

        // setup request with currency
        uint256 requestId = postRequestWithCredit(owner, amount, amount);

        // setup trade
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(0xc0d),
            amount * 15
        );

        // approve trade
        approveTradeToRequest(owner, requestId, tradeId, amount / 2);

        vm.prank(alice);
        bulletin.claim(IBulletin.TradeType.RESPONSE, requestId, tradeId);

        IBulletin.Credit memory c = bulletin.getCredit(alice);
        assertEq(c.amount, amount / 2);
    }

    function test_ClaimCredit_RequestDrop_TwoApprovals(
        uint256 amount
    ) public payable {
        vm.assume(20 ether > amount);
        vm.assume(amount > 10_000);

        // setup request with currency
        uint256 requestId = postRequestWithCredit(owner, amount, amount);

        // setup trades
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            alice,
            requestId,
            address(0xc0d),
            amount * 15
        );
        uint256 tradeId2 = postTradeWithCurrency(
            IBulletin.TradeType.RESPONSE,
            bob,
            requestId,
            address(0xc0d),
            amount * 5
        );

        // approve trades
        approveTradeToRequest(owner, requestId, tradeId, amount / 2);
        approveTradeToRequest(owner, requestId, tradeId2, amount / 3);

        vm.prank(alice);
        bulletin.claim(IBulletin.TradeType.RESPONSE, requestId, tradeId);
        IBulletin.Credit memory c = bulletin.getCredit(alice);
        assertEq(c.amount, amount / 2);

        vm.prank(bob);
        bulletin.claim(IBulletin.TradeType.RESPONSE, requestId, tradeId2);
        c = bulletin.getCredit(bob);
        assertEq(c.amount, amount / 3);
    }

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
        vm.assume(timestamp > duration + uint40(block.timestamp));

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
        vm.assume(timestamp > duration + uint40(block.timestamp));

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

    /* -------------------------------------------------------------------------- */
    /*                                   Pause.                                   */
    /* -------------------------------------------------------------------------- */

    function test_PauseBeforeExpiration(
        bool creditTrade,
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
            creditTrade ? address(0xc0d) : address(mock),
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
        vm.warp(timestamp);
        vm.prank(owner);
        bulletin.pause(resourceId, tradeId);

        // verify
        if (creditTrade) {
            IBulletin.Credit memory c = bulletin.getCredit(owner);
            assertEq(c.limit, 0);
            assertEq(c.amount, amountStreamed);
        } else {
            assertEq(mock.balanceOf(owner), amountStreamed);
        }

        trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        assertEq(trade.paused, true);
        assertEq(trade.amount, amount - amountStreamed);
        assertEq(trade.duration, remainingTime);

        uint256 tokenId = bulletin.encodeTokenId(
            address(bulletin),
            IBulletin.TradeType.EXCHANGE,
            uint40(resourceId),
            uint40(tradeId)
        );

        vm.expectRevert(IBulletin.TradePaused.selector);
        vm.prank(owner);
        bulletin.transfer(alice, tokenId, 1);

        vm.expectRevert(IBulletin.TradePaused.selector);
        vm.prank(alice);
        bulletin.transfer(owner, tokenId, 1);
    }

    function test_PauseBeforeExpiration_Unpause(
        bool creditTrade,
        uint256 amount,
        uint40 timestamp,
        uint40 timestamp2
    ) public payable {
        // data setup
        uint40 duration = 1 weeks;
        vm.assume(amount > 0);
        vm.assume(20 ether > amount);
        vm.assume(timestamp > 0);
        vm.assume(duration > timestamp);
        vm.assume(timestamp2 > timestamp);

        // pre-claim flow
        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            creditTrade ? address(0xc0d) : address(mock),
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

        // pause
        vm.prank(owner);
        bulletin.pause(resourceId, tradeId);

        // unpause
        vm.warp(timestamp2);
        vm.prank(owner);
        bulletin.pause(resourceId, tradeId);

        uint256 tokenId = bulletin.encodeTokenId(
            address(bulletin),
            IBulletin.TradeType.EXCHANGE,
            uint40(resourceId),
            uint40(tradeId)
        );

        // verify
        assertEq(bulletin.balanceOf(owner, tokenId), 1);
        assertEq(bulletin.balanceOf(alice, tokenId), 1);

        trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        assertEq(trade.paused, false);
        assertEq(trade.amount, amount - amountStreamed);
        assertEq(trade.duration, remainingTime);
        assertEq(trade.timestamp, timestamp2);

        vm.prank(owner);
        bulletin.approve(owner, tokenId, 100);
        vm.prank(owner);
        bulletin.transfer(alice, tokenId, 1);
        assertEq(bulletin.balanceOf(alice, tokenId), 2);

        vm.prank(alice);
        bulletin.approve(alice, tokenId, 2);
        vm.prank(alice);
        bulletin.transferFrom(alice, owner, tokenId, 2);
        assertEq(bulletin.balanceOf(owner, tokenId), 2);
    }

    function test_PauseAfterExpiration(
        bool creditTrade,
        uint256 amount,
        uint40 timestamp
    ) public payable {
        // data setup
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
            creditTrade ? address(0xc0d) : address(mock),
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
        (uint256 amountStreamed, ) = calculateAmountStreamedAndRemainingTime(
            timestamp,
            trade.timestamp,
            trade.duration,
            trade.amount
        );
        assertEq(trade.amount, amountStreamed);

        // claim
        vm.prank(owner);
        bulletin.pause(resourceId, tradeId);

        // verify
        uint256 tokenId = bulletin.encodeTokenId(
            address(bulletin),
            IBulletin.TradeType.EXCHANGE,
            uint40(resourceId),
            uint40(tradeId)
        );

        if (creditTrade) {
            IBulletin.Credit memory c = bulletin.getCredit(owner);
            assertEq(c.limit, 0);
            assertEq(c.amount, amountStreamed);
        } else {
            assertEq(mock.balanceOf(owner), amountStreamed);
        }

        assertEq(bulletin.balanceOf(owner, tokenId), 1);
        assertEq(bulletin.balanceOf(alice, tokenId), 1);

        trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        assertEq(trade.amount, 0);
        assertEq(trade.duration, 0);

        vm.expectRevert(IBulletin.TradePaused.selector);
        vm.prank(owner);
        bulletin.transfer(alice, tokenId, 1);

        vm.expectRevert(IBulletin.TradePaused.selector);
        vm.prank(alice);
        bulletin.transfer(owner, tokenId, 1);
    }

    function test_PauseAfterExpiration_Unpause(
        bool creditTrade,
        uint256 amount,
        uint40 timestamp,
        uint40 timestamp2
    ) public payable {
        // data setup
        uint40 duration = 1 weeks;
        vm.assume(amount > 0);
        vm.assume(20 ether > amount);
        vm.assume(timestamp > duration);
        vm.assume(timestamp2 > timestamp);

        // pre-claim flow
        uint256 resourceId = postResource(owner);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.EXCHANGE,
            alice,
            resourceId,
            creditTrade ? address(0xc0d) : address(mock),
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
        bulletin.pause(resourceId, tradeId);

        // pause
        vm.warp(timestamp2);
        vm.prank(owner);
        bulletin.pause(resourceId, tradeId);

        uint256 tokenId = bulletin.encodeTokenId(
            address(bulletin),
            IBulletin.TradeType.EXCHANGE,
            uint40(resourceId),
            uint40(tradeId)
        );

        // verify
        trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            tradeId
        );
        assertEq(trade.paused, false);
        assertEq(trade.amount, amount - amountStreamed);
        assertEq(trade.duration, remainingTime);
        assertEq(trade.timestamp, timestamp);

        vm.prank(owner);
        bulletin.approve(owner, tokenId, 100);
        vm.prank(owner);
        bulletin.transfer(alice, tokenId, 1);
        assertEq(bulletin.balanceOf(alice, tokenId), 2);

        vm.prank(alice);
        bulletin.approve(alice, tokenId, 2);
        vm.prank(alice);
        bulletin.transferFrom(alice, owner, tokenId, 2);
        assertEq(bulletin.balanceOf(owner, tokenId), 2);

        vm.prank(owner);
        vm.expectRevert(IBulletin.Denied.selector);
        bulletin.access(resourceId, tradeId);
    }
}
