// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract BulletinTest is Test {
    Bulletin bulletin;
    Bulletin bulletin2;
    Bulletin bulletin3;
    MockERC20 mock;
    MockERC20 mock2;

    /// @dev Mock Users.
    address immutable alice = makeAddr("alice");
    address immutable bob = makeAddr("bob");
    address immutable charlie = makeAddr("charlie");
    address immutable owner = makeAddr("owner");

    /// @dev Roles.
    bytes32 internal constant _OWNER_SLOT =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff74873927;
    uint40 public constant BULLETIN_ROLE = 1 << 0;
    uint40 public constant PERMISSIONED_USER = 1 << 2;

    /// @dev Mock Data.
    uint40 constant PAST = 100000;
    uint40 constant FUTURE = 2527482181;
    string TEST = "TEST";
    string TEST2 = "TEST2";
    bytes constant BYTES = bytes(string("BYTES"));
    bytes constant BYTES2 = bytes(string("BYTES2"));
    uint256 defaultBulletinBalance = 10 ether;

    uint256[] itemIds;

    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        deployBulletin(owner);

        mock = new MockERC20(TEST, TEST, 18);
        mock2 = new MockERC20(TEST2, TEST2, 18);
    }

    function testReceiveETH() public payable {
        (bool sent, ) = address(bulletin).call{value: 5 ether}("");
        assert(sent);
    }

    function deployBulletin(address user) public payable {
        bulletin = new Bulletin();
        bulletin.init(user);
        assertEq(bulletin.owner(), user);
    }

    function deployBulletin2(address user) public payable {
        bulletin2 = new Bulletin();
        bulletin2.init(user);
    }

    function deployBulletin3(address user) public payable {
        bulletin3 = new Bulletin();
        bulletin3.init(user);
    }

    function mockApprove(
        address approver,
        address spender,
        uint256 amount
    ) public payable {
        vm.prank(approver);
        mock.approve(spender, amount);
    }

    function grantRole(
        address _bulletin,
        address _owner,
        address user,
        uint256 role
    ) public payable {
        vm.prank(_owner);
        Bulletin(payable(_bulletin)).grantRoles(user, role);
    }

    /// -----------------------------------------------------------------------
    /// Helpers.
    /// -----------------------------------------------------------------------

    /// @notice Ask

    function ask(
        bool isOwner,
        address user
    ) public payable returns (uint256 id) {
        IBulletin.Request memory a = IBulletin.Request({
            fulfilled: true,
            owner: user,
            title: TEST,
            detail: TEST,
            currency: address(0),
            drop: 0 ether
        });

        vm.prank((isOwner) ? owner : user);
        bulletin.request(a);
        id = bulletin.requestId();
    }

    function askAndDepositEther(
        bool isOwner,
        address user,
        uint256 amount
    ) public payable returns (uint256 id) {
        IBulletin.Request memory a = IBulletin.Request({
            fulfilled: true,
            owner: user,
            title: TEST,
            detail: TEST,
            currency: address(0),
            drop: amount
        });

        vm.prank((isOwner) ? owner : user);
        bulletin.request{value: amount}(a);
        id = bulletin.requestId();
    }

    function askAndDepositCurrency(
        bool isOwner,
        address user,
        uint256 amount
    ) public payable returns (uint256 id) {
        IBulletin.Request memory a = IBulletin.Request({
            fulfilled: true,
            owner: user,
            title: TEST,
            detail: TEST,
            currency: address(mock),
            drop: amount
        });

        mockApprove((isOwner) ? owner : user, address(bulletin), amount);

        vm.prank((isOwner) ? owner : user);
        bulletin.request(a);
        id = bulletin.requestId();
    }

    function withdrawRequest(address op, uint256 requestId) public payable {
        vm.warp(block.timestamp + 10);
        vm.prank(op);
        bulletin.withdrawRequest(requestId);
    }

    /// @notice Resource

    function resource(
        bool isOwner,
        address user
    ) public payable returns (uint256 id) {
        IBulletin.Resource memory r = IBulletin.Resource({
            active: true,
            owner: user,
            title: TEST,
            detail: TEST
        });

        vm.prank((isOwner) ? owner : user);
        bulletin.resource(r);
        id = bulletin.resourceId();
    }

    function withdrawResource(address op, uint256 resourceId) public payable {
        vm.prank(op);
        bulletin.withdrawResource(resourceId);
    }

    function approveTrade(
        address op,
        uint256 requestId,
        uint256 tradeId
    ) public payable {
        vm.prank(op);
        bulletin.approveResponse(requestId, tradeId);
    }

    function settleRequest(
        address op,
        uint40 requestId,
        uint40 role,
        uint16[] memory percentages
    ) public payable {
        vm.prank(op);
        bulletin.settleRequest(requestId, true, role, percentages);
    }

    function setupResourceTrade(
        address user,
        uint256 requestId,
        uint256 responseId,
        address userBulletin,
        uint256 userResourceId
    ) public payable returns (uint256 id) {
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            from: user,
            resource: bulletin.encodeAsset(
                address(userBulletin),
                uint96(userResourceId)
            ),
            currency: address(0),
            amount: 0,
            content: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.respond(requestId, responseId, trade);
        id = bulletin.responseIdsPerRequest(requestId);
    }

    function setupCheckin(
        address user,
        uint256 requestId,
        uint256 responseId
    ) public payable returns (uint256 id) {
        bytes32 r;
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            from: user,
            resource: r,
            currency: address(0),
            amount: 0,
            content: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.respond(requestId, responseId, trade);
        id = bulletin.responseIdsPerRequest(requestId);
    }

    /// -----------------------------------------------------------------------
    /// Tests.
    /// ----------------------------------------------------------------------

    function test_GrantRoles(address user, uint256 role) public payable {
        vm.assume(role > 0);
        grantRole(address(bulletin), owner, user, role);
        assertEq(bulletin.hasAnyRole(user, role), true);
    }

    function test_GrantRoles_NotOwner(
        address user,
        uint256 role
    ) public payable {
        vm.expectRevert(Ownable.Unauthorized.selector);
        bulletin.grantRoles(user, role);
    }

    function test_ask() public payable {
        uint256 requestId = ask(true, owner);
        IBulletin.Request memory _ask = bulletin.getRequest(requestId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);
    }

    function test_askAndDepositCurrency(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        mock.mint(owner, max);
        uint256 requestId = askAndDepositCurrency(true, owner, amount);
        IBulletin.Request memory _ask = bulletin.getRequest(requestId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(mock));
        assertEq(_ask.drop, amount);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), amount);
        assertEq(MockERC20(mock).balanceOf(owner), max - amount);
    }

    function test_askAndDepositEther(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        vm.deal(owner, max);
        uint256 requestId = askAndDepositEther(true, owner, amount);
        IBulletin.Request memory _ask = bulletin.getRequest(requestId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, amount);

        assertEq(address(bulletin).balance, amount);
        assertEq(address(owner).balance, max - amount);
    }

    function test_askByUser() public payable {
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        uint256 requestId = ask(false, alice);
        IBulletin.Request memory _ask = bulletin.getRequest(requestId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, alice);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);
    }

    function test_askAndDepositCurrencyByUser(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        mock.mint(alice, max);
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        uint256 requestId = askAndDepositCurrency(false, alice, amount);
        IBulletin.Request memory _ask = bulletin.getRequest(requestId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, alice);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(mock));
        assertEq(_ask.drop, amount);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), amount);
        assertEq(MockERC20(mock).balanceOf(alice), max - amount);
    }

    function test_askAndDepositEtherByUser(uint256 amount) public payable {
        vm.deal(alice, amount);
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        uint256 requestId = askAndDepositEther(false, alice, amount);
        IBulletin.Request memory _ask = bulletin.getRequest(requestId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, alice);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, amount);

        assertEq(address(bulletin).balance, amount);
        assertEq(address(alice).balance, 0);
    }

    function test_withdraw() public payable {
        uint256 requestId = ask(true, owner);

        withdrawRequest(owner, requestId);

        IBulletin.Request memory _ask = bulletin.getRequest(requestId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, address(0));
        assertEq(_ask.title, "");
        assertEq(_ask.detail, "");
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);
    }

    function test_withdrawAndReturnCurrency(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        mock.mint(owner, max);
        uint256 requestId = askAndDepositCurrency(true, owner, amount);

        withdrawRequest(owner, requestId);

        IBulletin.Request memory _ask = bulletin.getRequest(requestId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, address(0));
        assertEq(_ask.title, "");
        assertEq(_ask.detail, "");
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(owner), max);
    }

    function test_withdrawAndReturnEther(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        vm.deal(owner, max);
        uint256 requestId = askAndDepositEther(true, owner, amount);

        withdrawRequest(owner, requestId);

        IBulletin.Request memory _ask = bulletin.getRequest(requestId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, address(0));
        assertEq(_ask.title, "");
        assertEq(_ask.detail, "");
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);

        assertEq(address(bulletin).balance, 0);
        assertEq(address(owner).balance, max);
    }

    function test_withdrawByUser() public payable {
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        uint256 requestId = ask(false, alice);
        withdrawRequest(alice, requestId);

        IBulletin.Request memory _ask = bulletin.getRequest(requestId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, address(0));
        assertEq(_ask.title, "");
        assertEq(_ask.detail, "");
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);
    }

    function test_withdrawAndReturnCurrencyByUser(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        mock.mint(alice, max);
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        uint256 requestId = askAndDepositCurrency(false, alice, amount);
        withdrawRequest(alice, requestId);

        IBulletin.Request memory _ask = bulletin.getRequest(requestId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, address(0));
        assertEq(_ask.title, "");
        assertEq(_ask.detail, "");
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(alice), max);
    }

    function test_withdrawAndReturnEtherByUser(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        vm.deal(alice, max);
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        uint256 requestId = askAndDepositEther(false, alice, amount);
        withdrawRequest(alice, requestId);

        IBulletin.Request memory _ask = bulletin.getRequest(requestId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, address(0));
        assertEq(_ask.title, "");
        assertEq(_ask.detail, "");
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);

        assertEq(address(bulletin).balance, 0);
        assertEq(address(alice).balance, max);
    }

    // todo: asserts
    function test_withdraw_InvalidOriginalPoster() public payable {}

    // todo: asserts
    function test_withdraw_InvalidWithdrawal() public payable {}

    function test_resource() public payable {
        uint256 resourceId = resource(true, owner);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        assertEq(_resource.active, true);
        assertEq(_resource.owner, owner);
        assertEq(_resource.title, TEST);
        assertEq(_resource.detail, TEST);
    }

    function test_withdrawResource() public payable {
        uint256 resourceId = resource(true, owner);
        withdrawResource(owner, resourceId);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        assertEq(_resource.active, false);
        assertEq(_resource.owner, address(0));
        assertEq(_resource.title, "");
        assertEq(_resource.detail, "");
    }

    function test_resourceByUser() public payable {
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);
        uint256 resourceId = resource(false, alice);

        withdrawResource(alice, resourceId);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        assertEq(_resource.active, false);
        assertEq(_resource.owner, address(0));
        assertEq(_resource.title, "");
        assertEq(_resource.detail, "");
    }

    function test_approveTrade(uint256 max, uint256 amount) public payable {
        mock.mint(owner, max);
        vm.assume(max > amount);

        // setup ask
        uint256 requestId = askAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        // setup resource
        uint256 resourceId = resource(false, alice);

        // setup trade
        uint256 tradeId = setupResourceTrade(
            alice,
            requestId,
            0,
            address(bulletin),
            resourceId
        );
        IBulletin.Trade memory trade = bulletin.getTrade(requestId, tradeId);
        bool approved = trade.approved;

        // approve trade
        approveTrade(owner, requestId, tradeId);
        trade = bulletin.getTrade(requestId, tradeId);

        assertEq(trade.approved, !approved);
    }

    function test_approveTrade_InvalidOriginalPoster(
        uint256 _requestId,
        uint256 _tradeId
    ) public payable {
        vm.prank(owner);
        vm.expectRevert(IBulletin.InvalidOriginalPoster.selector);
        bulletin.approveResponse(_requestId, _tradeId);
    }

    function test_settleRequest_OneCheckin(uint256 amount) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);
        mock.mint(owner, amount);

        // setup ask
        uint256 requestId = askAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        // setup first trade
        uint256 responseId = setupCheckin(alice, requestId, 0);

        // approve first trade
        approveTrade(owner, requestId, responseId);

        // settle ask
        uint16[] memory perc = new uint16[](1);
        perc[0] = 10000;
        settleRequest(
            owner,
            uint40(requestId),
            uint40(PERMISSIONED_USER),
            perc
        );

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(alice), amount);
    }

    function test_settleRequest_TwoCheckins(uint256 amount) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);
        mock.mint(owner, amount);

        // setup ask
        uint256 requestId = askAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);
        grantRole(address(bulletin), owner, bob, PERMISSIONED_USER);

        // grant BULLETIN role
        grantRole(address(bulletin), owner, address(bulletin), BULLETIN_ROLE);

        // setup first trade
        uint256 tradeId = setupCheckin(alice, requestId, 0);

        // approve first trade
        approveTrade(owner, requestId, tradeId);

        // setup second trade
        tradeId = setupCheckin(bob, requestId, 0);

        // approve second trade
        approveTrade(owner, requestId, tradeId);

        uint16[] memory perc = new uint16[](2);
        perc[0] = 6000;
        perc[1] = 4000;
        settleRequest(owner, uint40(requestId), PERMISSIONED_USER, perc);

        assertEq(
            MockERC20(mock).balanceOf(address(bulletin)),
            amount - (amount * 6000) / 10000 - (amount * 4000) / 10000
        );
        assertEq(MockERC20(mock).balanceOf(alice), (amount * 6000) / 10000);
        assertEq(MockERC20(mock).balanceOf(bob), (amount * 4000) / 10000);
    }

    function test_settleRequest_OneTrade(uint256 amount) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);
        mock.mint(owner, amount);

        // setup ask
        uint256 requestId = askAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        // setup first resource
        uint256 resourceId = resource(false, alice);

        // setup first trade
        uint256 tradeId = setupResourceTrade(
            alice,
            requestId,
            0,
            address(bulletin),
            resourceId
        );

        // approve first trade
        approveTrade(owner, requestId, tradeId);

        // settle ask
        uint16[] memory perc = new uint16[](1);
        perc[0] = 10000;
        settleRequest(
            owner,
            uint40(requestId),
            uint40(PERMISSIONED_USER),
            perc
        );

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(alice), amount);

        // uint256 usageId = bulletin.usageIds(resourceId);
        // assertEq(usageId, 1);
    }

    function test_settleRequest_TwoTrades(uint256 amount) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);
        mock.mint(owner, amount);

        // setup ask
        uint256 requestId = askAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);
        grantRole(address(bulletin), owner, bob, PERMISSIONED_USER);

        // grant BULLETIN role
        grantRole(address(bulletin), owner, address(bulletin), BULLETIN_ROLE);

        // setup first resource
        uint256 resourceId = resource(false, alice);

        // setup first trade
        uint256 tradeId = setupResourceTrade(
            alice,
            requestId,
            0,
            address(bulletin),
            resourceId
        );

        // approve first trade
        approveTrade(owner, requestId, tradeId);

        // setup second resource
        uint256 resourceId2 = resource(false, bob);

        // setup second trade
        tradeId = setupResourceTrade(
            bob,
            requestId,
            0,
            address(bulletin),
            resourceId2
        );

        // approve second trade
        approveTrade(owner, requestId, tradeId);

        // settle ask
        uint16[] memory perc = new uint16[](2);
        perc[0] = 6000;
        perc[1] = 4000;
        settleRequest(owner, uint40(requestId), PERMISSIONED_USER, perc);

        assertEq(
            MockERC20(mock).balanceOf(address(bulletin)),
            amount - (amount * 6000) / 10000 - (amount * 4000) / 10000
        );
        assertEq(MockERC20(mock).balanceOf(alice), (amount * 6000) / 10000);
        assertEq(MockERC20(mock).balanceOf(bob), (amount * 4000) / 10000);

        // uint256 usageId = bulletin.usageIds(resourceId);
        // assertEq(usageId, 1);
        // usageId = bulletin.usageIds(resourceId2);
        // assertEq(usageId, 1);

        // IBulletin.Usage memory u = bulletin.getUsage(resourceId, 1);
        // assertEq(u.Request, bulletin.encodeAsset(address(bulletin), uint96(requestId)));
        // assertEq(u.timestamp, block.timestamp);
        // u = bulletin.getUsage(resourceId2, 1);
        // assertEq(u.Request, bulletin.encodeAsset(address(bulletin), uint96(requestId)));
        // assertEq(u.timestamp, block.timestamp);
    }

    function test_settleRequest_ThreeTrades(uint256 amount) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);
        mock.mint(owner, amount);

        // setup ask
        uint256 requestId = askAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);
        grantRole(address(bulletin), owner, bob, PERMISSIONED_USER);
        grantRole(address(bulletin), owner, charlie, PERMISSIONED_USER);

        // grant BULLETIN role
        grantRole(address(bulletin), owner, address(bulletin), BULLETIN_ROLE);

        // setup first resource
        uint256 resourceId = resource(false, alice);

        // setup first trade
        uint256 tradeId = setupResourceTrade(
            alice,
            requestId,
            0,
            address(bulletin),
            resourceId
        );

        // approve first trade
        approveTrade(owner, requestId, tradeId);

        // setup second resource
        uint256 resourceId2 = resource(false, bob);

        // setup second trade
        tradeId = setupResourceTrade(
            bob,
            requestId,
            0,
            address(bulletin),
            resourceId2
        );

        // approve second trade
        approveTrade(owner, requestId, tradeId);

        // setup third resource
        uint256 resourceId3 = resource(false, charlie);

        // setup third trade
        tradeId = setupResourceTrade(
            charlie,
            requestId,
            0,
            address(bulletin),
            resourceId3
        );

        // approve third trade
        approveTrade(owner, requestId, tradeId);

        // settle ask
        uint16[] memory perc = new uint16[](3);
        perc[0] = 5000;
        perc[1] = 2500;
        perc[2] = 2500;
        settleRequest(owner, uint40(requestId), PERMISSIONED_USER, perc);

        assertEq(
            MockERC20(mock).balanceOf(address(bulletin)),
            amount -
                (amount * 5000) /
                10000 -
                (amount * 2500) /
                10000 -
                (amount * 2500) /
                10000
        );
        assertEq(MockERC20(mock).balanceOf(alice), (amount * 5000) / 10000);
        assertEq(MockERC20(mock).balanceOf(bob), (amount * 2500) / 10000);
        assertEq(MockERC20(mock).balanceOf(charlie), (amount * 2500) / 10000);
    }

    // todo:
    function test_filterTrades() public payable {}
}
