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

contract BulletinTest_Approve is Test, BulletinTest {
    function test_ApproveCurrencyExchangeForResource_ByVendor(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 10_000);

        mock.mint(bob, amount);

        activate(address(bulletin), owner, alice, 10 ether);
        uint256 resourceId = resource(false, alice);
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

    function test_ApproveCreditExchangeForResource_ByMember(
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
        uint256 resourceId = resource(false, alice);
        uint256 exchangeId = setupCreditExchange(bob, resourceId, amount);

        credit = bulletin.getCredit(bob);
        assertEq(credit.limit, 10 ether);
        assertEq(credit.amount, 10 ether - amount);

        approveTradeForResource(alice, resourceId, exchangeId);

        string memory uri = bulletin.tokenURI(
            bulletin.encodeTokenId(
                address(bulletin),
                IBulletin.TradeType.EXCHANGE,
                uint40(resourceId),
                uint40(exchangeId)
            )
        );

        vm.prank(alice);
        bulletin.claim(IBulletin.TradeType.EXCHANGE, resourceId, exchangeId);

        credit = bulletin.getCredit(alice);
        assertEq(credit.limit, 10 ether);
        assertEq(credit.amount, 10 ether + amount);
    }

    function test_ApproveExchangeForResource_BuildCredit(
        uint256 amount
    ) public payable {
        vm.assume(5 ether > amount);
        vm.assume(amount > 10_000);

        // Bob buys Alice's resource with credits.
        test_ApproveCreditExchangeForResource_ByMember(2 ether);

        IBulletin.Credit memory credit = bulletin.getCredit(bob);
        assertEq(credit.limit, 10 ether);
        assertEq(credit.amount, 8 ether);

        // Alice buys Bob's resource with credits.
        uint256 resourceId = resource(false, bob);
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

    function test_ApproveExchangeForResource_AmountGrtrThanLimit(
        uint256 amount
    ) public payable {
        vm.assume(5 ether > amount);
        vm.assume(amount > 10_000);

        // Bob buys Alice's resource with credits.
        test_ApproveCreditExchangeForResource_ByMember(4 ether);

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
        uint256 resourceId = resource(false, bob);
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
        uint256 resourceId = resource(false, alice);

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

        uint256 resourceId = resource(false, alice);
        uint256 bobResourceId = resource(false, bob);
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

    function test_ResourceResponseToRequest_Approved(
        uint256 amount
    ) public payable {
        mock.mint(owner, 10 ether);
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

        // setup request
        activate(address(bulletin), owner, owner, 10 ether);
        uint256 requestId = requestByCurrency(true, owner, amount);

        // setup resource
        activate(address(bulletin), owner, alice, 10 ether);
        uint256 resourceId = resource(false, alice);

        // setup trade
        uint256 tradeId = setupResourceResponse(
            alice,
            requestId,
            address(bulletin),
            resourceId
        );
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        bool approved = trade.approved;

        // approve trade
        approveTradeToRequest(owner, requestId, tradeId, 0);
        trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );

        assertEq(trade.approved, !approved);
    }

    function test_SimpleResponseToRequest_OneApprovalWithCurrency(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);
        mock.mint(owner, amount);

        // setup request
        activate(address(bulletin), owner, owner, 10 ether);
        uint256 requestId = requestByCurrency(true, owner, amount);

        // setup first trade
        uint256 responseId = setupSimpleResponse(alice, requestId);

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

    function test_SimpleResponseToRequest_TwoApprovalWithCurrency(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);
        mock.mint(owner, amount);

        // setup ask
        activate(address(bulletin), owner, owner, 10 ether);
        uint256 requestId = requestByCurrency(true, owner, amount);

        // grant BULLETIN role
        grantRole(address(bulletin), owner, address(bulletin), BULLETIN_ROLE);

        // setup first trade
        uint256 responseId = setupSimpleResponse(alice, requestId);

        // approve first trade
        approveTradeToRequest(
            owner,
            requestId,
            responseId,
            (amount * 20) / 100
        );

        uint256 tradeId = bulletin.getUnapprovedTradeIdByUser(
            IBulletin.TradeType.RESPONSE,
            requestId,
            alice
        );
        IBulletin.Trade memory _trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        assertEq(tradeId, 0);
        assertEq(tradeId, responseId);
        assertEq(_trade.approved, true);
        assertEq(_trade.from, alice);
        assertEq(_trade.currency, address(mock));
        assertEq(_trade.amount, (amount * 20) / 100);
        assertEq(_trade.resource, 0);
        assertEq(_trade.content, TEST);
        assertEq(_trade.data, BYTES);

        // setup second trade
        responseId = setupSimpleResponse(bob, requestId);

        tradeId = bulletin.getUnapprovedTradeIdByUser(
            IBulletin.TradeType.RESPONSE,
            requestId,
            bob
        );
        _trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        assertEq(tradeId, 2);

        // approve second trade
        approveTradeToRequest(
            owner,
            requestId,
            responseId,
            (amount * 20) / 100
        );

        vm.prank(bob);
        bulletin.claim(IBulletin.TradeType.RESPONSE, requestId, responseId);

        assertEq(
            MockERC20(mock).balanceOf(address(bulletin)),
            amount - (amount * 20) / 100
        );
        assertEq(MockERC20(mock).balanceOf(alice), 0);
        assertEq(MockERC20(mock).balanceOf(bob), (amount * 20) / 100);

        tradeId = bulletin.getUnapprovedTradeIdByUser(
            IBulletin.TradeType.RESPONSE,
            requestId,
            bob
        );
        _trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        assertEq(tradeId, 0);
        assertEq(tradeId, responseId);
        assertEq(_trade.approved, true);
        assertEq(_trade.from, bob);
        assertEq(_trade.currency, address(0));
        assertEq(_trade.amount, 0);
        assertEq(_trade.resource, 0);
        assertEq(_trade.content, TEST);
        assertEq(_trade.data, BYTES);
    }
}
