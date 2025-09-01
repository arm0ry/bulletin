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

contract BulletinTest_Withdraw is Test, BulletinTest {
    function test_Withdraw_PostRequestWithCredit(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

        uint256 requestId = postRequestWithCredit(owner, 10 ether, amount);

        withdrawRequest(owner, requestId);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);
        assertEq(_request.from, address(0));
        assertEq(_request.data, "");
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, 0);

        IBulletin.Credit memory credit = bulletin.getCredit(owner);
        assertEq(credit.amount, 10 ether);
    }

    function test_Withdraw_PostRequestWithCurrency(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);
        uint256 requestId = postRequestWithCurrency(owner, 10 ether, amount);

        withdrawRequest(owner, requestId);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);
        assertEq(_request.from, address(0));
        assertEq(_request.data, "");
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, 0);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(owner), 10 ether);
    }

    // todo: asserts
    function test_withdraw_InvalidOriginalPoster() public payable {}

    // todo: asserts
    function test_withdraw_InvalidWithdrawal() public payable {}

    function test_Withdraw_Resource() public payable {
        activate(address(bulletin), owner, owner, 10 ether);
        uint256 resourceId = postResource(owner);
        withdrawResource(owner, resourceId);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        assertEq(_resource.from, address(0));
        assertEq(_resource.data, "");
        assertEq(_resource.uri, "");
    }

    function test_Withdraw_TradeForResource(uint256 amount) public payable {
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

        withdrawExchange(bob, resourceId, exchangeId);

        uint256 id = bulletin.getUnapprovedTradeIdByUser(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            bob
        );
        assertEq(id, 0);

        trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            exchangeId
        );
        assertEq(trade.approved, false);
        assertEq(trade.from, address(0));
        assertEq(trade.currency, address(0));
        assertEq(trade.amount, 0);
        assertEq(mock.balanceOf(bob), amount);
        assertEq(mock.balanceOf(address(bulletin)), 0);
    }

    function test_Withdraw_PostResponseWithResource(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

        // setup request
        uint256 requestId = postRequestWithCurrency(owner, 10 ether, amount);

        // setup resource
        activate(address(bulletin), owner, alice, 10 ether);
        uint256 resourceId = postResource(alice);

        // setup trade
        uint256 responseId = setupResourceResponse(
            alice,
            requestId,
            address(bulletin),
            resourceId
        );

        withdrawResponse(alice, requestId, responseId);

        uint256 id = bulletin.getUnapprovedTradeIdByUser(
            IBulletin.TradeType.RESPONSE,
            requestId,
            alice
        );
        assertEq(id, 0);

        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            responseId
        );
        assertEq(trade.approved, false);
        assertEq(trade.from, address(0));
        assertEq(trade.currency, address(0));
        assertEq(trade.amount, 0);
        assertEq(trade.resource, 0);
        assertEq(trade.content, "");
        assertEq(trade.data, bytes(string("")));
    }
}
