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

    /// @notice Request

    function request(
        bool isOwner,
        address user
    ) public payable returns (uint256 id) {
        IBulletin.Request memory a = IBulletin.Request({
            from: user,
            title: TEST,
            detail: TEST,
            currency: address(0),
            drop: 0 ether
        });

        vm.prank((isOwner) ? owner : user);
        bulletin.request(a);
        id = bulletin.requestId();
    }

    function requestAndDepositEther(
        bool isOwner,
        address user,
        uint256 amount
    ) public payable returns (uint256 id) {
        IBulletin.Request memory a = IBulletin.Request({
            from: user,
            title: TEST,
            detail: TEST,
            currency: address(0),
            drop: amount
        });

        vm.prank((isOwner) ? owner : user);
        bulletin.request{value: amount}(a);
        id = bulletin.requestId();
    }

    function requestAndDepositCurrency(
        bool isOwner,
        address user,
        uint256 amount
    ) public payable returns (uint256 id) {
        IBulletin.Request memory a = IBulletin.Request({
            from: user,
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
            from: user,
            title: TEST,
            detail: TEST
        });

        vm.prank((isOwner) ? owner : user);
        bulletin.resource(r);
        id = bulletin.resourceId();
    }

    function withdrawResource(address op, uint256 resourceId) public payable {
        vm.warp(block.timestamp + 10);
        vm.prank(op);
        bulletin.withdrawResource(resourceId);
    }

    // function settleRequest(
    //     address op,
    //     uint40 requestId,
    //     uint40 role,
    //     uint16[] memory percentages
    // ) public payable {
    //     vm.prank(op);
    //     bulletin.settleRequest(requestId, true, role, percentages);
    // }

    function setupResourceResponse(
        address user,
        uint256 requestId,
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
        bulletin.respond(requestId, trade);
        id = bulletin.responseIdsPerRequest(requestId);
    }

    function setupSimpleResponse(
        address user,
        uint256 requestId
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
        bulletin.respond(requestId, trade);
        id = bulletin.responseIdsPerRequest(requestId);
    }

    function updateSimpleResponse(
        address user,
        uint256 requestId,
        uint256 responseId
    ) public payable {
        bytes32 r;
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            from: user,
            resource: r,
            currency: address(0),
            amount: 0,
            content: TEST2,
            data: BYTES2
        });
        vm.prank(user);
        bulletin.respond(requestId, trade);
    }

    function setupResourceExchange(
        address user,
        uint256 resourceId,
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
        bulletin.exchange(resourceId, trade);
        id = bulletin.exchangeIdsPerResource(resourceId);
    }

    function updateResourceExchange(
        address user,
        uint256 resourceId,
        uint256 exchangeId,
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
            content: TEST2,
            data: BYTES2
        });
        vm.prank(user);
        bulletin.exchange(resourceId, trade);
        id = bulletin.exchangeIdsPerResource(resourceId);
    }

    function setupCurrencyExchange(
        address user,
        uint256 resourceId,
        address currency,
        uint256 amount
    ) public payable returns (uint256 id) {
        bytes32 r;
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            from: user,
            resource: r,
            currency: currency,
            amount: amount,
            content: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.exchange(resourceId, trade);
        id = bulletin.exchangeIdsPerResource(resourceId);
    }

    function updateCurrencyExchange(
        address user,
        uint256 resourceId,
        uint256 exchangeId,
        address currency,
        uint256 amount
    ) public payable {
        bytes32 r;
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            from: user,
            resource: r,
            currency: currency,
            amount: amount,
            content: TEST2,
            data: BYTES2
        });
        vm.prank(user);
        bulletin.exchange(resourceId, trade);
    }

    /// @notice Trades

    function approveResponse(
        address op,
        uint256 requestId,
        uint256 responseId,
        uint256 amount
    ) public payable {
        vm.prank(op);
        bulletin.approveResponse(requestId, responseId, amount);
    }

    function withdrawResponse(
        address op,
        uint256 requestId,
        uint256 responseId
    ) public payable {
        vm.prank(op);
        bulletin.withdrawResponse(requestId, responseId);
    }

    function approveExchange(
        address op,
        uint256 resourceId,
        uint256 exchangeId
    ) public payable {
        vm.prank(op);
        bulletin.approveExchange(resourceId, exchangeId);
    }

    function withdrawExchange(
        address op,
        uint256 resourceId,
        uint256 exchangeId
    ) public payable {
        vm.prank(op);
        bulletin.withdrawExchange(resourceId, exchangeId);
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

    function test_Request() public payable {
        uint256 requestId = request(true, owner);
        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, owner);
        assertEq(_request.title, TEST);
        assertEq(_request.detail, TEST);
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, 0);
    }

    function test_RequestAndDepositCurrency(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        mock.mint(owner, max);
        uint256 requestId = requestAndDepositCurrency(true, owner, amount);
        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, owner);
        assertEq(_request.title, TEST);
        assertEq(_request.detail, TEST);
        assertEq(_request.currency, address(mock));
        assertEq(_request.drop, amount);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), amount);
        assertEq(MockERC20(mock).balanceOf(owner), max - amount);
    }

    function test_RequestAndDepositEther(uint256 amount) public payable {
        vm.assume(1e20 > amount);
        vm.deal(owner, amount);
        uint256 requestId = requestAndDepositEther(true, owner, amount);
        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, owner);
        assertEq(_request.title, TEST);
        assertEq(_request.detail, TEST);
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, amount);

        assertEq(address(bulletin).balance, amount);
        assertEq(address(owner).balance, 0);
    }

    function test_RequestByUser() public payable {
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        uint256 requestId = request(false, alice);
        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, alice);
        assertEq(_request.title, TEST);
        assertEq(_request.detail, TEST);
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, 0);
    }

    function test_RequestAndDepositCurrencyByUser(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        mock.mint(alice, max);
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        uint256 requestId = requestAndDepositCurrency(false, alice, amount);
        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, alice);
        assertEq(_request.title, TEST);
        assertEq(_request.detail, TEST);
        assertEq(_request.currency, address(mock));
        assertEq(_request.drop, amount);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), amount);
        assertEq(MockERC20(mock).balanceOf(alice), max - amount);
    }

    function test_RequestAndDepositEtherByUser(uint256 amount) public payable {
        vm.deal(alice, amount);
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        uint256 requestId = requestAndDepositEther(false, alice, amount);
        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, alice);
        assertEq(_request.title, TEST);
        assertEq(_request.detail, TEST);
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, amount);

        assertEq(address(bulletin).balance, amount);
        assertEq(address(alice).balance, 0);
    }

    function test_Request_Withdraw() public payable {
        uint256 requestId = request(true, owner);

        withdrawRequest(owner, requestId);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);
        assertEq(_request.from, address(0));
        assertEq(_request.title, "");
        assertEq(_request.detail, "");
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, 0);
    }

    function test_RequestAndDepositCurrency_Withdraw(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        mock.mint(owner, amount);
        uint256 requestId = requestAndDepositCurrency(true, owner, amount);

        withdrawRequest(owner, requestId);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);
        assertEq(_request.from, address(0));
        assertEq(_request.title, "");
        assertEq(_request.detail, "");
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, 0);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(owner), amount);
    }

    function test_RequestAndDepositEther_Withdraw(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        vm.deal(owner, amount);
        uint256 requestId = requestAndDepositEther(true, owner, amount);

        withdrawRequest(owner, requestId);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);
        assertEq(_request.from, address(0));
        assertEq(_request.title, "");
        assertEq(_request.detail, "");
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, 0);

        assertEq(address(bulletin).balance, 0);
        assertEq(address(owner).balance, amount);
    }

    function test_RequestByUser_Withdraw() public payable {
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        uint256 requestId = request(false, alice);
        withdrawRequest(alice, requestId);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);
        assertEq(_request.from, address(0));
        assertEq(_request.title, "");
        assertEq(_request.detail, "");
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, 0);
    }

    function test_RequestAndDepositCurrencyByUser_Withdraw(
        uint256 max,
        uint256 amount
    ) public payable {
        vm.assume(max > amount);
        mock.mint(alice, max);
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        uint256 requestId = requestAndDepositCurrency(false, alice, amount);
        withdrawRequest(alice, requestId);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);
        assertEq(_request.from, address(0));
        assertEq(_request.title, "");
        assertEq(_request.detail, "");
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, 0);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(alice), max);
    }

    function test_RequestAndDepositEtherByUser_Withdraw(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        vm.deal(alice, amount);
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        uint256 requestId = requestAndDepositEther(false, alice, amount);
        withdrawRequest(alice, requestId);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);
        assertEq(_request.from, address(0));
        assertEq(_request.title, "");
        assertEq(_request.detail, "");
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, 0);

        assertEq(address(bulletin).balance, 0);
        assertEq(address(alice).balance, amount);
    }

    // todo: asserts
    function test_withdraw_InvalidOriginalPoster() public payable {}

    // todo: asserts
    function test_withdraw_InvalidWithdrawal() public payable {}

    function test_Resource() public payable {
        uint256 resourceId = resource(true, owner);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        uint256 role = Bulletin(bulletin).rolesOf(owner);
        emit log_uint(role);

        assertEq(_resource.from, owner);
        assertEq(_resource.title, TEST);
        assertEq(_resource.detail, TEST);
    }

    function test_Resource_Withdraw() public payable {
        uint256 resourceId = resource(true, owner);
        withdrawResource(owner, resourceId);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        assertEq(_resource.from, address(0));
        assertEq(_resource.title, "");
        assertEq(_resource.detail, "");
    }

    function test_ResourceByUser() public payable {
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);
        uint256 resourceId = resource(false, alice);

        withdrawResource(alice, resourceId);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        assertEq(_resource.from, address(0));
        assertEq(_resource.title, "");
        assertEq(_resource.detail, "");
    }

    function test_ExchangeForResource_ApproveCurrency(
        uint256 amount
    ) public payable {
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);
        uint256 resourceId = resource(false, alice);

        mock.mint(bob, amount);
        mockApprove(bob, address(bulletin), amount);
        uint256 exchangeId = setupCurrencyExchange(
            bob,
            resourceId,
            address(mock),
            amount
        );

        IBulletin.Trade memory trade = bulletin.getExchange(
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

        (uint256 id, IBulletin.Trade memory _trade) = bulletin
            .getExchangeByUser(resourceId, bob);
        assertEq(id, exchangeId);
        assertEq(_trade.approved, false);
        assertEq(_trade.from, bob);
        assertEq(_trade.currency, address(mock));
        assertEq(_trade.amount, amount);
        assertEq(_trade.resource, 0);
        assertEq(_trade.content, TEST);
        assertEq(_trade.data, BYTES);

        approveExchange(alice, resourceId, exchangeId);
        trade = bulletin.getExchange(resourceId, exchangeId);
        assertEq(trade.approved, true);
        assertEq(trade.from, bob);
        assertEq(trade.currency, address(mock));
        assertEq(trade.amount, amount);
        assertEq(mock.balanceOf(alice), amount);
        assertEq(mock.balanceOf(address(bulletin)), 0);
    }

    function test_ExchangeForResource_ApproveResource() public payable {
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);
        uint256 resourceId = resource(false, alice);

        uint256 bobResourceId = resource(false, bob);
        uint256 exchangeId = setupResourceExchange(
            bob,
            resourceId,
            address(bulletin),
            bobResourceId
        );

        IBulletin.Trade memory trade = bulletin.getExchange(
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

        (uint256 id, IBulletin.Trade memory _trade) = bulletin
            .getExchangeByUser(resourceId, bob);
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

        approveExchange(alice, resourceId, exchangeId);
        trade = bulletin.getExchange(resourceId, exchangeId);
        assertEq(trade.approved, true);
        assertEq(trade.from, bob);
        assertEq(trade.currency, address(0));
        assertEq(trade.amount, 0);
    }

    function test_ExchangeForResource_Withdraw(uint256 amount) public payable {
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);
        uint256 resourceId = resource(false, alice);

        mock.mint(bob, amount);
        mockApprove(bob, address(bulletin), amount);
        uint256 exchangeId = setupCurrencyExchange(
            bob,
            resourceId,
            address(mock),
            amount
        );

        IBulletin.Trade memory trade = bulletin.getExchange(
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

        (uint256 id, ) = bulletin.getExchangeByUser(resourceId, bob);
        assertEq(id, 0);

        trade = bulletin.getExchange(resourceId, exchangeId);
        assertEq(trade.approved, false);
        assertEq(trade.from, address(0));
        assertEq(trade.currency, address(0));
        assertEq(trade.amount, 0);
        assertEq(mock.balanceOf(bob), amount);
        assertEq(mock.balanceOf(address(bulletin)), 0);
    }

    function test_ResourceResponseToRequest_Approved(
        uint256 max,
        uint256 amount
    ) public payable {
        mock.mint(owner, max);
        vm.assume(max > amount);

        // setup request
        uint256 requestId = requestAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        // setup resource
        uint256 resourceId = resource(false, alice);

        // setup trade
        uint256 tradeId = setupResourceResponse(
            alice,
            requestId,
            address(bulletin),
            resourceId
        );
        IBulletin.Trade memory trade = bulletin.getResponse(requestId, tradeId);
        bool approved = trade.approved;

        // approve trade
        approveResponse(owner, requestId, tradeId, 0);
        trade = bulletin.getResponse(requestId, tradeId);

        assertEq(trade.approved, !approved);
    }

    function test_ResourceResponseToRequest_Withdraw(
        uint256 max,
        uint256 amount
    ) public payable {
        mock.mint(owner, max);
        vm.assume(max > amount);

        // setup request
        uint256 requestId = requestAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        // setup resource
        uint256 resourceId = resource(false, alice);

        // setup trade
        uint256 responseId = setupResourceResponse(
            alice,
            requestId,
            address(bulletin),
            resourceId
        );

        withdrawResponse(alice, requestId, responseId);

        (uint256 id, ) = bulletin.getResponseByUser(requestId, alice);
        assertEq(id, 0);

        IBulletin.Trade memory trade = bulletin.getResponse(
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

    function test_updateSimpleResponse_NotOriginalPoster(
        uint256 _requestId,
        uint256 _tradeId
    ) public payable {
        vm.prank(owner);
        vm.expectRevert(IBulletin.NotOriginalPoster.selector);
        bulletin.approveResponse(_requestId, _tradeId, 0);
    }

    function test_SimpleResponseToRequest_OneApprovalWithCurrency(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 10_000);
        mock.mint(owner, amount);

        // setup request
        uint256 requestId = requestAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

        // setup first trade
        uint256 responseId = setupSimpleResponse(alice, requestId);

        // approve first trade
        approveResponse(owner, requestId, responseId, amount);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(alice), amount);

        (uint256 id, IBulletin.Trade memory _trade) = bulletin
            .getResponseByUser(requestId, alice);
        assertEq(id, responseId);
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
        uint256 requestId = requestAndDepositCurrency(true, owner, amount);

        // grant PERMISSIONED role
        grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);
        grantRole(address(bulletin), owner, bob, PERMISSIONED_USER);

        // grant BULLETIN role
        grantRole(address(bulletin), owner, address(bulletin), BULLETIN_ROLE);

        // setup first trade
        uint256 responseId = setupSimpleResponse(alice, requestId);

        // approve first trade
        approveResponse(owner, requestId, responseId, (amount * 20) / 100);

        (uint256 id, IBulletin.Trade memory _trade) = bulletin
            .getResponseByUser(requestId, alice);
        assertEq(id, responseId);
        assertEq(_trade.approved, true);
        assertEq(_trade.from, alice);
        assertEq(_trade.currency, address(0));
        assertEq(_trade.amount, 0);
        assertEq(_trade.resource, 0);
        assertEq(_trade.content, TEST);
        assertEq(_trade.data, BYTES);

        // setup second trade
        responseId = setupSimpleResponse(bob, requestId);

        // approve second trade
        approveResponse(owner, requestId, responseId, (amount * 20) / 100);

        assertEq(
            MockERC20(mock).balanceOf(address(bulletin)),
            amount - (amount * 20) / 100 - (amount * 20) / 100
        );
        assertEq(MockERC20(mock).balanceOf(alice), (amount * 20) / 100);
        assertEq(MockERC20(mock).balanceOf(bob), (amount * 20) / 100);

        (id, _trade) = bulletin.getResponseByUser(requestId, bob);
        assertEq(id, responseId);
        assertEq(_trade.approved, true);
        assertEq(_trade.from, bob);
        assertEq(_trade.currency, address(0));
        assertEq(_trade.amount, 0);
        assertEq(_trade.resource, 0);
        assertEq(_trade.content, TEST);
        assertEq(_trade.data, BYTES);
    }

    // function test_settleRequest_OneTrade(uint256 amount) public payable {
    //     vm.assume(1e20 > amount);
    //     vm.assume(amount > 10_000);
    //     mock.mint(owner, amount);

    //     // setup ask
    //     uint256 requestId = askAndDepositCurrency(true, owner, amount);

    //     // grant PERMISSIONED role
    //     grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);

    //     // setup first resource
    //     uint256 resourceId = resource(false, alice);

    //     // setup first trade
    //     uint256 tradeId = setupResourceResponse(
    //         alice,
    //         requestId,
    //         address(bulletin),
    //         resourceId
    //     );

    //     // approve first trade
    //     updateSimpleResponse(owner, requestId, tradeId);

    //     // settle ask
    //     uint16[] memory perc = new uint16[](1);
    //     perc[0] = 10000;
    //     settleRequest(
    //         owner,
    //         uint40(requestId),
    //         uint40(PERMISSIONED_USER),
    //         perc
    //     );

    //     assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
    //     assertEq(MockERC20(mock).balanceOf(alice), amount);

    //     // uint256 usageId = bulletin.usageIds(resourceId);
    //     // assertEq(usageId, 1);
    // }

    // function test_settleRequest_TwoTrades(uint256 amount) public payable {
    //     vm.assume(1e20 > amount);
    //     vm.assume(amount > 10_000);
    //     mock.mint(owner, amount);

    //     // setup ask
    //     uint256 requestId = askAndDepositCurrency(true, owner, amount);

    //     // grant PERMISSIONED role
    //     grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);
    //     grantRole(address(bulletin), owner, bob, PERMISSIONED_USER);

    //     // grant BULLETIN role
    //     grantRole(address(bulletin), owner, address(bulletin), BULLETIN_ROLE);

    //     // setup first resource
    //     uint256 resourceId = resource(false, alice);

    //     // setup first trade
    //     uint256 tradeId = setupResourceResponse(
    //         alice,
    //         requestId,
    //         address(bulletin),
    //         resourceId
    //     );

    //     // approve first trade
    //     updateSimpleResponse(owner, requestId, tradeId);

    //     // setup second resource
    //     uint256 resourceId2 = resource(false, bob);

    //     // setup second trade
    //     tradeId = setupResourceResponse(
    //         bob,
    //         requestId,
    //         address(bulletin),
    //         resourceId2
    //     );

    //     // approve second trade
    //     updateSimpleResponse(owner, requestId, tradeId);

    //     // settle ask
    //     uint16[] memory perc = new uint16[](2);
    //     perc[0] = 6000;
    //     perc[1] = 4000;
    //     settleRequest(owner, uint40(requestId), PERMISSIONED_USER, perc);

    //     assertEq(
    //         MockERC20(mock).balanceOf(address(bulletin)),
    //         amount - (amount * 6000) / 10000 - (amount * 4000) / 10000
    //     );
    //     assertEq(MockERC20(mock).balanceOf(alice), (amount * 6000) / 10000);
    //     assertEq(MockERC20(mock).balanceOf(bob), (amount * 4000) / 10000);

    //     // uint256 usageId = bulletin.usageIds(resourceId);
    //     // assertEq(usageId, 1);
    //     // usageId = bulletin.usageIds(resourceId2);
    //     // assertEq(usageId, 1);

    //     // IBulletin.Usage memory u = bulletin.getUsage(resourceId, 1);
    //     // assertEq(u.Request, bulletin.encodeAsset(address(bulletin), uint96(requestId)));
    //     // assertEq(u.timestamp, block.timestamp);
    //     // u = bulletin.getUsage(resourceId2, 1);
    //     // assertEq(u.Request, bulletin.encodeAsset(address(bulletin), uint96(requestId)));
    //     // assertEq(u.timestamp, block.timestamp);
    // }

    // function test_settleRequest_ThreeTrades(uint256 amount) public payable {
    //     vm.assume(1e20 > amount);
    //     vm.assume(amount > 10_000);
    //     mock.mint(owner, amount);

    //     // setup ask
    //     uint256 requestId = askAndDepositCurrency(true, owner, amount);

    //     // grant PERMISSIONED role
    //     grantRole(address(bulletin), owner, alice, PERMISSIONED_USER);
    //     grantRole(address(bulletin), owner, bob, PERMISSIONED_USER);
    //     grantRole(address(bulletin), owner, charlie, PERMISSIONED_USER);

    //     // grant BULLETIN role
    //     grantRole(address(bulletin), owner, address(bulletin), BULLETIN_ROLE);

    //     // setup first resource
    //     uint256 resourceId = resource(false, alice);

    //     // setup first trade
    //     uint256 tradeId = setupResourceResponse(
    //         alice,
    //         requestId,
    //         address(bulletin),
    //         resourceId
    //     );

    //     // approve first trade
    //     updateSimpleResponse(owner, requestId, tradeId);

    //     // setup second resource
    //     uint256 resourceId2 = resource(false, bob);

    //     // setup second trade
    //     tradeId = setupResourceResponse(
    //         bob,
    //         requestId,
    //         address(bulletin),
    //         resourceId2
    //     );

    //     // approve second trade
    //     updateSimpleResponse(owner, requestId, tradeId);

    //     // setup third resource
    //     uint256 resourceId3 = resource(false, charlie);

    //     // setup third trade
    //     tradeId = setupResourceResponse(
    //         charlie,
    //         requestId,
    //         address(bulletin),
    //         resourceId3
    //     );

    //     // approve third trade
    //     updateSimpleResponse(owner, requestId, tradeId);

    //     // settle ask
    //     uint16[] memory perc = new uint16[](3);
    //     perc[0] = 5000;
    //     perc[1] = 2500;
    //     perc[2] = 2500;
    //     settleRequest(owner, uint40(requestId), PERMISSIONED_USER, perc);

    //     assertEq(
    //         MockERC20(mock).balanceOf(address(bulletin)),
    //         amount -
    //             (amount * 5000) /
    //             10000 -
    //             (amount * 2500) /
    //             10000 -
    //             (amount * 2500) /
    //             10000
    //     );
    //     assertEq(MockERC20(mock).balanceOf(alice), (amount * 5000) / 10000);
    //     assertEq(MockERC20(mock).balanceOf(bob), (amount * 2500) / 10000);
    //     assertEq(MockERC20(mock).balanceOf(charlie), (amount * 2500) / 10000);
    // }

    // todo:
    function test_filterTrades() public payable {}
}
