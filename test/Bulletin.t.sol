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
    uint40 public constant BULLETIN_ROLE = 1 << 1;
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
        IBulletin.Ask memory a = IBulletin.Ask({
            fulfilled: true,
            owner: user,
            role: PERMISSIONED_USER,
            title: TEST,
            detail: TEST,
            currency: address(0),
            drop: 0 ether
        });

        vm.prank((isOwner) ? owner : user);
        bulletin.ask(a);
        id = bulletin.askId();
    }

    function askAndDepositEther(
        bool isOwner,
        address user,
        uint256 amount
    ) public payable returns (uint256 id) {
        IBulletin.Ask memory a = IBulletin.Ask({
            fulfilled: true,
            owner: user,
            role: PERMISSIONED_USER,
            title: TEST,
            detail: TEST,
            currency: address(0),
            drop: amount
        });

        vm.prank((isOwner) ? owner : user);
        bulletin.ask{value: amount}(a);
        id = bulletin.askId();
    }

    function askAndDepositCurrency(
        bool isOwner,
        address user,
        uint256 amount
    ) public payable returns (uint256 id) {
        IBulletin.Ask memory a = IBulletin.Ask({
            fulfilled: true,
            owner: user,
            role: PERMISSIONED_USER,
            title: TEST,
            detail: TEST,
            currency: address(mock),
            drop: amount
        });

        mockApprove((isOwner) ? owner : user, address(bulletin), amount);

        vm.prank((isOwner) ? owner : user);
        bulletin.ask(a);
        id = bulletin.askId();
    }

    function updateAsk(
        address op,
        uint256 askId,
        IBulletin.Ask memory a
    ) public payable {
        vm.prank(op);
        bulletin.updateAsk(askId, a);
    }

    function withdrawAsk(address op, uint256 askId) public payable {
        vm.warp(block.timestamp + 10);
        vm.prank(op);
        bulletin.withdrawAsk(askId);
    }

    /// @notice Resource

    function resource(
        bool isOwner,
        address user
    ) public payable returns (uint256 id) {
        IBulletin.Resource memory r = IBulletin.Resource({
            active: true,
            role: PERMISSIONED_USER,
            owner: user,
            title: TEST,
            detail: TEST
        });

        vm.prank((isOwner) ? owner : user);
        bulletin.resource(r);
        id = bulletin.resourceId();
    }

    function updateResource(
        address op,
        uint256 resourceId,
        IBulletin.Resource memory r
    ) public payable {
        vm.prank(op);
        bulletin.updateResource(resourceId, r);
    }

    function approveTrade(
        address op,
        uint256 askId,
        uint256 tradeId
    ) public payable {
        vm.prank(op);
        bulletin.approveTrade(askId, tradeId);
    }

    function rejectTrade(
        address op,
        uint256 askId,
        uint256 tradeId
    ) public payable {
        vm.prank(op);
        bulletin.rejectTrade(askId, tradeId);
    }

    function settleAsk(
        address op,
        uint40 askId,
        uint40 role,
        uint16[] memory percentages
    ) public payable {
        vm.prank(op);
        bulletin.settleAsk(askId, role, percentages);
    }

    function setupResourceTrade(
        address user,
        uint256 askId,
        uint40 role,
        address userBulletin,
        uint256 userResourceId
    ) public payable returns (uint256 id) {
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            role: role,
            proposer: user,
            resource: bulletin.encodeAsset(
                address(userBulletin),
                uint96(userResourceId)
            ),
            feedback: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.trade(askId, trade);
        id = bulletin.tradeIds(askId);
    }

    function setupCheckin(
        address user,
        uint256 askId,
        uint40 role
    ) public payable returns (uint256 id) {
        bytes32 r;
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            role: role,
            proposer: user,
            resource: r,
            feedback: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.trade(askId, trade);
        id = bulletin.tradeIds(askId);
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
        uint256 askId = ask(true, owner);
        IBulletin.Ask memory _ask = bulletin.getAsk(askId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.role, uint40(uint256(_OWNER_SLOT)));
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
        uint256 askId = askAndDepositCurrency(true, owner, amount);
        IBulletin.Ask memory _ask = bulletin.getAsk(askId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.role, uint40(uint256(_OWNER_SLOT)));
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
        uint256 askId = askAndDepositEther(true, owner, amount);
        IBulletin.Ask memory _ask = bulletin.getAsk(askId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, amount);

        assertEq(address(bulletin).balance, amount);
        assertEq(address(owner).balance, max - amount);
    }

    function test_askByUser() public payable {
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        uint256 askId = ask(false, alice);
        IBulletin.Ask memory _ask = bulletin.getAsk(askId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, alice);
        assertEq(_ask.role, PERMISSIONED_USER);
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

        uint256 askId = askAndDepositCurrency(false, alice, amount);
        IBulletin.Ask memory _ask = bulletin.getAsk(askId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, alice);
        assertEq(_ask.role, PERMISSIONED_USER);
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

        uint256 askId = askAndDepositEther(false, alice, amount);
        IBulletin.Ask memory _ask = bulletin.getAsk(askId);

        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, alice);
        assertEq(_ask.role, PERMISSIONED_USER);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, amount);

        assertEq(address(bulletin).balance, amount);
        assertEq(address(alice).balance, 0);
    }

    function test_updateAskWithNewAmount(uint256 amount) public payable {
        uint256 askId = ask(true, owner);

        IBulletin.Ask memory a = IBulletin.Ask({
            fulfilled: true,
            owner: owner,
            role: PERMISSIONED_USER,
            title: TEST2,
            detail: TEST2,
            currency: address(0),
            drop: amount
        });

        vm.deal(owner, amount);
        vm.prank(owner);
        bulletin.updateAsk{value: amount}(askId, a);

        uint256 id = bulletin.askId();
        IBulletin.Ask memory _a = bulletin.getAsk(id);
        assertEq(_a.fulfilled, false);
        assertEq(_a.owner, owner);
        assertEq(_a.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_a.title, TEST2);
        assertEq(_a.detail, TEST2);
        assertEq(_a.currency, address(0));
        assertEq(_a.drop, amount);
        assertEq(address(owner).balance, 0);
    }

    function test_updateAskWithSameCurrencyNewAmount(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        mock.mint(owner, amount);
        uint256 askId = askAndDepositCurrency(true, owner, amount);

        IBulletin.Ask memory a = IBulletin.Ask({
            fulfilled: true,
            owner: owner,
            role: PERMISSIONED_USER,
            title: TEST2,
            detail: TEST2,
            currency: address(mock),
            drop: 1 ether
        });

        mock.mint(owner, 1 ether);
        mockApprove(owner, address(bulletin), 1 ether);

        vm.prank(owner);
        bulletin.updateAsk(askId, a);

        uint256 id = bulletin.askId();
        IBulletin.Ask memory _a = bulletin.getAsk(id);
        assertEq(_a.title, TEST2);
        assertEq(_a.detail, TEST2);
        assertEq(_a.currency, address(mock));
        assertEq(_a.drop, 1 ether);
        assertEq(MockERC20(mock).balanceOf(owner), amount);
    }

    function test_updateAskWithNewCurrencyNewAmount(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        mock.mint(owner, amount);
        uint256 askId = askAndDepositCurrency(true, owner, amount);

        uint256 newAmount = 1 ether;
        IBulletin.Ask memory a = IBulletin.Ask({
            fulfilled: true,
            owner: owner,
            role: PERMISSIONED_USER,
            title: TEST2,
            detail: TEST2,
            currency: address(mock2),
            drop: newAmount
        });

        mock2.mint(owner, newAmount);
        vm.prank(owner);
        mock2.approve(address(bulletin), newAmount);

        vm.prank(owner);
        bulletin.updateAsk(askId, a);

        uint256 id = bulletin.askId();
        IBulletin.Ask memory _a = bulletin.getAsk(id);
        assertEq(_a.fulfilled, false);
        assertEq(_a.owner, owner);
        assertEq(_a.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_a.title, TEST2);
        assertEq(_a.detail, TEST2);
        assertEq(_a.currency, address(mock2));
        assertEq(_a.drop, newAmount);
        assertEq(MockERC20(mock).balanceOf(owner), amount);
    }

    function test_updateAsk_InvalidOriginalPoster(
        uint256 amount
    ) public payable {
        mock.mint(owner, amount);
        uint256 askId = askAndDepositCurrency(true, owner, amount);

        IBulletin.Ask memory a;
        vm.expectRevert(IBulletin.InvalidOriginalPoster.selector);
        bulletin.updateAsk(askId, a);
    }

    // todo:
    function test_updateAsk_AlreadyFulfilled() public payable {}

    function test_withdraw() public payable {
        uint256 askId = ask(true, owner);

        withdrawAsk(owner, askId);

        IBulletin.Ask memory _ask = bulletin.getAsk(askId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);
    }

    function test_withdrawAndReturnCurrency(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        mock.mint(owner, max);
        uint256 askId = askAndDepositCurrency(true, owner, amount);

        withdrawAsk(owner, askId);

        IBulletin.Ask memory _ask = bulletin.getAsk(askId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
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
        uint256 askId = askAndDepositEther(true, owner, amount);

        withdrawAsk(owner, askId);

        IBulletin.Ask memory _ask = bulletin.getAsk(askId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, owner);
        assertEq(_ask.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
        assertEq(_ask.currency, address(0));
        assertEq(_ask.drop, 0);

        assertEq(address(bulletin).balance, 0);
        assertEq(address(owner).balance, max);
    }

    function test_withdrawByUser() public payable {
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        uint256 askId = ask(false, alice);
        withdrawAsk(alice, askId);

        IBulletin.Ask memory _ask = bulletin.getAsk(askId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, alice);
        assertEq(_ask.role, PERMISSIONED_USER);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
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

        uint256 askId = askAndDepositCurrency(false, alice, amount);
        withdrawAsk(alice, askId);

        IBulletin.Ask memory _ask = bulletin.getAsk(askId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, alice);
        assertEq(_ask.role, PERMISSIONED_USER);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
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

        uint256 askId = askAndDepositEther(false, alice, amount);
        withdrawAsk(alice, askId);

        IBulletin.Ask memory _ask = bulletin.getAsk(askId);
        assertEq(_ask.fulfilled, false);
        assertEq(_ask.owner, alice);
        assertEq(_ask.role, PERMISSIONED_USER);
        assertEq(_ask.title, TEST);
        assertEq(_ask.detail, TEST);
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
        assertEq(_resource.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_resource.owner, owner);
        assertEq(_resource.title, TEST);
        assertEq(_resource.detail, TEST);
    }

    function test_updateResource() public payable {
        uint256 resourceId = resource(true, owner);

        IBulletin.Resource memory r = IBulletin.Resource({
            active: false,
            role: 0,
            owner: alice,
            title: TEST2,
            detail: TEST2
        });

        updateResource(owner, resourceId, r);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        assertEq(_resource.active, false);
        assertEq(_resource.role, uint40(uint256(_OWNER_SLOT)));
        assertEq(_resource.owner, owner);
        assertEq(_resource.title, TEST2);
        assertEq(_resource.detail, TEST2);
    }

    function test_resourceByUser() public payable {
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);
        uint256 resourceId = resource(false, alice);

        IBulletin.Resource memory r = IBulletin.Resource({
            active: false,
            role: PERMISSIONED_USER,
            owner: alice,
            title: TEST2,
            detail: TEST2
        });

        updateResource(alice, resourceId, r);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        assertEq(_resource.active, false);
        assertEq(_resource.role, PERMISSIONED_USER);
        assertEq(_resource.owner, alice);
        assertEq(_resource.title, TEST2);
        assertEq(_resource.detail, TEST2);
    }

    function test_approveTrade(uint256 max, uint256 amount) public payable {
        mock.mint(owner, max);
        vm.assume(max > amount);

        // setup ask
        uint256 askId = askAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        // setup resource
        uint256 resourceId = resource(false, alice);

        // setup trade
        uint256 tradeId = setupResourceTrade(
            alice,
            askId,
            PERMISSIONED_USER,
            address(bulletin),
            resourceId
        );
        IBulletin.Trade memory trade = bulletin.getTrade(askId, tradeId);
        bool approved = trade.approved;

        // approve trade
        approveTrade(owner, askId, tradeId);
        trade = bulletin.getTrade(askId, tradeId);

        assertEq(trade.approved, !approved);
        assertEq(
            trade.resource,
            bulletin.encodeAsset(address(bulletin), uint96(resourceId))
        );
        assertEq(trade.feedback, TEST);
        assertEq(trade.data, BYTES);
    }

    function test_rejectTrade(uint256 max, uint256 amount) public payable {
        mock.mint(owner, max);
        vm.assume(max > amount);

        // setup ask
        uint256 askId = askAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        // setup resource
        uint256 resourceId = resource(false, alice);

        // setup trade
        uint256 tradeId = setupResourceTrade(
            alice,
            askId,
            PERMISSIONED_USER,
            address(bulletin),
            resourceId
        );

        // approve trade
        approveTrade(owner, askId, tradeId);

        IBulletin.Trade memory trade = bulletin.getTrade(askId, tradeId);
        bool approved = trade.approved;

        // reject trade
        rejectTrade(owner, askId, tradeId);
        trade = bulletin.getTrade(askId, tradeId);

        assertEq(trade.approved, !approved);
        assertEq(
            trade.resource,
            bulletin.encodeAsset(address(bulletin), uint96(resourceId))
        );
        assertEq(trade.feedback, TEST);
        assertEq(trade.data, BYTES);
    }

    function test_approveTrade_InvalidOriginalPoster(
        uint256 _askId,
        uint256 _tradeId
    ) public payable {
        vm.prank(owner);
        vm.expectRevert(IBulletin.InvalidOriginalPoster.selector);
        bulletin.approveTrade(_askId, _tradeId);
    }

    function test_settleAsk_OneCheckin(uint256 amount) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);
        mock.mint(owner, amount);

        // setup ask
        uint256 askId = askAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        // grant BULLETIN role
        grantRole(address(bulletin), owner, address(bulletin), BULLETIN_ROLE);

        // setup first trade
        setupCheckin(alice, askId, PERMISSIONED_USER);

        // settle ask
        uint16[] memory perc = new uint16[](1);
        perc[0] = 10000;
        settleAsk(owner, uint40(askId), uint40(PERMISSIONED_USER), perc);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(alice), amount);
    }

    function test_settleAsk_TwoCheckins(uint256 amount) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);
        mock.mint(owner, amount);

        // setup ask
        uint256 askId = askAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);
        grantRole(address(bulletin), owner, bob, PERMISSIONED_USER);

        // grant BULLETIN role
        grantRole(address(bulletin), owner, address(bulletin), BULLETIN_ROLE);

        // setup first trade
        setupCheckin(alice, askId, PERMISSIONED_USER);

        // setup second trade
        setupCheckin(bob, askId, PERMISSIONED_USER);

        uint16[] memory perc = new uint16[](2);
        perc[0] = 6000;
        perc[1] = 4000;
        settleAsk(owner, uint40(askId), PERMISSIONED_USER, perc);

        assertEq(
            MockERC20(mock).balanceOf(address(bulletin)),
            amount - (amount * 6000) / 10000 - (amount * 4000) / 10000
        );
        assertEq(MockERC20(mock).balanceOf(alice), (amount * 6000) / 10000);
        assertEq(MockERC20(mock).balanceOf(bob), (amount * 4000) / 10000);
    }

    function test_settleAsk_OneTrade(uint256 amount) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);
        mock.mint(owner, amount);

        // setup ask
        uint256 askId = askAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        // grant BULLETIN role
        grantRole(address(bulletin), owner, address(bulletin), BULLETIN_ROLE);

        // setup first resource
        uint256 resourceId = resource(false, alice);

        // setup first trade
        uint256 tradeId = setupResourceTrade(
            alice,
            askId,
            PERMISSIONED_USER,
            address(bulletin),
            resourceId
        );

        // approve first trade
        approveTrade(owner, askId, tradeId);

        // settle ask
        uint16[] memory perc = new uint16[](1);
        perc[0] = 10000;
        settleAsk(owner, uint40(askId), uint40(PERMISSIONED_USER), perc);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(alice), amount);

        uint256 usageId = bulletin.usageIds(resourceId);
        assertEq(usageId, 1);
    }

    function test_settleAsk_TwoTrades(uint256 amount) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);
        mock.mint(owner, amount);

        // setup ask
        uint256 askId = askAndDepositCurrency(true, owner, amount);

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
            askId,
            PERMISSIONED_USER,
            address(bulletin),
            resourceId
        );

        // approve first trade
        approveTrade(owner, askId, tradeId);

        // setup second resource
        uint256 resourceId2 = resource(false, bob);

        // setup second trade
        tradeId = setupResourceTrade(
            bob,
            askId,
            PERMISSIONED_USER,
            address(bulletin),
            resourceId2
        );

        // approve second trade
        approveTrade(owner, askId, tradeId);

        // settle ask
        uint16[] memory perc = new uint16[](2);
        perc[0] = 6000;
        perc[1] = 4000;
        settleAsk(owner, uint40(askId), PERMISSIONED_USER, perc);

        assertEq(
            MockERC20(mock).balanceOf(address(bulletin)),
            amount - (amount * 6000) / 10000 - (amount * 4000) / 10000
        );
        assertEq(MockERC20(mock).balanceOf(alice), (amount * 6000) / 10000);
        assertEq(MockERC20(mock).balanceOf(bob), (amount * 4000) / 10000);

        uint256 usageId = bulletin.usageIds(resourceId);
        assertEq(usageId, 1);
        usageId = bulletin.usageIds(resourceId2);
        assertEq(usageId, 1);

        IBulletin.Usage memory u = bulletin.getUsage(resourceId, 1);
        assertEq(u.ask, bulletin.encodeAsset(address(bulletin), uint96(askId)));
        assertEq(u.timestamp, block.timestamp);
        u = bulletin.getUsage(resourceId2, 1);
        assertEq(u.ask, bulletin.encodeAsset(address(bulletin), uint96(askId)));
        assertEq(u.timestamp, block.timestamp);
    }

    function test_settleAsk_ThreeTrades(uint256 amount) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);
        mock.mint(owner, amount);

        // setup ask
        uint256 askId = askAndDepositCurrency(true, owner, amount);

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
            askId,
            PERMISSIONED_USER,
            address(bulletin),
            resourceId
        );

        // approve first trade
        approveTrade(owner, askId, tradeId);

        // setup second resource
        uint256 resourceId2 = resource(false, bob);

        // setup second trade
        tradeId = setupResourceTrade(
            bob,
            askId,
            PERMISSIONED_USER,
            address(bulletin),
            resourceId2
        );

        // approve second trade
        approveTrade(owner, askId, tradeId);

        // setup third resource
        uint256 resourceId3 = resource(false, charlie);

        // setup third trade
        tradeId = setupResourceTrade(
            charlie,
            askId,
            PERMISSIONED_USER,
            address(bulletin),
            resourceId3
        );

        // approve third trade
        approveTrade(owner, askId, tradeId);

        // settle ask
        uint16[] memory perc = new uint16[](3);
        perc[0] = 5000;
        perc[1] = 2500;
        perc[2] = 2500;
        settleAsk(owner, uint40(askId), PERMISSIONED_USER, perc);

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

        uint256 usageId = bulletin.usageIds(resourceId);
        assertEq(usageId, 1);
        usageId = bulletin.usageIds(resourceId2);
        assertEq(usageId, 1);
        usageId = bulletin.usageIds(resourceId3);
        assertEq(usageId, 1);

        IBulletin.Usage memory u = bulletin.getUsage(resourceId, 1);
        assertEq(u.ask, bulletin.encodeAsset(address(bulletin), uint96(askId)));
        assertEq(u.timestamp, block.timestamp);
        u = bulletin.getUsage(resourceId2, 1);
        assertEq(u.ask, bulletin.encodeAsset(address(bulletin), uint96(askId)));
        assertEq(u.timestamp, block.timestamp);
        u = bulletin.getUsage(resourceId3, 1);
        assertEq(u.ask, bulletin.encodeAsset(address(bulletin), uint96(askId)));
        assertEq(u.timestamp, block.timestamp);
    }

    function test_incrementUsageByAnotherBulletin(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);
        mock.mint(owner, amount);

        // setup ask
        uint256 askId = askAndDepositCurrency(true, owner, amount);

        // deploy bulletin for alice
        deployBulletin2(alice);
        deployBulletin3(bob);

        // grant BULLETIN role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);
        grantRole(address(bulletin), owner, bob, PERMISSIONED_USER);
        grantRole(address(bulletin2), alice, address(bulletin), BULLETIN_ROLE);
        grantRole(address(bulletin3), bob, address(bulletin), BULLETIN_ROLE);

        // setup first resource
        IBulletin.Resource memory r = IBulletin.Resource({
            active: true,
            role: PERMISSIONED_USER,
            owner: alice,
            title: TEST,
            detail: TEST
        });

        vm.prank(alice);
        bulletin2.resource(r);

        // setup first trade
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            role: PERMISSIONED_USER,
            proposer: alice,
            resource: bulletin.encodeAsset(address(bulletin2), uint96(1)),
            feedback: TEST,
            data: BYTES
        });
        vm.prank(alice);
        bulletin.trade(askId, trade);
        uint256 tradeId = bulletin.tradeIds(askId);

        // approve first trade
        approveTrade(owner, askId, tradeId);

        // setup second resource
        r = IBulletin.Resource({
            active: true,
            role: PERMISSIONED_USER,
            owner: bob,
            title: TEST,
            detail: TEST
        });

        vm.prank(bob);
        bulletin3.resource(r);

        // setup second trade
        trade = IBulletin.Trade({
            approved: true,
            role: PERMISSIONED_USER,
            proposer: bob,
            resource: bulletin.encodeAsset(address(bulletin3), uint96(1)),
            feedback: TEST,
            data: BYTES
        });
        vm.prank(bob);
        bulletin.trade(askId, trade);
        tradeId = bulletin.tradeIds(askId);

        // approve second trade
        approveTrade(owner, askId, tradeId);

        // settle ask
        uint16[] memory perc = new uint16[](2);
        perc[0] = 6000;
        perc[1] = 4000;
        settleAsk(owner, uint40(askId), PERMISSIONED_USER, perc);

        assertEq(
            MockERC20(mock).balanceOf(address(bulletin)),
            amount - (amount * 6000) / 10000 - (amount * 4000) / 10000
        );
        assertEq(MockERC20(mock).balanceOf(alice), (amount * 6000) / 10000);
        assertEq(MockERC20(mock).balanceOf(bob), (amount * 4000) / 10000);

        uint256 usageId = bulletin2.usageIds(1);
        assertEq(usageId, 1);
        usageId = bulletin3.usageIds(1);
        assertEq(usageId, 1);

        IBulletin.Usage memory u = bulletin2.getUsage(1, 1);
        assertEq(u.ask, bulletin.encodeAsset(address(bulletin), uint96(askId)));
        assertEq(u.timestamp, block.timestamp);
        u = bulletin3.getUsage(1, 1);
        assertEq(u.ask, bulletin.encodeAsset(address(bulletin), uint96(askId)));
        assertEq(u.timestamp, block.timestamp);
    }

    function test_comment() public payable {
        test_settleAsk_OneTrade(1 ether);

        vm.prank(owner);
        bulletin.comment(1, 1, TEST, BYTES);

        IBulletin.Usage memory u = bulletin.getUsage(1, 1);
        assertEq(u.feedback, TEST);
        assertEq(u.data, BYTES);
    }

    function test_commentAnotherBulletin() public payable {
        test_incrementUsageByAnotherBulletin(1 ether);

        vm.prank(owner);
        bulletin2.comment(1, 1, TEST, BYTES);
        vm.prank(owner);
        bulletin3.comment(1, 1, TEST, BYTES);

        IBulletin.Usage memory u = bulletin2.getUsage(1, 1);
        assertEq(u.feedback, TEST);
        assertEq(u.data, BYTES);
        u = bulletin3.getUsage(1, 1);
        assertEq(u.feedback, TEST);
        assertEq(u.data, BYTES);
    }

    // todo:
    function test_filterTrades() public payable {}
}
