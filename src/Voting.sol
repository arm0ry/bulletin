// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";
import {BERC6909} from "src/BERC6909.sol";

import {console} from "lib/forge-std/src/console.sol";

enum Scaling {
    ONE_ADD_ONE_VOTE,
    ONE_ADD_SCALED_VOTES
}

enum Tally {
    SIMPLE_MAJORITY,
    SIMPLE_MAJORITY_QUORUM_REQUIRED,
    SUPERMAJORITY,
    SUPERMAJORITY_QUORUM_REQUIRED,
    QUADRATIC,
    QUADRATIC_QUORUM_REQUIRED,
    CONVICTION,
    CONVICTION_QUOUM_REQUIRED
}

enum ProposalType {
    ACTIVATE_CREDIT,
    ADJUST_CREDIT,
    POST_REQUEST,
    UPDATE_REQUEST,
    WITHDRAW_REQUEST,
    APPROVE_RESPONSE,
    POST_RESOURCE,
    UPDATE_RESOURCE,
    WITHDRAW_RESOURCE,
    APPROVE_EXCHANGE,
    CLAIM,
    PAUSE
}

struct Proposal {
    ProposalType pt;
    Scaling s;
    Tally t;
    uint8 quorum;
    uint40 timestamp;
    address proposer;
    uint256[] roles;
    uint256[] weights;
    bytes payload; // proposal content
    string doc;
}

struct Vote {
    uint40 timestamp;
    bool yay;
}

/// @title Bulletin
/// @notice A system to store and interact with requests and resources.
/// @author audsssy.eth
contract Voting {
    error Denied();

    uint40 proposalId;

    uint40 gracePeriod; // starts after proposal meets passing requirement

    address internal bulletin;

    mapping(uint256 id => Proposal) public proposals;

    mapping(uint256 id => mapping(address voter => bool)) public votes;

    /* -------------------------------------------------------------------------- */
    /*                                Constructor.                                */
    /* -------------------------------------------------------------------------- */

    function init() external {
        // todo: init bulletin
        // todo: init grace period
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Governance.                                */
    /* -------------------------------------------------------------------------- */

    function propose(Proposal calldata prop) external {
        // Check permission.
        IBulletin.Credit memory c = IBulletin(bulletin).getCredit(msg.sender);
        if (c.limit == 0) revert Denied();

        // Check parity.
        if (prop.roles.length != prop.weights.length) revert Denied();

        // Check quorum.
        if (prop.quorum > 100) revert Denied();

        // Check proposal payload.
        if (verifyPayload(prop.pt, prop.payload)) revert Denied();

        proposals[proposalId++] = prop;
    }

    function vote(uint256 id, bool yay) external {
        // todo: check role
        // todo: check if voted already
        // todo: check if prop is processed
        // todo: record vote
    }

    function process(uint256 id) external {}

    /* -------------------------------------------------------------------------- */
    /*                                  Internal.                                 */
    /* -------------------------------------------------------------------------- */

    function verifyPayload(
        ProposalType pt,
        bytes calldata payload
    ) internal pure returns (bool) {
        if (
            pt == ProposalType.ACTIVATE_CREDIT ||
            pt == ProposalType.ADJUST_CREDIT
        ) {
            (address user, uint256 limit) = abi.decode(
                payload,
                (address, uint256)
            );
        } else if (
            pt == ProposalType.POST_REQUEST || pt == ProposalType.UPDATE_REQUEST
        ) {
            (uint256 id, IBulletin.Request memory req) = abi.decode(
                payload,
                (uint256, IBulletin.Request)
            );
        } else if (
            pt == ProposalType.POST_RESOURCE ||
            pt == ProposalType.UPDATE_RESOURCE
        ) {
            (uint256 id, IBulletin.Resource memory res) = abi.decode(
                payload,
                (uint256, IBulletin.Resource)
            );
        } else if (
            pt == ProposalType.APPROVE_RESPONSE ||
            pt == ProposalType.APPROVE_EXCHANGE
        ) {
            (uint256 s, uint256 t, uint256 a, uint40 d) = abi.decode(
                payload,
                (uint256, uint256, uint256, uint40)
            );
        } else if (
            pt == ProposalType.WITHDRAW_REQUEST ||
            pt == ProposalType.WITHDRAW_RESOURCE
        ) {
            uint256 id = abi.decode(payload, (uint256));
            return true;
        } else if (pt == ProposalType.CLAIM) {} else if (
            pt == ProposalType.PAUSE
        ) {
            (uint256 s, uint256 t) = abi.decode(payload, (uint256, uint256));
            return true;
        } else {
            return false;
        }

        return true;
    }

    function credit(ProposalType pt, address user, uint256 limit) internal {
        if (pt == ProposalType.ACTIVATE_CREDIT)
            IBulletin(bulletin).activate(user, limit);
        else if (pt == ProposalType.ADJUST_CREDIT)
            IBulletin(bulletin).adjust(user, limit);
        else return;
    }

    function post(
        ProposalType pt,
        uint256 id,
        IBulletin.Request calldata req,
        IBulletin.Resource calldata res
    ) internal {
        if (pt == ProposalType.POST_REQUEST)
            IBulletin(bulletin).request(0, req);
        else if (pt == ProposalType.UPDATE_REQUEST)
            IBulletin(bulletin).request(id, req);
        else if (pt == ProposalType.POST_RESOURCE)
            IBulletin(bulletin).resource(0, res);
        else if (pt == ProposalType.UPDATE_RESOURCE)
            IBulletin(bulletin).resource(0, res);
        else return;
    }

    function approve(
        ProposalType pt,
        uint256 subjectId,
        uint256 tradeId,
        uint256 amount,
        uint40 duration
    ) internal {
        if (pt == ProposalType.APPROVE_RESPONSE)
            IBulletin(bulletin).approveResponse(subjectId, tradeId, amount);
        else if (pt == ProposalType.APPROVE_EXCHANGE)
            IBulletin(bulletin).approveExchange(subjectId, tradeId, duration);
        else return;
    }

    function withdraw(ProposalType pt, uint256 id) internal {
        if (pt == ProposalType.WITHDRAW_REQUEST)
            IBulletin(bulletin).withdrawRequest(id);
        else if (pt == ProposalType.WITHDRAW_RESOURCE)
            IBulletin(bulletin).withdrawResource(id);
        else return;
    }

    function claim(
        IBulletin.TradeType tradeType,
        uint256 subjectId,
        uint256 tradeId
    ) internal {
        IBulletin(bulletin).claim(tradeType, subjectId, tradeId);
    }

    function pause(uint256 subjectId, uint256 tradeId) internal {
        IBulletin(bulletin).pause(subjectId, tradeId);
    }
}
