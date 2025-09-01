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

    function postRequestWithCredit(
        address user,
        uint256 credit,
        uint256 drop
    ) public payable returns (uint256 id) {
        activate(address(bulletin), owner, user, credit);
        IBulletin.Request memory r = IBulletin.Request({
            from: user,
            currency: address(0xc0d),
            drop: drop,
            data: BYTES,
            uri: TEST
        });

        vm.prank(user);
        bulletin.request(0, r);
        id = bulletin.requestId();
    }

    function postRequestWithCurrency(
        address user,
        uint256 mint,
        uint256 drop
    ) public payable returns (uint256 id) {
        mock.mint(owner, mint);
        mockApprove(user, address(bulletin), drop);

        IBulletin.Request memory r = IBulletin.Request({
            from: user,
            currency: address(mock),
            drop: drop,
            data: BYTES,
            uri: TEST
        });

        vm.prank(user);
        bulletin.request(0, r);
        id = bulletin.requestId();
    }

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
            data: BYTES2,
            uri: TEST2
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

    function postResource(address user) public payable returns (uint256 id) {
        IBulletin.Resource memory r = IBulletin.Resource({
            from: user,
            data: BYTES,
            uri: TEST
        });

        vm.prank(user);
        bulletin.resource(0, r);
        id = bulletin.resourceId();
    }

    // function resource(
    //     bool isOwner,
    //     address user
    // ) public payable returns (uint256 id) {
    //     IBulletin.Resource memory r = IBulletin.Resource({
    //         from: user,
    //         data: BYTES,
    //         uri: TEST
    //     });

    //     vm.prank((isOwner) ? owner : user);
    //     bulletin.resource(0, r);
    //     id = bulletin.resourceId();
    // }

    function updateResource(
        address op,
        address newOwner,
        uint256 resourceId
    ) public payable {
        vm.warp(block.timestamp + 10);
        IBulletin.Resource memory r = IBulletin.Resource({
            from: newOwner,
            data: BYTES2,
            uri: TEST2
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
            timestamp: uint40(block.timestamp),
            duration: 2 weeks,
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
        bulletin.trade(IBulletin.TradeType.RESPONSE, requestId, trade);
        id = bulletin.tradeIdsPerRequest(requestId);
    }

    function postTradeWithPromise(
        IBulletin.TradeType tradeType,
        address user,
        uint256 subjectId,
        string memory content,
        bytes memory data
    ) public payable returns (uint256 id) {
        bytes32 r;
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: true,
            timestamp: uint40(block.timestamp),
            duration: 2 weeks,
            from: user,
            resource: r,
            currency: address(0),
            amount: 0,
            content: content,
            data: data
        });
        vm.prank(user);
        bulletin.trade(tradeType, subjectId, trade);
        id = (tradeType == IBulletin.TradeType.RESPONSE)
            ? bulletin.tradeIdsPerRequest(subjectId)
            : bulletin.tradeIdsPerResource(subjectId);
    }

    function postTradeWithResource(
        IBulletin.TradeType tradeType,
        address user,
        uint256 subjectId,
        address userBulletin,
        uint256 userResourceId
    ) public payable returns (uint256 id) {
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            timestamp: uint40(block.timestamp),
            duration: 2 weeks,
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
        bulletin.trade(tradeType, subjectId, trade);
        id = (tradeType == IBulletin.TradeType.RESPONSE)
            ? bulletin.tradeIdsPerRequest(subjectId)
            : bulletin.tradeIdsPerResource(subjectId);
    }

    function postTradeWithResourceAndCurrency(
        IBulletin.TradeType tradeType,
        address user,
        uint256 subjectId,
        address userBulletin,
        uint256 userResourceId,
        address currency,
        uint256 amount
    ) public payable returns (uint256 id) {
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            timestamp: uint40(block.timestamp),
            duration: 2 weeks,
            from: user,
            resource: bulletin.encodeAsset(
                address(userBulletin),
                uint96(userResourceId)
            ),
            currency: currency,
            amount: amount,
            content: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.trade(tradeType, subjectId, trade);
        id = (tradeType == IBulletin.TradeType.RESPONSE)
            ? bulletin.tradeIdsPerRequest(subjectId)
            : bulletin.tradeIdsPerResource(subjectId);
    }

    function postTradeWithCurrency(
        IBulletin.TradeType tradeType,
        address user,
        uint256 subjectId,
        address currency,
        uint256 amount
    ) public payable returns (uint256 id) {
        bytes32 r;
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: true,
            timestamp: uint40(block.timestamp),
            duration: 2 weeks,
            from: user,
            resource: r,
            currency: currency,
            amount: amount,
            content: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.trade(tradeType, subjectId, trade);
        id = (tradeType == IBulletin.TradeType.RESPONSE)
            ? bulletin.tradeIdsPerRequest(subjectId)
            : bulletin.tradeIdsPerResource(subjectId);
    }

    function updateTrade(
        IBulletin.TradeType tradeType,
        address user,
        uint256 subjectId,
        bytes32 r,
        address currency,
        uint256 amount
    ) public payable {
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: true,
            timestamp: uint40(block.timestamp),
            duration: 2 weeks,
            from: user,
            resource: r,
            currency: currency,
            amount: amount,
            content: TEST2,
            data: BYTES2
        });
        vm.prank(user);
        bulletin.trade(tradeType, subjectId, trade);
    }

    function setupSimpleResponse(
        address user,
        uint256 requestId
    ) public payable returns (uint256 id) {
        bytes32 r;
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            timestamp: uint40(block.timestamp),
            duration: 2 weeks,
            from: user,
            resource: r,
            currency: address(0),
            amount: 0,
            content: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.trade(IBulletin.TradeType.RESPONSE, requestId, trade);
        id = bulletin.tradeIdsPerRequest(requestId);
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
            timestamp: uint40(block.timestamp),
            duration: 2 weeks,
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
        bulletin.trade(IBulletin.TradeType.EXCHANGE, resourceId, trade);
        id = bulletin.tradeIdsPerResource(resourceId);
    }

    function setupCreditExchange(
        address user,
        uint256 resourceId,
        uint256 amount
    ) public payable returns (uint256 id) {
        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            timestamp: uint40(block.timestamp),
            duration: 2 weeks,
            from: user,
            resource: bytes32(0),
            currency: address(0xc0d),
            amount: amount,
            content: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.trade(IBulletin.TradeType.EXCHANGE, resourceId, trade);
        id = bulletin.tradeIdsPerResource(resourceId);
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
            timestamp: uint40(block.timestamp),
            duration: 2 weeks,
            from: user,
            resource: r,
            currency: currency,
            amount: amount,
            content: TEST,
            data: BYTES
        });
        vm.prank(user);
        bulletin.trade(IBulletin.TradeType.EXCHANGE, resourceId, trade);
        id = bulletin.tradeIdsPerResource(resourceId);
    }

    /// @notice Trades

    function approveTradeToRequest(
        address op,
        uint256 requestId,
        uint256 responseId,
        uint256 amount
    ) public payable {
        vm.prank(op);
        bulletin.approveTradeToRequest(requestId, responseId, amount);
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

    function approveTradeForResource(
        address op,
        uint256 resourceId,
        uint256 exchangeId
    ) public payable {
        vm.prank(op);
        bulletin.approveTradeForResource(
            resourceId,
            exchangeId,
            type(uint40).max
        );
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
}
