// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {CollectiveTest_Base} from "test/collective/Collective_Base.t.sol";
import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {ICollective} from "src/interface/ICollective.sol";

contract CollectiveTest_Propose is Test, CollectiveTest_Base {
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
        assertEq(p.spotsCap[0], spotsCap[0]);
        assertEq(p.spotsCap[1], spotsCap[1]);
        assertEq(p.spotsCap.length, spotsCap.length);
    }

    function test_PostProprosal_ActivateCredit(
        address _addr,
        uint256 _amount
    ) public {
        bytes memory payload;
        uint256 id = postProposal(
            owner,
            10,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.ACTIVATE_CREDIT,
            payload = getPayload_Credit(_addr, _amount),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.action), uint8(ICollective.Action.ACTIVATE_CREDIT));
        assertEq(p.payload, payload);

        (address addr, uint256 amount) = abi.decode(
            p.payload,
            (address, uint256)
        );
        assertEq(addr, _addr);
        assertEq(amount, _amount);
    }

    function test_PostProprosal_AdjustCredit(
        address _addr,
        uint256 _amount
    ) public {
        bytes memory payload;
        uint256 id = postProposal(
            owner,
            10,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.ADJUST_CREDIT,
            payload = getPayload_Credit(_addr, _amount),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.action), uint8(ICollective.Action.ADJUST_CREDIT));
        assertEq(p.payload, payload);

        (address addr, uint256 amount) = abi.decode(
            p.payload,
            (address, uint256)
        );
        assertEq(addr, _addr);
        assertEq(amount, _amount);
    }

    function test_PostProprosal_Request(
        bool credit,
        uint256 drop,
        uint256 reqId
    ) public {
        IBulletin.Request memory req = IBulletin.Request({
            from: address(collective),
            currency: (credit) ? address(0xc0d) : address(mock),
            drop: drop,
            data: BYTES,
            uri: TEST
        });
        bytes memory payload;
        uint256 id = postProposal(
            owner,
            30,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.POST_OR_UPDATE_REQUEST,
            payload = getPayload_Request(reqId, req),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(
            uint8(p.action),
            uint8(ICollective.Action.POST_OR_UPDATE_REQUEST)
        );
        assertEq(p.payload, payload);

        (uint256 subjectId, IBulletin.Request memory _req) = abi.decode(
            p.payload,
            (uint256, IBulletin.Request)
        );

        assertEq(subjectId, reqId);
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
            p.payload,
            (uint256, IBulletin.Resource)
        );

        assertEq(subjectId, 0);
        assertEq(res.from, _res.from);
        assertEq(res.uri, _res.uri);
        assertEq(res.data, _res.data);
    }

    function test_PostProposal_ApproveResponse(
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

    function test_PostProposal_ApproveExchange(
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
            p.payload,
            (uint256, uint256, uint256)
        );
        assertEq(sId, subjectId);
        assertEq(tId, tradeId);
        assertEq(_duration, duration);
    }

    function test_PostProprosal_Trade(uint8 tt, uint256 _subjectId) public {
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
            payload = getPayload_Trade(
                IBulletin.TradeType(tt),
                _subjectId,
                trade
            ),
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
                p.payload,
                (IBulletin.TradeType, uint256, IBulletin.Trade)
            );

        assertEq(subjectId, _subjectId);
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

    function test_PostProprosal_WithdrawRequest(uint256 _subjectId) public {
        bytes memory payload;
        uint256 id = postProposal(
            owner,
            10,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.WITHDRAW_REQUEST,
            payload = getPayload_WithdrawRequestOrResource(_subjectId),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.action), uint8(ICollective.Action.WITHDRAW_REQUEST));
        assertEq(p.payload, payload);

        uint256 subjectId = abi.decode(p.payload, (uint256));
        assertEq(subjectId, _subjectId);
    }

    function test_PostProprosal_WithdrawResource(uint256 _subjectId) public {
        bytes memory payload;
        uint256 id = postProposal(
            owner,
            10,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.WITHDRAW_RESOURCE,
            payload = getPayload_WithdrawRequestOrResource(_subjectId),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.action), uint8(ICollective.Action.WITHDRAW_RESOURCE));
        assertEq(p.payload, payload);

        uint256 subjectId = abi.decode(p.payload, (uint256));
        assertEq(subjectId, _subjectId);
    }

    function test_PostProprosal_WithdrawTrade(
        uint8 _tt,
        uint256 _subjectId,
        uint256 _tradeId
    ) public {
        vm.assume(uint8(type(IBulletin.TradeType).max) >= _tt);

        bytes memory payload;
        uint256 id = postProposal(
            owner,
            10,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.WITHDRAW_RESOURCE,
            payload = getPayload_WithdrawTrade(
                IBulletin.TradeType(_tt),
                _subjectId,
                _tradeId
            ),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.action), uint8(ICollective.Action.WITHDRAW_RESOURCE));
        assertEq(p.payload, payload);

        (IBulletin.TradeType tt, uint256 subjectId, uint256 tradeId) = abi
            .decode(p.payload, (IBulletin.TradeType, uint256, uint256));
        assertEq(uint8(_tt), uint8(tt));
        assertEq(subjectId, _subjectId);
        assertEq(tradeId, _tradeId);
    }

    function test_PostProprosal_Claim(
        uint8 _tt,
        uint256 _subjectId,
        uint256 _tradeId
    ) public {
        vm.assume(uint8(type(IBulletin.TradeType).max) >= _tt);

        bytes memory payload;
        uint256 id = postProposal(
            owner,
            10,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.CLAIM,
            payload = getPayload_Claim(
                IBulletin.TradeType(_tt),
                _subjectId,
                _tradeId
            ),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.action), uint8(ICollective.Action.CLAIM));
        assertEq(p.payload, payload);

        (IBulletin.TradeType tt, uint256 subjectId, uint256 tradeId) = abi
            .decode(p.payload, (IBulletin.TradeType, uint256, uint256));
        assertEq(uint8(_tt), uint8(tt));
        assertEq(subjectId, _subjectId);
        assertEq(tradeId, _tradeId);
    }

    function test_PostProprosal_Pause(
        uint256 _subjectId,
        uint256 _tradeId
    ) public {
        bytes memory payload;
        uint256 id = postProposal(
            owner,
            10,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.PAUSE,
            payload = getPayload_Pause(_subjectId, _tradeId),
            TEST
        );

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.action), uint8(ICollective.Action.PAUSE));
        assertEq(p.payload, payload);

        (uint256 subjectId, uint256 tradeId) = abi.decode(
            p.payload,
            (uint256, uint256)
        );
        assertEq(subjectId, _subjectId);
        assertEq(tradeId, _tradeId);
    }
}
