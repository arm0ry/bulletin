// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {Bulletin} from "src/Bulletin.sol";
import {Collective} from "src/Collective.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {ICollective} from "src/interface/ICollective.sol";

contract CollectiveTest is Test {
    Collective collective;
    Bulletin bulletin;
    MockERC20 mock;
    MockERC20 mock2;

    /// @dev Mock Users.
    address immutable alice = makeAddr("alice");
    address immutable bob = makeAddr("bob");
    address immutable charlie = makeAddr("charlie");
    address immutable owner = makeAddr("owner");

    /// @dev Mock Data.
    string TEST = "TEST";
    string TEST2 = "TEST2";
    bytes32 constant BYTES32 = bytes32("BYTES32");
    bytes constant BYTES = bytes(string("BYTES"));
    bytes constant BYTES2 = bytes(string("BYTES2"));

    /// @dev Roles, Weights, Spots.
    uint256 ARTISTS = 1 << 5;
    uint256 OPERATIONS = 1 << 6;
    uint256 RELATIONS = 1 << 7;
    uint256[] roles = new uint256[](2);
    uint256[] weights = new uint256[](2);
    uint256[] spotsCap = new uint256[](2);

    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        deployBulletin(owner);
        deployCollective(address(bulletin));

        // Roles.
        grantRole(
            address(bulletin),
            owner,
            address(collective),
            bulletin.COLLECTIVE()
        );

        // Credits.
        activate(address(bulletin), owner, address(collective), 10 ether);
        activate(address(bulletin), owner, owner, 10 ether);
        activate(address(bulletin), owner, alice, 10 ether);
        activate(address(bulletin), owner, bob, 10 ether);

        // Proposal roles, weights, and spotsCap.
        roles[0] = ARTISTS;
        roles[1] = OPERATIONS;
        weights[0] = 3;
        weights[1] = 5;
        spotsCap[0] = 1;
        spotsCap[1] = 1;
    }

    function testReceiveETH() public payable {
        (bool sent, ) = address(collective).call{value: 5 ether}("");
        assert(sent);
    }

    function deployCollective(address b) public payable {
        collective = new Collective();
        collective.init(b);
        assertEq(collective.bulletin(), b);
    }

    function deployBulletin(address user) public payable {
        bulletin = new Bulletin();
        bulletin.init(user);
        assertEq(bulletin.owner(), user);
    }

    function grantRole(
        address _bulletin,
        address _owner,
        address user,
        uint256 role
    ) public payable returns (uint256) {
        vm.prank(_owner);
        Bulletin(payable(_bulletin)).grantRoles(user, role);

        return Bulletin(payable(_bulletin)).rolesOf(user);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Credit.                                  */
    /* -------------------------------------------------------------------------- */

    function activate(
        address _bulletin,
        address _owner,
        address user,
        uint256 amount
    ) public payable {
        vm.prank(_owner);
        Bulletin(payable(_bulletin)).activate(user, amount);
    }

    function adjust(
        address _bulletin,
        address _owner,
        address user,
        uint256 amount
    ) public payable {
        vm.prank(_owner);
        Bulletin(payable(_bulletin)).adjust(user, amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Proposals.                                 */
    /* -------------------------------------------------------------------------- */

    function postProposal(
        address proposer,
        uint8 quorum,
        ICollective.Tally tally,
        ICollective.Action action,
        bytes memory payload,
        string memory doc
    ) public returns (uint256 id) {
        ICollective.Proposal memory p = ICollective.Proposal({
            status: ICollective.Status.COSIGNED,
            action: action,
            tally: tally,
            targetProp: 0,
            quorum: quorum,
            proposer: proposer,
            payload: payload,
            doc: doc,
            roles: roles,
            weights: weights,
            spotsUsed: spotsCap,
            spotsCap: spotsCap
        });
        vm.prank(proposer);
        collective.propose(0, p);

        return collective.proposalId();
    }

    function postImpProposal(
        uint40 targetProp,
        address proposer,
        uint8 quorum,
        ICollective.Tally tally,
        ICollective.Action action,
        bytes memory payload,
        string memory doc
    ) public returns (uint256 id) {
        ICollective.Proposal memory p = ICollective.Proposal({
            status: ICollective.Status.COSIGNED,
            action: action,
            tally: tally,
            quorum: quorum,
            targetProp: targetProp,
            proposer: proposer,
            payload: payload,
            doc: doc,
            roles: roles,
            weights: weights,
            spotsUsed: spotsCap,
            spotsCap: spotsCap
        });
        vm.prank(proposer);
        collective.raise(0, p);

        return collective.proposalId();
    }

    function sponsor(address user, uint256 propId) public {
        vm.prank(user);
        collective.sponsor(propId);
    }

    function vote(
        address voter,
        bool decision,
        uint256 propId,
        uint256 role,
        uint256 votes
    ) public {
        vm.prank(voter);
        collective.vote(decision, propId, role, votes);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Payload.                                  */
    /* -------------------------------------------------------------------------- */

    function getPayload_Credit(
        address user,
        uint256 amount
    ) public pure returns (bytes memory) {
        return abi.encode(user, amount);
    }

    function getPayload_Request(
        uint256 id,
        IBulletin.Request memory req
    ) public pure returns (bytes memory) {
        return abi.encode(id, req);
    }
    function getPayload_Resource(
        uint256 id,
        IBulletin.Resource memory res
    ) public pure returns (bytes memory) {
        return abi.encode(id, res);
    }

    function getPayload_ApproveTradeToRequest(
        uint256 subjectId,
        uint256 tradeId,
        uint256 amount
    ) public pure returns (bytes memory) {
        return abi.encode(subjectId, tradeId, amount);
    }
    function getPayload_ApproveTradeForResource(
        uint256 subjectId,
        uint256 tradeId,
        uint256 duration
    ) public pure returns (bytes memory) {
        return abi.encode(subjectId, tradeId, duration);
    }

    function getPayload_Trade(
        IBulletin.TradeType tt,
        uint256 subjectId,
        IBulletin.Trade memory trade
    ) public pure returns (bytes memory) {
        return abi.encode(tt, subjectId, trade);
    }

    function getPayload_WithdrawRequestOrResource(
        uint256 subjectId
    ) public pure returns (bytes memory) {
        return abi.encode(subjectId);
    }

    function getPayload_WithdrawTrade(
        IBulletin.TradeType tt,
        uint256 subjectId,
        uint256 tradeId
    ) public pure returns (bytes memory) {
        return abi.encode(tt, subjectId, tradeId);
    }

    function getPayload_Claim(
        IBulletin.TradeType tt,
        uint256 subjectId,
        uint256 tradeId
    ) public pure returns (bytes memory) {
        return abi.encode(tt, subjectId, tradeId);
    }

    function getPayload_Pause(
        uint256 subjectId,
        uint256 tradeId
    ) public pure returns (bytes memory) {
        return abi.encode(subjectId, tradeId);
    }

    /* -------------------------------------------------------------------------- */
    /*                               From Bulletin.                               */
    /* -------------------------------------------------------------------------- */

    function mockApprove(
        address approver,
        address spender,
        uint256 amount
    ) public payable {
        vm.prank(approver);
        mock.approve(spender, amount);
    }

    function postRequestWithCredit(
        address user,
        uint256 drop
    ) public payable returns (uint256 id) {
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
        mock.mint(user, mint);
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

    function postTradeWithCurrency(
        IBulletin.TradeType tradeType,
        address user,
        uint256 subjectId,
        address currency,
        uint256 amount
    ) public payable returns (uint256 id) {
        bytes32 r;
        if (currency != address(0) && currency != address(0xc0d)) {
            mock.mint(user, amount);
            mockApprove(user, address(bulletin), amount);
        }

        if (currency == address(0xc0d)) {
            IBulletin.Credit memory c = bulletin.getCredit(user);
            if (c.limit > 0)
                adjust(address(bulletin), owner, user, amount + c.limit);
            else activate(address(bulletin), owner, user, amount);
        }

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
}
