// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IBulletin} from "src/interface/IBulletin.sol";
import {Bulletin} from "src/Bulletin.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "lib/solady/src/utils/FixedPointMathLib.sol";
import {console} from "lib/forge-std/src/console.sol";

enum Status {
    ACTIVE,
    SPONSORED,
    GRACE,
    PROCESSED,
    CANCELLED
}

enum Tally {
    SIMPLE_MAJORITY,
    SUPERMAJORITY,
    QUADRATIC
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
    uint256[] weights; // unsigned integer, 0 decimal
    uint256[] spots; // unsigned integer, 0 decimal
}

struct Ballot {
    bool yay;
    address voter;
    uint256 amount;
}

struct Objection {
    address user;
    string content;
}

/// @title Governor Module for governing bulletin.
/// @notice A control center for action Bulletin.
/// @author audsssy.eth
contract Governor {
    error Denied();

    uint16 public proposalId; // keeping it small for gas golfing

    uint40 public midpoint = 3 days; // for s-curve use only

    uint40 public gracePeriod; // starts after proposal meets passing requirement

    address public bulletin;

    mapping(uint256 => Proposal) public proposals;

    mapping(uint256 => uint256) public ballotIdsPerProposal;

    mapping(uint256 => mapping(uint256 => Ballot)) public ballots;

    mapping(uint256 => uint256) public objectionIdsPerProposal;

    mapping(uint256 => mapping(uint256 => Objection)) public objections;

    /* -------------------------------------------------------------------------- */
    /*                                Constructor.                                */
    /* -------------------------------------------------------------------------- */

    function init(address b, uint40 g) external {
        bulletin = b;
        gracePeriod = g;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Modifiers.                                 */
    /* -------------------------------------------------------------------------- */

    modifier undenounced() {
        // `Denounced` users may not propose.
        if (
            Bulletin(bulletin).hasAnyRole(
                msg.sender,
                Bulletin(bulletin).DENOUNCED()
            )
        ) revert Denied();

        _;
    }

    modifier onlyCredited() {
        // Insufficient `Bulletin.Credit.limit`.
        IBulletin.Credit memory c = IBulletin(bulletin).getCredit(msg.sender);
        if (c.limit == 0) revert Denied();

        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Governance.                                */
    /* -------------------------------------------------------------------------- */

    function propose(Proposal calldata prop) external onlyCredited undenounced {
        // Check array parity.
        if (prop.roles.length == 0) revert Denied();
        if (prop.roles.length != prop.weights.length) revert Denied();
        if (prop.weights.length != prop.spots.length) revert Denied();

        // Check quorum.
        if (prop.quorum > 100) revert Denied();

        // Check proposal payload.
        handlePayload(false, prop.action, prop.payload);

        // Store prop settings.
        Proposal storage p = proposals[++proposalId];
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

    function cancel(uint256 propId) external {
        Proposal storage p = proposals[propId];
        if (
            p.proposer == msg.sender &&
            (p.status == Status.ACTIVE || p.status == Status.SPONSORED)
        ) {
            p.status = Status.CANCELLED;
        } else revert Denied();
    }

    function sponsor(uint256 propId) external onlyCredited undenounced {
        Proposal storage p = proposals[propId];
        if (p.proposer == msg.sender) revert Denied();

        bool hasRole;
        uint256 length = p.roles.length;
        for (uint256 i; i < length; ++i) {
            // Check role.
            if (Bulletin(bulletin).hasAnyRole(msg.sender, p.roles[i]))
                hasRole = true;
        }

        // Sponsor proposal.
        if (hasRole && p.status == Status.ACTIVE) {
            p.status = Status.SPONSORED;
        } else revert Denied();
    }

    // User may vote until proposal is processed.
    function vote(
        bool yay,
        uint256 propId,
        uint256 ballotId,
        uint256 role,
        uint256 amount
    ) external onlyCredited returns (bool) {
        // Insufficient `Bulletin.Credit.limit`.
        IBulletin.Credit memory c = IBulletin(bulletin).getCredit(msg.sender);
        if (c.limit == 0) revert Denied();

        Proposal storage p = proposals[propId];
        if (p.status == Status.SPONSORED || p.status == Status.GRACE) {
            Ballot storage b;

            // Check role and retrieve weights to scale vote.
            bool hasRole;
            uint256 weight;
            uint256 length = p.roles.length;
            for (uint256 i; i < length; ++i) {
                if (
                    role == p.roles[i] &&
                    Bulletin(bulletin).hasAnyRole(msg.sender, role)
                ) {
                    hasRole = true;
                    weight = p.weights[i];
                    if (ballotId == 0) --p.spots[i];
                    break;
                }
            }

            if (ballotId == 0) {
                // Compute new ballotId.
                ballotId = ++ballotIdsPerProposal[propId];
                b = ballots[propId][ballotId];
                b.voter = msg.sender;
            } else {
                b = ballots[propId][ballotId];
                // Not original voter.
                if (b.voter != msg.sender) revert Denied();
            }

            // Store vote.
            b.yay = yay;
            b.amount = (weight == 0)
                ? 1e18 // one address one vote
                : ((amount > c.limit) ? c.limit : amount) * weight;
        } else revert Denied();

        // todo. do we need to check if status is in grace period?
        if (isQuorumSatisfied(ballotId, p) && p.status == Status.SPONSORED) {
            p.timestamp = uint40(block.timestamp);
            p.status = Status.GRACE;
            return true;
        } else return false;
    }

    function process(uint256 propId) external {
        // Proposal not ready to process.
        Proposal storage p = proposals[propId];
        if (p.status != Status.GRACE) revert Denied();

        uint256 ids = ballotIdsPerProposal[propId];
        if (uint40(block.timestamp) > gracePeriod + p.timestamp) {
            uint256 yTotal;
            uint256 nTotal;
            Ballot storage b;

            // Count votes.
            for (uint256 i; i < ids; ++i) {
                b = ballots[propId][ids];
                if (p.tally == Tally.QUADRATIC)
                    (b.yay)
                        ? yTotal += FixedPointMathLib.sqrt(b.amount)
                        : nTotal += FixedPointMathLib.sqrt(b.amount);
                else (b.yay) ? yTotal += b.amount : nTotal += b.amount;
            }

            // Execute if passed.
            if (
                p.tally == Tally.SIMPLE_MAJORITY || p.tally == Tally.QUADRATIC
            ) {
                // Execute.
                if (yTotal > nTotal) handlePayload(true, p.action, p.payload);
            } else {
                // Execute.
                if (yTotal > (2 * (yTotal + nTotal)) / 3)
                    handlePayload(true, p.action, p.payload);
            }
        }
    }

    function object(
        uint256 propId,
        string calldata obj
    ) external onlyCredited undenounced {
        if (proposalId > propId) {
            Proposal storage p = proposals[propId];
            if (p.status == Status.GRACE) {
                // Derive dynamic number of co-signs from total ballots.
                uint256 total;
                for (uint256 i = 1; i <= proposalId; ++i) {
                    total += ballotIdsPerProposal[i];
                }

                // Dynamic co-signs
                if (
                    (total / proposalId) / 3 > objectionIdsPerProposal[propId]
                ) {
                    uint256 id = ++objectionIdsPerProposal[propId];
                    objections[propId][id].user = msg.sender;
                    objections[propId][id].content = obj;
                } else {
                    // todo. extend grace period, i.e., update p.timestamp
                }
            } else revert Denied();
        } else revert Denied();
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal.                                 */
    /* -------------------------------------------------------------------------- */

    function handlePayload(
        bool passed,
        Action action,
        bytes memory payload
    ) internal returns (bool) {
        address addr;
        uint256 subjectId;
        uint256 tradeId;
        uint256 number;
        IBulletin.Request memory req;
        IBulletin.Resource memory res;
        IBulletin.Trade memory t;
        IBulletin.TradeType tt;

        if (
            action == Action.ACTIVATE_CREDIT || action == Action.ADJUST_CREDIT
        ) {
            (addr, number) = abi.decode(payload, (address, uint256));
            if (passed) credit(action, addr, number);
        } else if (
            action == Action.POST_REQUEST || action == Action.UPDATE_REQUEST
        ) {
            (subjectId, req) = abi.decode(
                payload,
                (uint256, IBulletin.Request)
            );
            if (passed) post(action, subjectId, req, res);
        } else if (
            action == Action.POST_RESOURCE || action == Action.UPDATE_RESOURCE
        ) {
            (subjectId, res) = abi.decode(
                payload,
                (uint256, IBulletin.Resource)
            );
            if (passed) post(action, subjectId, req, res);
        } else if (
            action == Action.APPROVE_RESPONSE ||
            action == Action.APPROVE_EXCHANGE
        ) {
            uint40 duration;
            (subjectId, tradeId, number, duration) = abi.decode(
                payload,
                (uint256, uint256, uint256, uint40)
            );
            if (passed) approve(action, subjectId, tradeId, number, duration);
        } else if (action == Action.TRADE) {
            (tt, subjectId, t) = abi.decode(
                payload,
                (IBulletin.TradeType, uint256, IBulletin.Trade)
            );
            if (passed) trade(tt, subjectId, t);
        } else if (
            action == Action.WITHDRAW_REQUEST ||
            action == Action.WITHDRAW_RESOURCE
        ) {
            subjectId = abi.decode(payload, (uint256));
            if (passed) withdraw(action, tt, subjectId, tradeId);
        } else if (action == Action.WITHDRAW_TRADE) {
            (tt, subjectId, tradeId) = abi.decode(
                payload,
                (IBulletin.TradeType, uint256, uint256)
            );
            if (passed) withdraw(action, tt, subjectId, tradeId);
        } else if (action == Action.CLAIM) {
            (tt, subjectId, tradeId) = abi.decode(
                payload,
                (IBulletin.TradeType, uint256, uint256)
            );
            if (passed) claim(tt, subjectId, tradeId);
        } else if (action == Action.PAUSE) {
            (subjectId, tradeId) = abi.decode(payload, (uint256, uint256));
            if (passed) pause(subjectId, tradeId);
        } else return false;
        return true;
    }

    function isQuorumSatisfied(
        uint256 ballotId,
        Proposal storage p
    ) internal view returns (bool) {
        // Quorum not met.
        uint256 length = p.spots.length;
        uint256 sTotal = ballotId;
        for (uint256 i; i < length; ++i) sTotal += p.spots[i];
        return ((ballotId * 100) / sTotal >= p.quorum);
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
        IBulletin.Request memory req,
        IBulletin.Resource memory res
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
            IBulletin(bulletin).approveTradeToRequest(
                subjectId,
                tradeId,
                amount
            );
        else if (action == Action.APPROVE_EXCHANGE)
            IBulletin(bulletin).approveTradeForResource(
                subjectId,
                tradeId,
                duration
            );
        else return;
    }

    function trade(
        IBulletin.TradeType tradeType,
        uint256 subjectId,
        IBulletin.Trade memory t
    ) internal {
        IBulletin(bulletin).trade(tradeType, subjectId, t);
    }

    function withdraw(
        Action action,
        IBulletin.TradeType tradeType,
        uint256 subjectId,
        uint256 tradeId
    ) internal {
        if (action == Action.WITHDRAW_REQUEST)
            IBulletin(bulletin).withdrawRequest(subjectId);
        else if (action == Action.WITHDRAW_RESOURCE)
            IBulletin(bulletin).withdrawResource(subjectId);
        else if (action == Action.WITHDRAW_TRADE)
            IBulletin(bulletin).withdrawTrade(tradeType, subjectId, tradeId);
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

    receive() external payable {}
}
