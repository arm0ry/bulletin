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

    /// @dev Mock Data.
    uint40 constant PAST = 100000;
    uint40 constant FUTURE = 2527482181;
    string TEST = "TEST";
    string TEST2 = "TEST2";
    bytes32 constant BYTES32 = bytes32("BYTES32");
    bytes constant BYTES = bytes(string("BYTES"));
    bytes constant BYTES2 = bytes(string("BYTES2"));

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
        assert(!sent);
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

    function activate(
        address _bulletin,
        address _owner,
        address user,
        uint256 amount
    ) public payable {
        vm.prank(_owner);
        Bulletin(payable(_bulletin)).activate(user, amount);
    }

    /// -----------------------------------------------------------------------
    /// Helpers.
    /// -----------------------------------------------------------------------

    /// @notice Request

    function requestByCredit(
        bool isOwner,
        address user,
        uint256 drop
    ) public payable returns (uint256 id) {
        IBulletin.Request memory a = IBulletin.Request({
            from: user,
            currency: address(0xc0d),
            drop: drop,
            data: BYTES,
            uri: TEST
        });

        vm.prank((isOwner) ? owner : user);
        bulletin.request(0, a);
        id = bulletin.requestId();
    }

    function requestByCurrency(
        bool isOwner,
        address user,
        uint256 amount
    ) public payable returns (uint256 id) {
        IBulletin.Request memory a = IBulletin.Request({
            from: user,
            currency: address(mock),
            drop: amount,
            data: BYTES,
            uri: TEST
        });

        mockApprove((isOwner) ? owner : user, address(bulletin), amount);

        vm.prank((isOwner) ? owner : user);
        bulletin.request(0, a);
        id = bulletin.requestId();
    }

    // function requestByCredit(
    //     address user,
    //     uint256 amount
    // ) public payable returns (uint256 id) {
    //     IBulletin.Request memory a = IBulletin.Request({
    //         from: user,
    //         currency: address(0xc0d),
    //         drop: amount,
    //         data: BYTES
    //     });

    //     vm.prank(user);
    //     bulletin.request(0, a);
    //     id = bulletin.requestId();
    // }

    function updateRequest(
        address op,
        uint256 requestId,
        address currency,
        uint256 amount
    ) public payable {
        vm.warp(block.timestamp + 10);
        IBulletin.Request memory r = IBulletin.Request({
            from: op,
            currency: currency,
            drop: amount,
            data: BYTES,
            uri: TEST
        });
        vm.prank(op);
        bulletin.request(requestId, r);
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
            data: BYTES,
            uri: TEST
        });

        vm.prank((isOwner) ? owner : user);
        bulletin.resource(0, r);
        id = bulletin.resourceId();
    }

    function updateResource(
        address op,
        address newOwner,
        uint256 resourceId
    ) public payable {
        vm.warp(block.timestamp + 10);
        IBulletin.Resource memory r = IBulletin.Resource({
            from: newOwner,
            data: BYTES,
            uri: TEST
        });
        vm.prank(op);
        bulletin.resource(resourceId, r);
    }

    function withdrawResource(address op, uint256 resourceId) public payable {
        vm.warp(block.timestamp + 10);
        vm.prank(op);
        bulletin.withdrawResource(resourceId);
    }

    function setupResourceResponse(
        address user,
        uint256 requestId,
        address userBulletin,
        uint256 userResourceId
    ) public payable returns (uint256 id) {
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            from: user,
            timestamp: uint40(block.timestamp),
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
        bulletin.trade(IBulletin.TradeType.RESPONSE, requestId, trade);
        id = bulletin.responseIdsPerRequest(requestId);
    }

    function setupSimpleResponse(
        address user,
        uint256 requestId
    ) public payable returns (uint256 id) {
        bytes32 r;
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            from: user,
            timestamp: uint40(block.timestamp),
            resource: r,
            currency: address(0),
            amount: 0,
            content: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.trade(IBulletin.TradeType.RESPONSE, requestId, trade);
        id = bulletin.responseIdsPerRequest(requestId);
    }

    function updateSimpleResponse(
        address user,
        uint256 requestId
    ) public payable {
        bytes32 r;
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            from: user,
            timestamp: uint40(block.timestamp),
            resource: r,
            currency: address(0),
            amount: 0,
            content: TEST2,
            data: BYTES2
        });
        vm.prank(user);
        bulletin.trade(IBulletin.TradeType.RESPONSE, requestId, trade);
    }

    function setupResourceExchange(
        address user,
        uint256 resourceId,
        address userBulletin,
        uint256 userResourceId
    ) public payable returns (uint256 id) {
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            from: user,
            timestamp: uint40(block.timestamp),
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
        bulletin.trade(IBulletin.TradeType.EXCHANGE, resourceId, trade);
        id = bulletin.exchangeIdsPerResource(resourceId);
    }

    function updateResourceExchange(
        address user,
        uint256 resourceId,
        address userBulletin,
        uint256 userResourceId
    ) public payable returns (uint256 id) {
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            from: user,
            timestamp: uint40(block.timestamp),
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
        bulletin.trade(IBulletin.TradeType.EXCHANGE, resourceId, trade);
        id = bulletin.exchangeIdsPerResource(resourceId);
    }

    function setupCreditExchange(
        address user,
        uint256 resourceId,
        uint256 amount
    ) public payable returns (uint256 id) {
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            from: user,
            timestamp: uint40(block.timestamp),
            resource: bytes32(0),
            currency: address(0xc0d),
            amount: amount,
            content: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.trade(IBulletin.TradeType.EXCHANGE, resourceId, trade);
        id = bulletin.exchangeIdsPerResource(resourceId);
    }

    function setupStaking(
        IBulletin.TradeType tradeType,
        address user,
        uint256 subjectId,
        uint256 amount
    ) public payable returns (uint256 id) {
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            from: user,
            timestamp: uint40(block.timestamp),
            resource: bytes32(0),
            currency: address(0xbeef),
            amount: amount,
            content: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.trade(tradeType, subjectId, trade);
        id = bulletin.exchangeIdsPerResource(subjectId);
    }

    function setupCurrencyExchange(
        address user,
        uint256 resourceId,
        address currency,
        uint256 amount
    ) public payable returns (uint256 id) {
        vm.prank(user);
        MockERC20(currency).approve(address(bulletin), amount);

        bytes32 r;
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            from: user,
            timestamp: uint40(block.timestamp),
            resource: r,
            currency: currency,
            amount: amount,
            content: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.trade(IBulletin.TradeType.EXCHANGE, resourceId, trade);
        id = bulletin.exchangeIdsPerResource(resourceId);
    }

    function updateCurrencyExchange(
        address user,
        uint256 resourceId,
        address currency,
        uint256 amount
    ) public payable {
        bytes32 r;
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            from: user,
            timestamp: uint40(block.timestamp),
            resource: r,
            currency: currency,
            amount: amount,
            content: TEST2,
            data: BYTES2
        });
        vm.prank(user);
        bulletin.trade(IBulletin.TradeType.EXCHANGE, resourceId, trade);
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
        bulletin.withdrawTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            responseId
        );
    }

    function approveExchange(
        address op,
        uint256 resourceId,
        uint256 exchangeId
    ) public payable {
        vm.prank(op);
        bulletin.approveExchange(resourceId, exchangeId, type(uint40).max);
    }

    function withdrawExchange(
        address op,
        uint256 resourceId,
        uint256 exchangeId
    ) public payable {
        vm.prank(op);
        bulletin.withdrawTrade(
            IBulletin.TradeType.EXCHANGE,
            resourceId,
            exchangeId
        );
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

    function test_Request(uint256 amount) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);
        activate(address(bulletin), owner, owner, 10 ether);

        uint256 requestId = requestByCredit(true, owner, amount);
        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, owner);
        assertEq(_request.data, BYTES);
        assertEq(_request.currency, address(0xc0d));
        assertEq(_request.drop, amount);
    }

    function test_RequestAndDepositCurrency(uint256 amount) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

        activate(address(bulletin), owner, owner, 10 ether);
        mock.mint(owner, amount);
        uint256 requestId = requestByCurrency(true, owner, amount);
        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, owner);
        assertEq(_request.data, BYTES);
        assertEq(_request.currency, address(mock));
        assertEq(_request.drop, amount);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), amount);
        assertEq(MockERC20(mock).balanceOf(owner), 0);
    }

    function test_Request_Withdraw() public payable {
        activate(address(bulletin), owner, owner, 10 ether);
        uint256 requestId = requestByCredit(true, owner, 5 ether);

        withdrawRequest(owner, requestId);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);
        assertEq(_request.from, address(0));
        assertEq(_request.data, "");
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, 0);
    }

    function test_Request_UpdateCreditAmount() public payable {
        activate(address(bulletin), owner, owner, 20 ether);
        uint256 requestId = requestByCredit(true, owner, 5 ether);
        updateRequest(owner, requestId, address(0xc0d), 10 ether);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, owner);
        assertEq(_request.data, BYTES);
        assertEq(_request.currency, address(0xc0d));
        assertEq(_request.drop, 10 ether);
    }

    // TODO:
    function test_Request_UpdateCurrencyAmount() public payable {}

    // TODO:
    function test_Request_UpdateCurrency_CreditToCurrency() public payable {}

    // TODO:
    function test_Request_UpdateCurrency_CurrencyToCredit() public payable {}

    function test_RequestAndDepositCurrency_Withdraw(
        uint256 amount
    ) public payable {
        vm.assume(1e20 > amount);
        vm.assume(amount > 0);
        mock.mint(owner, amount);
        activate(address(bulletin), owner, owner, 10 ether);
        uint256 requestId = requestByCurrency(true, owner, amount);

        withdrawRequest(owner, requestId);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);
        assertEq(_request.from, address(0));
        assertEq(_request.data, "");
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, 0);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(owner), amount);
    }

    // todo: asserts
    function test_withdraw_InvalidOriginalPoster() public payable {}

    // todo: asserts
    function test_withdraw_InvalidWithdrawal() public payable {}

    function test_Resource() public payable {
        activate(address(bulletin), owner, owner, 10 ether);
        uint256 resourceId = resource(true, owner);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        uint256 role = Bulletin(bulletin).rolesOf(owner);
        emit log_uint(role);

        assertEq(_resource.from, owner);
        assertEq(_resource.data, BYTES);
    }

    function test_Resource_Update() public payable {
        activate(address(bulletin), owner, owner, 10 ether);
        uint256 resourceId = resource(true, owner);

        activate(address(bulletin), owner, charlie, 10 ether);
        updateResource(owner, charlie, resourceId);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        assertEq(_resource.from, charlie);
        assertEq(_resource.data, BYTES);
    }

    function test_Resource_Withdraw() public payable {
        activate(address(bulletin), owner, owner, 10 ether);
        uint256 resourceId = resource(true, owner);
        withdrawResource(owner, resourceId);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        assertEq(_resource.from, address(0));
        assertEq(_resource.data, "");
    }

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
        approveExchange(alice, resourceId, exchangeId);

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

        approveExchange(alice, resourceId, exchangeId);

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
        approveExchange(bob, resourceId, exchangeId);

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
        approveExchange(bob, resourceId, exchangeId);

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

        approveExchange(alice, 1, exchangeId);

        vm.prank(alice);
        bulletin.claim(IBulletin.TradeType.EXCHANGE, 1, exchangeId);

        credit = bulletin.getCredit(alice);
        assertEq(credit.limit, 2 ether);
        assertEq(credit.amount, 6 ether);
    }

    function test_Staking(uint256 amount) public payable {
        vm.assume(2 ether > amount);
        vm.assume(amount > 10_000);
        test_ApproveCreditExchangeForResource_ByMember(2 ether);

        // Staking
        uint256 stakingId = setupStaking(
            IBulletin.TradeType.EXCHANGE,
            bob,
            1,
            amount
        );
        (
            uint256 tradeId,
            uint256 sId,
            uint256 lastTrade,
            uint256 lastStake
        ) = Bulletin(address(bulletin)).getTradeAndStakeIdsByUser(
                IBulletin.TradeType.EXCHANGE,
                1,
                bob
            );
        assertEq(tradeId, 0);
        assertEq(stakingId, sId);
        assertEq(lastTrade, 1);
        assertEq(lastStake, 0);

        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            1,
            stakingId
        );
        assertEq(trade.approved, false);
        assertEq(trade.from, bob);
        assertEq(trade.currency, address(0xbeef));
        assertEq(trade.amount, amount);
        assertEq(trade.resource, bytes32(block.timestamp));
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);
    }

    function test_UpdateStaking() public payable {
        test_Staking(1 ether);

        uint256 stakingId = setupStaking(
            IBulletin.TradeType.EXCHANGE,
            bob,
            1,
            2 ether
        );

        uint256 timestamp = block.timestamp;

        (
            uint256 tradeId,
            uint256 sId,
            uint256 lastTrade,
            uint256 lastStake
        ) = Bulletin(address(bulletin)).getTradeAndStakeIdsByUser(
                IBulletin.TradeType.EXCHANGE,
                1,
                bob
            );
        assertEq(tradeId, 0);
        assertEq(stakingId, sId);
        assertEq(lastTrade, 1);
        assertEq(lastStake, 0);

        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            1,
            stakingId
        );
        assertEq(trade.approved, false);
        assertEq(trade.from, bob);
        assertEq(trade.currency, address(0xbeef));
        assertEq(trade.amount, 2 ether);
        assertEq(trade.resource, bytes32(timestamp));
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);
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

        (uint256 id, , , ) = bulletin.getTradeAndStakeIdsByUser(
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

        approveExchange(alice, resourceId, exchangeId);

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

        (uint256 id, , , ) = bulletin.getTradeAndStakeIdsByUser(
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

        approveExchange(alice, resourceId, exchangeId);
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

    function test_ExchangeForResource_Withdraw(uint256 amount) public payable {
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

        withdrawExchange(bob, resourceId, exchangeId);

        (uint256 id, , , ) = bulletin.getTradeAndStakeIdsByUser(
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
        approveResponse(owner, requestId, tradeId, 0);
        trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );

        assertEq(trade.approved, !approved);
    }

    function test_ResourceResponseToRequest_Withdraw(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

        // setup request
        mock.mint(owner, 10 ether);
        activate(address(bulletin), owner, owner, 10 ether);
        uint256 requestId = requestByCurrency(true, owner, amount);

        // setup resource
        activate(address(bulletin), owner, alice, 10 ether);
        uint256 resourceId = resource(false, alice);

        // setup trade
        uint256 responseId = setupResourceResponse(
            alice,
            requestId,
            address(bulletin),
            resourceId
        );

        withdrawResponse(alice, requestId, responseId);

        (uint256 id, , , ) = bulletin.getTradeAndStakeIdsByUser(
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
        activate(address(bulletin), owner, owner, 10 ether);
        uint256 requestId = requestByCurrency(true, owner, amount);

        // setup first trade
        uint256 responseId = setupSimpleResponse(alice, requestId);

        // approve first trade
        approveResponse(owner, requestId, responseId, amount);

        vm.prank(alice);
        bulletin.claim(IBulletin.TradeType.RESPONSE, requestId, responseId);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), 0);
        assertEq(MockERC20(mock).balanceOf(alice), amount);

        (, , uint256 lastTrade, ) = bulletin.getTradeAndStakeIdsByUser(
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
        approveResponse(owner, requestId, responseId, (amount * 20) / 100);

        (uint256 tradeId, , uint256 lastTrade, ) = bulletin
            .getTradeAndStakeIdsByUser(
                IBulletin.TradeType.RESPONSE,
                requestId,
                alice
            );
        IBulletin.Trade memory _trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            lastTrade
        );
        assertEq(tradeId, 0);
        assertEq(lastTrade, responseId);
        assertEq(_trade.approved, true);
        assertEq(_trade.from, alice);
        assertEq(_trade.currency, address(mock));
        assertEq(_trade.amount, (amount * 20) / 100);
        assertEq(_trade.resource, 0);
        assertEq(_trade.content, TEST);
        assertEq(_trade.data, BYTES);

        // setup second trade
        responseId = setupSimpleResponse(bob, requestId);

        (tradeId, , lastTrade, ) = bulletin.getTradeAndStakeIdsByUser(
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
        assertEq(lastTrade, 0);

        // approve second trade
        approveResponse(owner, requestId, responseId, (amount * 20) / 100);

        vm.prank(bob);
        bulletin.claim(IBulletin.TradeType.RESPONSE, requestId, responseId);

        assertEq(
            MockERC20(mock).balanceOf(address(bulletin)),
            amount - (amount * 20) / 100
        );
        assertEq(MockERC20(mock).balanceOf(alice), 0);
        assertEq(MockERC20(mock).balanceOf(bob), (amount * 20) / 100);

        (tradeId, , lastTrade, ) = bulletin.getTradeAndStakeIdsByUser(
            IBulletin.TradeType.RESPONSE,
            requestId,
            bob
        );
        _trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            lastTrade
        );
        assertEq(tradeId, 0);
        assertEq(lastTrade, responseId);
        assertEq(_trade.approved, true);
        assertEq(_trade.from, bob);
        assertEq(_trade.currency, address(0));
        assertEq(_trade.amount, 0);
        assertEq(_trade.resource, 0);
        assertEq(_trade.content, TEST);
        assertEq(_trade.data, BYTES);
    }
}
