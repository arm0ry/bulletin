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
    /* -------------------------------------------------------------------------- */
    /*                                   Claim.                                   */
    /* -------------------------------------------------------------------------- */

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
}
