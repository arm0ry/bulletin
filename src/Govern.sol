// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IBulletin} from "src/interface/IBulletin.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";
import {console} from "lib/forge-std/src/console.sol";

enum Status {
    ACTIVE,
    GRACE,
    PROCESSED
}

enum Tally {
    SIMPLE_MAJORITY,
    SUPERMAJORITY,
    QUADRATIC,
    CONVICTION
}

enum Action {
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
    PAUSE,
    TRANSFER,
    BATCH_TRANSFER,
    TRADE,
    WITHDRAW_TRADE
}

struct Proposal {
    Status status;
    Action action;
    Tally tally;
    uint8 quorum;
    uint40 timestamp;
    address proposer;
    bytes payload; // proposal content
    string doc;
    // allowlist
    uint256[] roles;
    uint256[] weights;
    uint256[] spots;
}

struct Ballot {
    bool yay;
    uint40 id;
    uint40 timestamp;
    address voter;
    uint256 amount;
}

/// @title BackOffice
/// @notice A control center for action Bulletin.
/// @author audsssy.eth
contract Govern {
    error Denied();

    uint40 public proposalId;

    uint40 public gracePeriod; // starts after proposal meets passing requirement

    address public bulletin;

    mapping(uint256 id => Proposal) public proposals;

    mapping(uint256 id => uint256) public ballotIdsPerProposal;

    mapping(uint256 id => mapping(uint256 => Ballot)) public ballots;

    /* -------------------------------------------------------------------------- */
    /*                                Constructor.                                */
    /* -------------------------------------------------------------------------- */

    function init(address b, uint40 g) external credited {
        bulletin = b;
        gracePeriod = g;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Modifiers.                                 */
    /* -------------------------------------------------------------------------- */

    modifier credited() {
        // Insufficient `IBulletin.Credit.limit`.
        IBulletin.Credit memory c = IBulletin(bulletin).getCredit(msg.sender);
        if (c.limit == 0) revert Denied();

        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Governance.                                */
    /* -------------------------------------------------------------------------- */

    function propose(Proposal calldata prop) external credited {
        // Check allowlist parity.
        if (prop.roles.length != prop.weights.length) revert Denied();
        if (prop.weights.length != prop.spots.length) revert Denied();

        // Check quorum.
        if (prop.quorum > 100) revert Denied();

        // Check proposal payload.
        verifyPayload(prop.action, prop.payload);

        // Store prop settings.
        Proposal storage p = proposals[proposalId++];
        p.status = Status.ACTIVE;
        p.action = prop.action;
        p.tally = prop.tally;
        p.quorum = prop.quorum;

        // Store prop data.
        p.timestamp = uint40(block.timestamp);
        p.proposer = msg.sender;
        p.payload = prop.payload;
        p.doc = prop.doc;

        // Store allowlist.
        p.roles = prop.roles;
        p.weights = prop.weights;
        p.spots = prop.spots;
    }

    // User may vote until proposal is processed.
    function vote(
        uint256 propId,
        uint256 ballotId,
        bool yay,
        uint256 amount
    ) external returns (bool graceBegins) {
        // Insufficient `IBulletin.Credit.limit`.
        IBulletin.Credit memory c = IBulletin(bulletin).getCredit(msg.sender);
        if (c.limit == 0) revert Denied();

        // Proposal already processed.
        Proposal storage p = proposals[propId];
        if (p.status == Status.PROCESSED) revert Denied();

        // Not original voter.
        Ballot storage b = ballots[propId][ballotId];
        if (b.voter != msg.sender) revert Denied();

        // Get ballotId.
        (ballotId == 0) ? ballotId = ++ballotIdsPerProposal[propId] : ballotId;
        b = ballots[propId][ballotId];

        if (p.roles.length != 0) {
            uint256 length = p.roles.length;
            for (uint i; i < length; ++i) {
                // Loop for roles to scale votes.
                if (IBulletin(bulletin).hasAnyRole(msg.sender, p.roles[i])) {
                    // Record vote.
                    --p.spots[i];

                    b.yay = yay;
                    b.voter = msg.sender;
                    b.timestamp = uint40(block.timestamp);
                    b.amount = amount * p.weights[i]; // todo: double check math
                }

                if (graceBegins = quorumReached(ballotId, p)) {
                    p.timestamp = uint40(block.timestamp);
                    p.status = Status.GRACE;
                }
            }
        }
    }

    function process(uint256 id) external {
        uint256 ids = ballotIdsPerProposal[id];

        // Proposal not ready to process.
        Proposal storage p = proposals[id];
        if (p.status != Status.GRACE) revert Denied();

        if (uint40(block.timestamp) > gracePeriod + p.timestamp) {
            // Count raw votes.
            uint256 yTotal;
            uint256 nTotal;
            for (uint256 i; i < ids; ++i) {
                Ballot storage b = ballots[id][ids];
                // todo. check tally method.

                if (p.tally == Tally.SIMPLE_MAJORITY) {
                    (b.yay) ? yTotal = b.amount : nTotal = b.amount;
                    if (yTotal > nTotal) {
                        // todo: execute
                    }
                } else if (p.tally == Tally.SUPERMAJORITY) {
                    if (yTotal > nTotal) {
                        // todo: execute
                    }
                } else if (p.tally == Tally.QUADRATIC) {
                    if (yTotal > nTotal) {
                        // todo: execute
                    }
                } else if (p.tally == Tally.CONVICTION) {} else {
                    if (yTotal > nTotal) {
                        // todo: execute
                    }
                }
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal.                                 */
    /* -------------------------------------------------------------------------- */

    function verifyPayload(
        Action action,
        bytes calldata payload
    ) internal pure returns (bool) {
        address user;
        uint256 number;
        IBulletin.Request memory req;
        IBulletin.Resource memory res;

        if (
            action == Action.ACTIVATE_CREDIT || action == Action.ADJUST_CREDIT
        ) {
            (user, number) = abi.decode(payload, (address, uint256));
        } else if (
            action == Action.POST_REQUEST || action == Action.UPDATE_REQUEST
        ) {
            (number, req) = abi.decode(payload, (uint256, IBulletin.Request));
        } else if (
            action == Action.POST_RESOURCE || action == Action.UPDATE_RESOURCE
        ) {
            (number, res) = abi.decode(payload, (uint256, IBulletin.Resource));
        } else if (
            action == Action.APPROVE_RESPONSE ||
            action == Action.APPROVE_EXCHANGE
        ) {
            (number, number, number, number) = abi.decode(
                payload,
                (uint256, uint256, uint256, uint40)
            );
        } else if (
            action == Action.WITHDRAW_REQUEST ||
            action == Action.WITHDRAW_RESOURCE
        ) {
            number = abi.decode(payload, (uint256));
        } else if (action == Action.CLAIM) {
            (IBulletin.TradeType tt, uint256 s, uint256 t) = abi.decode(
                payload,
                (IBulletin.TradeType, uint256, uint256)
            );
        } else if (action == Action.PAUSE) {
            (number, number) = abi.decode(payload, (uint256, uint256));
        } else return false;
        return true;
    }

    function quorumReached(
        uint256 ballotId,
        Proposal storage p
    ) internal view returns (bool) {
        // Quorum not met.
        uint256 length = p.spots.length;
        uint256 sTotal = ballotId;
        for (uint256 i; i < length; ++i) sTotal += p.spots[i];
        return ((ballotId * 100) / sTotal > p.quorum);
    }

    function credit(Action action, address user, uint256 limit) internal {
        if (action == Action.ACTIVATE_CREDIT)
            IBulletin(bulletin).activate(user, limit);
        else if (action == Action.ADJUST_CREDIT)
            IBulletin(bulletin).adjust(user, limit);
        else return;
    }

    function post(
        Action action,
        uint256 id,
        IBulletin.Request calldata req,
        IBulletin.Resource calldata res
    ) internal {
        if (action == Action.POST_REQUEST) IBulletin(bulletin).request(0, req);
        else if (action == Action.UPDATE_REQUEST)
            IBulletin(bulletin).request(id, req);
        else if (action == Action.POST_RESOURCE)
            IBulletin(bulletin).resource(0, res);
        else if (action == Action.UPDATE_RESOURCE)
            IBulletin(bulletin).resource(0, res);
        else return;
    }

    function approve(
        Action action,
        uint256 subjectId,
        uint256 tradeId,
        uint256 amount,
        uint40 duration
    ) internal {
        if (action == Action.APPROVE_RESPONSE)
            IBulletin(bulletin).approveResponse(subjectId, tradeId, amount);
        else if (action == Action.APPROVE_EXCHANGE)
            IBulletin(bulletin).approveExchange(subjectId, tradeId, duration);
        else return;
    }

    function withdraw(Action action, uint256 id) internal {
        if (action == Action.WITHDRAW_REQUEST)
            IBulletin(bulletin).withdrawRequest(id);
        else if (action == Action.WITHDRAW_RESOURCE)
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
