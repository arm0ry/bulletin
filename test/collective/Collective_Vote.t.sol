// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {CollectiveTest_Base} from "test/collective/Collective_Base.t.sol";
import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {ICollective} from "src/interface/ICollective.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

contract CollectiveTest_Vote is Test, CollectiveTest_Base {
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

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.VOTED));
        assertEq(p.spotsUsed[0], artistsSpotsUsed - 1);

        vm.prank(alice);
        collective.vote(decision, id, OPERATIONS, votes);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.VOTED));
        assertEq(p.spotsUsed[1], operationsSpotsUsed - 1);
    }

    function test_Vote_Status_Processed_ActionBasedProp(uint256 votes) public {
        vm.assume(5 ether > votes);
        vm.assume(votes > 0);

        bool decision = true;
        roles[0] = ARTISTS;
        roles[1] = OPERATIONS;
        spotsCap[0] = 1;
        spotsCap[1] = 1;

        bytes memory payload;
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
            payload = getPayload_Request(0, req),
            TEST
        );

        // grant roles
        grantRole(address(bulletin), owner, bob, ARTISTS);
        grantRole(address(bulletin), owner, alice, OPERATIONS);

        // sponsor
        vm.prank(bob);
        collective.sponsor(id);
        ICollective.Proposal memory p = collective.getProposal(id);

        // voting by two members
        vm.prank(bob);
        collective.vote(decision, id, ARTISTS, votes);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.VOTED));

        vm.prank(alice);
        collective.vote(decision, id, OPERATIONS, votes);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.PROCESSED));

        // check Bulletin.sol for posting
        IBulletin.Request memory _request = bulletin.getRequest(1);
        assertEq(_request.from, address(collective));
        assertEq(_request.currency, address(0xc0d));
        assertEq(_request.drop, votes);
        assertEq(_request.data, BYTES);
        assertEq(_request.uri, TEST);

        IBulletin.Credit memory credit = bulletin.getCredit(
            address(collective)
        );
        assertEq(credit.amount, 10 ether - votes);
    }

    function test_Vote_Status_Processed_ActionlessBasedProp(
        uint256 votes
    ) public {
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

    function test_Vote_Status_NotPassed(
        uint256 firstVotes,
        uint256 secondVotes
    ) public {
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
        collective.vote(true, id, ARTISTS, firstVotes);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.VOTED));
        assertEq(p.spotsUsed[0], artistsSpotsUsed - 1);

        vm.assume(secondVotes > 10 ether);
        vm.prank(alice);
        collective.vote(false, id, OPERATIONS, secondVotes);

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

        // alice votes again
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

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.VOTED));
        assertEq(p.spotsUsed[0], artistsSpotsUsed -= 1);

        // Alice votes.
        vm.prank(alice);
        collective.vote(decision, id, ARTISTS, votes);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.VOTED));
        assertEq(p.spotsUsed[0], artistsSpotsUsed -= 1);

        // Bob updates previous vote before quorum is reached.
        vm.prank(bob);
        collective.vote(!decision, id, ARTISTS, votes);

        p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.VOTED));
        assertEq(p.spotsUsed[0], artistsSpotsUsed);
    }

    function testRevert_Vote_NotQualified(bool decision, uint256 votes) public {
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

    function testRevert_Vote_PropNotReady(bool decision, uint256 votes) public {
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

        grantRole(address(bulletin), owner, alice, ARTISTS);

        vm.expectRevert(ICollective.PropNotReady.selector);
        vm.prank(alice);
        collective.vote(decision, id, ARTISTS, votes);
    }
}
