// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {Bulletin} from "src/Bulletin.sol";
import {Collective} from "src/Collective.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {ICollective} from "src/interface/ICollective.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract CollectiveTest_Base is Test {
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
    uint256[] roles = new uint256[](2);
    uint256[] weights = new uint256[](2);
    uint256[] spots = new uint256[](2);

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
        activate(address(bulletin), owner, owner, 10 ether);
        activate(address(bulletin), owner, alice, 10 ether);
        activate(address(bulletin), owner, bob, 10 ether);

        // Proposal roles, weights, and spots.
        roles[0] = 2;
        roles[1] = 3;
        weights[0] = 3;
        weights[1] = 5;
        spots[0] = 1;
        spots[1] = 1;
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
            spots: spots
        });
        vm.prank(proposer);
        collective.propose(0, p);

        return collective.proposalId();
    }

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
    function getPayload_Withdraw(
        bool toWithdrawTrade,
        uint256 subjectId,
        IBulletin.TradeType tt,
        uint256 tradeId
    ) public pure returns (bytes memory) {
        return
            (toWithdrawTrade)
                ? abi.encode(subjectId)
                : abi.encode(tt, subjectId, tradeId);
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
    /*                                  Propose.                                  */
    /* -------------------------------------------------------------------------- */

    function test_PostProprosal_Doc(
        uint8 quorum,
        uint8 _tally,
        bytes memory payload
    ) public {
        vm.assume(quorum > 0);
        vm.assume(100 > quorum);
        vm.assume(uint8(type(ICollective.Tally).max) >= _tally);
        ICollective.Tally tally = ICollective.Tally(_tally);
        uint256 _id = collective.proposalId();
        uint256 id = postProposal(
            owner,
            quorum,
            tally,
            ICollective.Action.NONE,
            payload,
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(++_id, id);
        assertEq(uint8(p.status), uint8(ICollective.Status.ACTIVE));
        assertEq(uint8(p.action), uint8(ICollective.Action.NONE));
        assertEq(uint8(p.tally), uint8(_tally));
        assertEq(p.targetProp, 0);
        assertEq(p.quorum, quorum);
        assertEq(p.proposer, owner);
        assertEq(p.payload, payload);
        assertEq(p.doc, TEST);
        assertEq(p.roles[0], roles[0]);
        assertEq(p.roles[1], roles[1]);
        assertEq(p.roles.length, roles.length);
        assertEq(p.weights[0], weights[0]);
        assertEq(p.weights[1], weights[1]);
        assertEq(p.weights.length, weights.length);
        assertEq(p.spots[0], spots[0]);
        assertEq(p.spots[1], spots[1]);
        assertEq(p.spots.length, spots.length);
    }

    function test_PostProprosal_ActivateCredit() public {
        bytes memory payload;
        uint256 id = postProposal(
            owner,
            10,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.ACTIVATE_CREDIT,
            payload = getPayload_Credit(charlie, 10 ether),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.action), uint8(ICollective.Action.ACTIVATE_CREDIT));
        assertEq(p.payload, payload);
    }

    function test_PostProprosal_AdjustCredit() public {
        bytes memory payload;
        uint256 id = postProposal(
            owner,
            10,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.ADJUST_CREDIT,
            payload = getPayload_Credit(charlie, 10 ether),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.action), uint8(ICollective.Action.ADJUST_CREDIT));
        assertEq(p.payload, payload);
    }

    function test_PostProprosal_Request() public {
        IBulletin.Request memory req = IBulletin.Request({
            from: address(collective),
            currency: address(0xc0d),
            drop: 2 ether,
            data: BYTES,
            uri: TEST
        });
        bytes memory payload;
        uint256 id = postProposal(
            owner,
            30,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.POST_OR_UPDATE_REQUEST,
            payload = getPayload_Request(0, req),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(
            uint8(p.action),
            uint8(ICollective.Action.POST_OR_UPDATE_REQUEST)
        );
        assertEq(p.payload, payload);

        (uint256 subjectId, IBulletin.Request memory _req) = abi.decode(
            payload,
            (uint256, IBulletin.Request)
        );

        assertEq(subjectId, 0);
        assertEq(req.from, _req.from);
        assertEq(req.currency, _req.currency);
        assertEq(req.drop, _req.drop);
        assertEq(req.uri, _req.uri);
        assertEq(req.data, _req.data);
    }

    function test_PostProprosal_Resource() public {
        IBulletin.Resource memory res = IBulletin.Resource({
            from: address(collective),
            data: BYTES,
            uri: TEST
        });
        bytes memory payload;
        uint256 id = postProposal(
            owner,
            30,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.POST_OR_UPDATE_RESOURCE,
            payload = getPayload_Resource(0, res),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(
            uint8(p.action),
            uint8(ICollective.Action.POST_OR_UPDATE_RESOURCE)
        );
        assertEq(p.payload, payload);

        (uint256 subjectId, IBulletin.Resource memory _res) = abi.decode(
            payload,
            (uint256, IBulletin.Resource)
        );

        assertEq(subjectId, 0);
        assertEq(res.from, _res.from);
        assertEq(res.uri, _res.uri);
        assertEq(res.data, _res.data);
    }

    function test_PostProprosal_Trade(uint8 tt) public {
        vm.assume(uint8(type(IBulletin.TradeType).max) >= tt);

        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: true,
            timestamp: 100,
            duration: 200,
            from: address(collective),
            resource: bytes32(uint256(100)),
            currency: address(0xc0d), // `address(0xc0d)` reserved for credit
            amount: 1 ether,
            content: TEST,
            data: BYTES //
        });
        bytes memory payload;
        uint256 id = postProposal(
            owner,
            30,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.TRADE,
            payload = getPayload_Trade(IBulletin.TradeType(tt), 1, trade),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.action), uint8(ICollective.Action.TRADE));
        assertEq(p.payload, payload);

        (
            IBulletin.TradeType _tt,
            uint256 subjectId,
            IBulletin.Trade memory _trade
        ) = abi.decode(
                payload,
                (IBulletin.TradeType, uint256, IBulletin.Trade)
            );

        assertEq(subjectId, 1);
        assertEq(uint8(_tt), uint8(tt));
        assertEq(trade.approved, _trade.approved);
        assertEq(trade.paused, _trade.paused);
        assertEq(trade.timestamp, _trade.timestamp);
        assertEq(trade.duration, _trade.duration);
        assertEq(trade.from, _trade.from);
        assertEq(trade.resource, _trade.resource);
        assertEq(trade.currency, _trade.currency);
        assertEq(trade.amount, _trade.amount);
        assertEq(trade.content, _trade.content);
        assertEq(trade.data, _trade.data);
    }

    function test_ApproveTrade_ApproveResponse(
        uint256 subjectId,
        uint256 tradeId,
        uint256 amount
    ) public {
        bytes memory payload;
        uint256 id = postProposal(
            owner,
            30,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.APPROVE_RESPONSE,
            payload = getPayload_ApproveTradeToRequest(
                subjectId,
                tradeId,
                amount
            ),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.action), uint8(ICollective.Action.APPROVE_RESPONSE));
        assertEq(p.payload, payload);

        (uint256 sId, uint256 tId, uint256 _amount) = abi.decode(
            payload,
            (uint256, uint256, uint256)
        );
        assertEq(sId, subjectId);
        assertEq(tId, tradeId);
        assertEq(_amount, amount);
    }

    function test_ApproveTrade_ApproveExchange(
        uint256 subjectId,
        uint256 tradeId,
        uint40 duration
    ) public {
        bytes memory payload;
        uint256 id = postProposal(
            owner,
            30,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.APPROVE_EXCHANGE,
            payload = getPayload_ApproveTradeForResource(
                subjectId,
                tradeId,
                duration
            ),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.action), uint8(ICollective.Action.APPROVE_EXCHANGE));
        assertEq(p.payload, payload);

        (uint256 sId, uint256 tId, uint256 _duration) = abi.decode(
            payload,
            (uint256, uint256, uint256)
        );
        assertEq(sId, subjectId);
        assertEq(tId, tradeId);
        assertEq(_duration, duration);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Cancel Proposals.                             */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------------------------------------------------- */
    /*                                  Sponsor.                                  */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------------------------------------------------- */
    /*                                    Vote.                                   */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------------------------------------------------- */
    /*                                Improvements.                               */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------------------------------------------------- */
    /*                                  Process.                                  */
    /* -------------------------------------------------------------------------- */
}
