// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {CollectiveTest} from "test/collective/Collective_Base.t.sol";
import {BulletinTest} from "test/bulletin/Bulletin_Base.t.sol";
import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {ICollective} from "src/interface/ICollective.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

contract CollectiveTest_Vote is Test, CollectiveTest {
    function test_Vote_Status_Voted(bool decision, uint256 votes) public {
        // uint256 _roles = bulletin.rolesOf(bob);
        // emit ICollective.CheckNumber(_roles);
        // bool isDenounced = bulletin.hasAnyRole(bob, bulletin.DENOUNCED());
        // emit ICollective.CheckBool(isDenounced);

        vm.assume(10 ether > votes);

        roles[0] = ARTISTS;
        roles[1] = OPERATIONS;
        spotsCap[0] = 2;
        spotsCap[1] = 2;
        uint256 artistsSpotsUsed = spotsCap[0];
        uint256 operationsSpotsUsed = spotsCap[1];

        bytes memory payload;
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.QUADRATIC,
            ICollective.Action.NONE,
            payload,
            TEST
        );

        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        vm.prank(bob);
        collective.sponsor(id);
        ICollective.Proposal memory p = collective.getProposal(id);

        vm.prank(bob);
        collective.vote(decision, id, ARTISTS, votes);

        uint256 ballotId = collective.ballotIdsPerProposal(id);
        ICollective.Ballot memory b = collective.getBallot(id, ballotId);
        assertEq(b.decision, decision);
        assertEq(b.voter, bob);
        assertEq(b.size, votes * weights[0]);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.VOTED));
        assertEq(p.spotsUsed[0], artistsSpotsUsed - 1);

        vm.prank(alice);
        collective.vote(decision, id, OPERATIONS, votes);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.VOTED));
        assertEq(p.spotsUsed[1], operationsSpotsUsed - 1);

        ballotId = collective.ballotIdsPerProposal(id);
        b = collective.getBallot(id, ballotId);
        assertEq(b.decision, decision);
        assertEq(b.voter, alice);
        assertEq(b.size, votes * weights[1]);
    }

    function test_Vote_Status_NotPassed(
        bool decision,
        uint256 firstVotes,
        uint256 secondVotes
    ) public {
        decision = true;
        vm.assume(5 ether > firstVotes);

        roles[0] = ARTISTS;
        roles[1] = OPERATIONS;
        spotsCap[0] = 1;
        spotsCap[1] = 1;
        uint256 artistsSpotsUsed = spotsCap[0];
        uint256 operationsSpotsUsed = spotsCap[1];

        bytes memory payload;
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.NONE,
            payload,
            TEST
        );

        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        vm.prank(bob);
        collective.sponsor(id);
        ICollective.Proposal memory p = collective.getProposal(id);

        vm.prank(bob);
        collective.vote(decision, id, ARTISTS, firstVotes);

        uint256 ballotId = collective.ballotIdsPerProposal(id);
        ICollective.Ballot memory b = collective.getBallot(id, ballotId);
        assertEq(b.decision, decision);
        assertEq(b.voter, bob);
        assertEq(b.size, firstVotes * weights[0]);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.VOTED));
        assertEq(p.spotsUsed[0], artistsSpotsUsed - 1);

        vm.assume(10 ether > secondVotes);
        vm.assume(secondVotes > firstVotes);
        vm.prank(alice);
        collective.vote(!decision, id, OPERATIONS, secondVotes);

        ballotId = collective.ballotIdsPerProposal(id);
        b = collective.getBallot(id, ballotId);
        assertEq(b.decision, !decision);
        assertEq(b.voter, alice);
        assertEq(b.size, secondVotes * weights[1]);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.NOT_PASSED));
        assertEq(p.spotsUsed[1], operationsSpotsUsed - 1);
    }

    function test_Vote_Status_Deliberation(
        bool decision,
        uint256 firstVotes,
        uint256 secondVotes
    ) public {
        vm.assume(5 ether > firstVotes);
        vm.assume(secondVotes > 10 ether);

        roles[0] = ARTISTS;
        roles[1] = OPERATIONS;
        spotsCap[0] = 1;
        spotsCap[1] = 1;
        uint256 artistsSpotsUsed = spotsCap[0];

        bytes memory payload;
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.NONE,
            payload,
            TEST
        );

        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        vm.prank(bob);
        collective.sponsor(id);
        ICollective.Proposal memory p = collective.getProposal(id);

        vm.prank(bob);
        collective.vote(decision, id, ARTISTS, firstVotes);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.VOTED));
        assertEq(p.spotsUsed[0], artistsSpotsUsed -= 1);

        // post improvement proposal
        uint256 impId = postImpProposal(
            uint40(id),
            owner,
            80,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.NONE,
            payload,
            TEST
        );

        // bob cosigns
        vm.prank(bob);
        collective.sponsor(impId);
        ICollective.Proposal memory impP = collective.getProposal(impId);
        assertEq(uint8(impP.status), uint8(ICollective.Status.COSIGNED));

        // alice votes
        vm.prank(alice);
        collective.vote(decision, id, OPERATIONS, secondVotes);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.DELIBERATION));
    }

    function test_UpdateVote(bool decision, uint256 votes) public {
        vm.assume(10 ether > votes);

        roles[0] = ARTISTS;
        roles[1] = OPERATIONS;
        spotsCap[0] = 2;
        spotsCap[1] = 2;
        uint256 artistsSpotsUsed = spotsCap[0];

        bytes memory payload;
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.QUADRATIC,
            ICollective.Action.NONE,
            payload,
            TEST
        );

        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, ARTISTS);

        // Bob votes.
        vm.prank(bob);
        collective.sponsor(id);
        ICollective.Proposal memory p = collective.getProposal(id);

        vm.prank(bob);
        collective.vote(decision, id, ARTISTS, votes);

        uint256 bobBallotId = collective.ballotIdsPerProposal(id);
        ICollective.Ballot memory b = collective.getBallot(id, bobBallotId);
        assertEq(b.decision, decision);
        assertEq(b.voter, bob);
        assertEq(b.size, votes * weights[0]);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.VOTED));
        assertEq(p.spotsUsed[0], artistsSpotsUsed -= 1);

        // Alice votes.
        vm.prank(alice);
        collective.vote(decision, id, ARTISTS, votes);

        uint256 aliceBallotId = collective.ballotIdsPerProposal(id);
        b = collective.getBallot(id, aliceBallotId);
        assertEq(b.decision, decision);
        assertEq(b.voter, alice);
        assertEq(b.size, votes * weights[0]);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.VOTED));
        assertEq(p.spotsUsed[0], artistsSpotsUsed -= 1);

        // Bob updates previous vote before quorum is reached.
        vm.prank(bob);
        collective.vote(!decision, id, ARTISTS, votes / 2);

        b = collective.getBallot(id, bobBallotId);
        assertEq(b.decision, !decision);
        assertEq(b.voter, bob);
        assertEq(b.size, (votes / 2) * weights[0]);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.VOTED));
        assertEq(p.spotsUsed[0], artistsSpotsUsed);
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Processed.                                 */
    /* -------------------------------------------------------------------------- */

    function test_Vote_Status_Processed_ActivateCredit(uint256 votes) public {
        vm.assume(5 ether > votes);
        vm.assume(votes > 0);

        bool decision = true;
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.QUADRATIC,
            ICollective.Action.ACTIVATE_CREDIT,
            getPayload_Credit(charlie, 20 ether),
            TEST
        );

        // grant roles
        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        // sponsor
        sponsor(bob, id);

        // voting by two members
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        // check proposal status
        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.PROCESSED));

        // check Bulletin.sol for posting
        IBulletin.Credit memory credit = bulletin.getCredit(charlie);
        assertEq(credit.limit, 20 ether);
        assertEq(credit.amount, 20 ether);
    }

    function test_Vote_Status_Processed_AdjustCredit(uint256 votes) public {
        vm.assume(5 ether > votes);
        vm.assume(votes > 0);

        bool decision = true;
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.QUADRATIC,
            ICollective.Action.ADJUST_CREDIT,
            getPayload_Credit(alice, 5 ether),
            TEST
        );

        // grant roles
        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        // sponsor
        sponsor(bob, id);

        // voting by two members
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        // check proposal status
        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.PROCESSED));

        // check Bulletin.sol for posting
        IBulletin.Credit memory credit = bulletin.getCredit(alice);
        assertEq(credit.limit, 5 ether);
        assertEq(credit.amount, 5 ether);
    }

    function test_Vote_Status_Processed_PostRequest(uint256 votes) public {
        vm.assume(5 ether > votes);
        vm.assume(votes > 0);

        bool decision = true;
        IBulletin.Request memory req = IBulletin.Request({
            from: address(collective),
            currency: address(0xc0d),
            drop: votes,
            data: BYTES,
            uri: TEST
        });
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.QUADRATIC,
            ICollective.Action.POST_OR_UPDATE_REQUEST,
            getPayload_Request(0, req),
            TEST
        );

        // grant roles
        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        // sponsor
        sponsor(bob, id);

        // voting by two members
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        // check proposal status
        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.PROCESSED));

        // check Bulletin.sol for posting
        IBulletin.Request memory _request = bulletin.getRequest(1);
        assertEq(_request.from, req.from);
        assertEq(_request.currency, req.currency);
        assertEq(_request.drop, req.drop);
        assertEq(_request.data, req.data);
        assertEq(_request.uri, req.uri);

        IBulletin.Credit memory credit = bulletin.getCredit(
            address(collective)
        );
        assertEq(credit.amount, 10 ether - votes);
    }

    function test_Vote_Status_Processed_PostResource(uint256 votes) public {
        vm.assume(5 ether > votes);
        vm.assume(votes > 0);

        bool decision = true;
        IBulletin.Resource memory res = IBulletin.Resource({
            from: address(collective),
            data: BYTES,
            uri: TEST
        });
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.QUADRATIC,
            ICollective.Action.POST_OR_UPDATE_RESOURCE,
            getPayload_Resource(0, res),
            TEST
        );

        // grant roles
        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        // sponsor
        sponsor(bob, id);

        // voting by two members
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        // check proposal status
        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.PROCESSED));

        // check Bulletin.sol for posting
        IBulletin.Resource memory _resource = bulletin.getResource(1);
        assertEq(_resource.from, address(collective));
        assertEq(_resource.data, BYTES);
        assertEq(_resource.uri, TEST);
    }

    function test_Vote_Status_Processed_ApproveResponse(uint256 votes) public {
        vm.assume(5 ether > votes);
        vm.assume(votes > 0);

        bool decision = true;
        IBulletin.Request memory req = IBulletin.Request({
            from: address(collective),
            currency: address(0xc0d),
            drop: votes,
            data: BYTES,
            uri: TEST
        });
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.POST_OR_UPDATE_REQUEST,
            getPayload_Request(0, req),
            TEST
        );

        // grant roles
        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        // sponsor
        sponsor(bob, id);

        // alice and bob vote
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        // check proposal status
        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.PROCESSED));

        // charlie responds to request
        uint256 reqId = bulletin.requestId();
        uint256 tradeId = postTradeWithPromise(
            IBulletin.TradeType.RESPONSE,
            charlie,
            reqId,
            TEST2,
            BYTES2
        );

        // collective approves response
        id = postProposal(
            owner,
            51,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.APPROVE_RESPONSE,
            getPayload_ApproveTradeToRequest(reqId, tradeId, votes / 3),
            TEST
        );

        // sponsor
        sponsor(bob, id);

        // alice and bob vote on proposal to approve trade
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        // verify
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            reqId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, charlie);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, 0);
        assertEq(trade.duration, 0);
        assertEq(trade.currency, address(0xc0d));
        assertEq(trade.amount, votes / 3);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST2);
        assertEq(trade.data, BYTES2);

        assertEq(
            bulletin.balanceOf(
                charlie,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.RESPONSE,
                    uint40(reqId),
                    uint40(tradeId)
                )
            ),
            1
        );
    }
    function test_Vote_Status_Processed_ApproveExchange(uint256 votes) public {
        vm.assume(5 ether > votes);
        vm.assume(votes > 0);

        bool decision = true;
        IBulletin.Resource memory res = IBulletin.Resource({
            from: address(collective),
            data: BYTES,
            uri: TEST
        });
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.POST_OR_UPDATE_RESOURCE,
            getPayload_Resource(0, res),
            TEST
        );

        // grant roles
        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        // sponsor
        sponsor(bob, id);

        // alice and bob vote
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        // charlie trades for resource
        uint256 resId = bulletin.resourceId();
        activate(address(bulletin), owner, charlie, 5 ether);
        uint256 tradeId = postTradeWithCurrency(
            IBulletin.TradeType.EXCHANGE,
            charlie,
            resId,
            address(0xc0d),
            3 ether
        );

        // collective approves response
        id = postProposal(
            owner,
            51,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.APPROVE_EXCHANGE,
            getPayload_ApproveTradeForResource(resId, tradeId, 1 weeks),
            TEST
        );

        // sponsor
        sponsor(bob, id);

        // alice and bob vote on proposal to approve trade
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        // verify
        IBulletin.Trade memory trade = bulletin.getTrade(
            IBulletin.TradeType.EXCHANGE,
            resId,
            tradeId
        );
        assertEq(trade.approved, true);
        assertEq(trade.from, charlie);
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, uint40(block.timestamp));
        assertEq(trade.duration, 1 weeks);
        assertEq(trade.currency, address(0xc0d));
        assertEq(trade.amount, 3 ether);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        assertEq(
            bulletin.balanceOf(
                charlie,
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.EXCHANGE,
                    uint40(resId),
                    uint40(tradeId)
                )
            ),
            1
        );
        assertEq(
            bulletin.balanceOf(
                address(collective),
                bulletin.encodeTokenId(
                    address(bulletin),
                    IBulletin.TradeType.EXCHANGE,
                    uint40(resId),
                    uint40(tradeId)
                )
            ),
            1
        );
    }

    function test_Vote_Status_Processed_Trade(
        uint256 votes,
        uint256 tradeAmount
    ) public {
        vm.assume(5 ether > votes);
        vm.assume(votes > 0);
        vm.assume(5 ether > tradeAmount);
        vm.assume(tradeAmount > 0);

        IBulletin.Credit memory credit = bulletin.getCredit(
            address(collective)
        );

        uint256 requestId = postRequestWithCredit(owner, votes);

        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            timestamp: uint40(block.timestamp),
            duration: 2 weeks,
            from: address(collective),
            resource: 0,
            currency: address(0xc0d),
            amount: tradeAmount,
            content: TEST,
            data: BYTES
        });
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.TRADE,
            getPayload_Trade(IBulletin.TradeType.RESPONSE, requestId, trade),
            TEST
        );

        // grant roles
        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        // sponsor
        sponsor(bob, id);

        // alice and bob vote
        bool decision = true;
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        // check proposal status
        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.PROCESSED));

        // verify trade is submitted
        uint256 tradeId = bulletin.tradeIdsPerRequest(requestId);
        trade = bulletin.getTrade(
            IBulletin.TradeType.RESPONSE,
            requestId,
            tradeId
        );
        assertEq(trade.approved, false);
        assertEq(trade.from, address(collective));
        assertEq(trade.paused, false);
        assertEq(trade.timestamp, uint40(block.timestamp));
        assertEq(trade.duration, 0);
        assertEq(trade.currency, address(0xc0d));
        assertEq(trade.amount, tradeAmount);
        assertEq(trade.resource, 0);
        assertEq(trade.content, TEST);
        assertEq(trade.data, BYTES);

        IBulletin.Credit memory _credit = bulletin.getCredit(
            address(collective)
        );
        assertEq(_credit.amount, credit.amount - tradeAmount);
    }

    function test_Vote_Status_Processed_WithdrawRequest(uint256 votes) public {
        vm.assume(5 ether > votes);
        vm.assume(votes > 0);

        bool decision = true;
        IBulletin.Request memory req = IBulletin.Request({
            from: address(collective),
            currency: address(0xc0d),
            drop: votes,
            data: BYTES,
            uri: TEST
        });
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.QUADRATIC,
            ICollective.Action.POST_OR_UPDATE_REQUEST,
            getPayload_Request(0, req),
            TEST
        );

        // grant roles
        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        // sponsor
        sponsor(bob, id);

        // voting by two members
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        // post withdraw proposal
        uint256 reqId = bulletin.requestId();
        id = postProposal(
            owner,
            51,
            ICollective.Tally.QUADRATIC,
            ICollective.Action.WITHDRAW_REQUEST,
            getPayload_WithdrawRequestOrResource(reqId),
            TEST
        );

        // sponsor
        sponsor(bob, id);

        // voting by two members
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        // check Bulletin.sol for posting
        IBulletin.Request memory _request = bulletin.getRequest(reqId);
        assertEq(_request.from, address(0));
        assertEq(_request.currency, address(0));
        assertEq(_request.drop, 0);
        assertEq(_request.data, "");
        assertEq(_request.uri, "");

        IBulletin.Credit memory credit = bulletin.getCredit(
            address(collective)
        );
        assertEq(credit.amount, 10 ether);
    }

    function test_Vote_Status_Processed_WithdrawResource(uint256 votes) public {
        vm.assume(5 ether > votes);
        vm.assume(votes > 0);

        bool decision = true;
        IBulletin.Resource memory res = IBulletin.Resource({
            from: address(collective),
            data: BYTES,
            uri: TEST
        });
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.POST_OR_UPDATE_RESOURCE,
            getPayload_Resource(0, res),
            TEST
        );

        // grant roles
        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        // sponsor
        sponsor(bob, id);

        // alice and bob vote
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        // collective proposes to withdraw resource
        uint256 resId = bulletin.resourceId();
        id = postProposal(
            owner,
            51,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.WITHDRAW_RESOURCE,
            getPayload_WithdrawRequestOrResource(resId),
            TEST
        );

        // sponsor
        sponsor(bob, id);

        // alice and bob vote on proposal to approve trade
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        IBulletin.Resource memory _res = bulletin.getResource(resId);
        assertEq(_res.from, address(0));
        assertEq(_res.data, "");
        assertEq(_res.uri, "");
    }

    function test_Vote_Status_Processed_WithdrawTrade(
        uint256 votes,
        uint256 tradeAmount
    ) public {
        vm.assume(5 ether > votes);
        vm.assume(votes > 0);
        vm.assume(5 ether > tradeAmount);
        vm.assume(tradeAmount > 0);

        IBulletin.Credit memory credit = bulletin.getCredit(
            address(collective)
        );

        uint256 requestId = postRequestWithCredit(owner, votes);

        IBulletin.Trade memory trade = IBulletin.Trade({
            approved: true,
            paused: false,
            timestamp: uint40(block.timestamp),
            duration: 2 weeks,
            from: address(collective),
            resource: 0,
            currency: address(0xc0d),
            amount: tradeAmount,
            content: TEST,
            data: BYTES
        });
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.TRADE,
            getPayload_Trade(IBulletin.TradeType.RESPONSE, requestId, trade),
            TEST
        );

        // grant roles
        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        // sponsor
        sponsor(bob, id);

        // alice and bob vote
        bool decision = true;
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        IBulletin.Credit memory c = bulletin.getCredit(address(collective));
        assertEq(c.amount, credit.amount - tradeAmount);

        // collective proposes to withdraw trade
        uint256 tradeId = bulletin.tradeIdsPerRequest(requestId);
        id = postProposal(
            owner,
            51,
            ICollective.Tally.SIMPLE_MAJORITY,
            ICollective.Action.WITHDRAW_TRADE,
            getPayload_WithdrawTrade(
                IBulletin.TradeType.RESPONSE,
                requestId,
                tradeId
            ),
            TEST
        );

        // sponsor
        sponsor(bob, id);

        // alice and bob vote
        vote(bob, decision, id, ARTISTS, votes);
        vote(alice, decision, id, OPERATIONS, votes);

        // verify
        IBulletin.Credit memory _credit = bulletin.getCredit(
            address(collective)
        );
        assertEq(_credit.amount, credit.amount);
    }
    function test_Vote_Status_Processed_Claim(uint256 votes) public {}
    function test_Vote_Status_Processed_Pause(uint256 votes) public {}

    function test_Vote_Status_Processed_ActionNone(uint256 votes) public {
        vm.assume(20 ether > votes);
        vm.assume(votes > 0);

        bool decision = true;
        roles[0] = ARTISTS;
        roles[1] = OPERATIONS;
        spotsCap[0] = 1;
        spotsCap[1] = 1;
        uint256 artistsSpotsUsed = spotsCap[0];

        bytes memory payload;
        uint256 id = postProposal(
            owner,
            50,
            ICollective.Tally.QUADRATIC,
            ICollective.Action.NONE,
            payload,
            TEST
        );

        grantRole(address(bulletin), owner, bob, ARTISTS);

        vm.prank(bob);
        collective.sponsor(id);
        ICollective.Proposal memory p = collective.getProposal(id);

        vm.prank(bob);
        collective.vote(decision, id, ARTISTS, votes);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.PROCESSED));
        assertEq(p.spotsUsed[0], artistsSpotsUsed - 1);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Reverts.                                  */
    /* -------------------------------------------------------------------------- */

    function testRevert_Vote_VoterRoleMismatch(
        bool decision,
        uint256 votes
    ) public {
        vm.assume(10 ether > votes);

        roles[0] = ARTISTS;
        roles[1] = OPERATIONS;

        bytes memory payload;
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.QUADRATIC,
            ICollective.Action.NONE,
            payload,
            TEST
        );

        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        vm.prank(bob);
        collective.sponsor(id);

        vm.expectRevert(ICollective.VoterRoleMismatch.selector);
        vm.prank(alice);
        collective.vote(decision, id, ARTISTS, votes);
    }

    function testRevert_Vote_NotQualified(bool decision, uint256 votes) public {
        vm.assume(10 ether > votes);

        bytes memory payload;
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.QUADRATIC,
            ICollective.Action.NONE,
            payload,
            TEST
        );

        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, RELATIONS);

        vm.prank(bob);
        collective.sponsor(id);

        vm.expectRevert(ICollective.NotQualified.selector);
        vm.prank(alice);
        collective.vote(decision, id, RELATIONS, votes);
    }

    function testRevert_Vote_PropNotReady(bool decision, uint256 votes) public {
        vm.assume(10 ether > votes);

        bytes memory payload;
        uint256 id = postProposal(
            owner,
            51,
            ICollective.Tally.QUADRATIC,
            ICollective.Action.NONE,
            payload,
            TEST
        );

        grantRole(address(bulletin), owner, alice, ARTISTS);

        vm.expectRevert(ICollective.PropNotReady.selector);
        vm.prank(alice);
        collective.vote(decision, id, ARTISTS, votes);
    }
}
