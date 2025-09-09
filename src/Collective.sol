// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IBulletin} from "src/interface/IBulletin.sol";
import {ICollective} from "src/interface/ICollective.sol";
import {Bulletin} from "src/Bulletin.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "lib/solady/src/utils/FixedPointMathLib.sol";
import {console} from "lib/forge-std/src/console.sol";

/// @title Collective Module for governing bulletin.
/// @notice A control center for Bulletin actions.
/// @author audsssy.eth
contract Collective is ICollective {
    address public bulletin;
    uint40 public gracePeriod; // auto starts after proposal meets quorum
    uint40 public proposalId;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => uint256) public ballotIdsPerProposal;
    mapping(uint256 => uint256) public improvementIdsPerProposal;

    mapping(uint256 => mapping(uint256 => Ballot)) public ballots;
    mapping(uint256 => mapping(uint256 => Improvement)) public improvements;

    /* -------------------------------------------------------------------------- */
    /*                                Constructor.                                */
    /* -------------------------------------------------------------------------- */

    function init(address _bulletin, uint40 _grace) external {
        bulletin = _bulletin;
        gracePeriod = _grace;
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
        ) revert Denounced();

        _;
    }

    modifier credited() {
        // Insufficient `Bulletin.Credit.limit`.
        IBulletin.Credit memory c = IBulletin(bulletin).getCredit(msg.sender);
        if (c.limit == 0) revert Denied();

        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Proposals.                                 */
    /* -------------------------------------------------------------------------- */

    function propose(Proposal calldata prop) external credited undenounced {
        // Check array parity.
        if (prop.roles.length == 0) revert RolesUndefined();
        if (prop.roles.length != prop.weights.length) revert LengthMismatch();
        if (prop.weights.length != prop.spots.length) revert LengthMismatch();

        // Check quorum.
        if (prop.quorum > 100) revert InvalidQuorum();

        // Check proposal payload and throws when payload cannot be decoded.
        handlePayload(false, prop.action, prop.payload);

        // Create proposal.
        Proposal storage p = proposals[++proposalId];
        p.timestamp = uint40(block.timestamp);
        p.proposer = msg.sender;

        // Store voting procedure.
        p.tally = prop.tally;
        p.quorum = prop.quorum;
        p.roles = prop.roles;
        p.weights = prop.weights;
        p.spots = prop.spots;

        // Store proposed action.
        p.action = prop.action;
        p.payload = prop.payload;
        p.doc = prop.doc;
    }

    function cancel(uint256 propId) external {
        Proposal storage p = proposals[propId];
        if (p.proposer != msg.sender) revert Denied();
        if (
            p.proposer == msg.sender &&
            (p.status == Status.ACTIVE || p.status == Status.SPONSORED)
        ) {
            p.status = Status.CANCELLED;
        } else revert Denied();
    }

    function sponsor(uint256 propId) external credited undenounced {
        Proposal storage p = proposals[propId];
        if (p.proposer == msg.sender) revert NotOriginalProposer();

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
        } else revert PropNotReady();
    }

    // User may vote until proposal is processed.
    function vote(
        bool yay,
        uint256 propId,
        uint256 role,
        uint256 amount
    ) external undenounced {
        Ballot storage b;
        Proposal storage p = proposals[propId];

        // Prop not ready to be voted on.
        if (p.status != Status.SPONSORED) revert PropNotReady();

        // Verify role.
        if (!Bulletin(bulletin).hasAnyRole(msg.sender, role))
            revert InvalidVoter();

        // Insufficient `Bulletin.Credit.limit`.
        IBulletin.Credit memory c = IBulletin(bulletin).getCredit(msg.sender);
        if (c.limit == 0) revert Denied();

        // Cap number of votes by voters' at credit limit.
        (amount > c.limit) ? amount = c.limit : amount;

        // If voter role is qualified to vote on proposal, retrieve voting weight.
        uint256 weight;
        uint256 length = p.roles.length;
        uint256 ballotId = hasVoted(propId, msg.sender);
        for (uint256 i; i < length; ++i) {
            if (role == p.roles[i]) {
                if (ballotId == 0) --p.spots[i];
                weight = p.weights[i];
            }
        }

        // Get ballot and update/verify voter.
        if (ballotId == 0) {
            b = ballots[propId][++ballotIdsPerProposal[propId]];
            b.voter = msg.sender;
        } else {
            // Verify original voter.
            b = ballots[propId][ballotId];
            if (b.voter != msg.sender) revert NotOriginalVoter();
        }

        // Update ballot.
        b.vote = yay;
        b.amount = (weight == 0) ? 1 ether : amount * weight;

        // If quorum is satisfied, update proposal status.
        if (isQuorum(ballotIdsPerProposal[propId], p)) {
            p.timestamp = uint40(block.timestamp);
            p.status = Status.GRACE;
        }
    }

    function process(uint256 propId) external {
        // Proposal not ready to process.
        Proposal storage p = proposals[propId];
        if (p.status != Status.GRACE) revert PropNotReady();

        uint256 ids = ballotIdsPerProposal[propId];
        if (uint40(block.timestamp) > gracePeriod + p.timestamp) {
            uint256 yTotal;
            uint256 nTotal;
            Ballot storage b;

            // Count votes.
            for (uint256 i; i < ids; ++i) {
                b = ballots[propId][ids];
                if (p.tally == Tally.QUADRATIC)
                    (b.vote)
                        ? yTotal += FixedPointMathLib.sqrt(b.amount)
                        : nTotal += FixedPointMathLib.sqrt(b.amount);
                else (b.vote) ? yTotal += b.amount : nTotal += b.amount;
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
        } else revert PropNotReady();
    }

    /* -------------------------------------------------------------------------- */
    /*                                Improvements.                               */
    /* -------------------------------------------------------------------------- */

    // Suggest executable improvements.
    function raise(
        uint256 propId,
        Improvement calldata _imp
    ) external credited undenounced {
        Improvement storage imp;
        Proposal storage p = proposals[propId];
        if (p.status != Status.GRACE) revert PropNotReady();

        // Validate roles and action/payload.
        if (_imp.payload.length > 0)
            handlePayload(false, _imp.action, _imp.payload);

        if (_imp.roles.length > 0) {
            if (_imp.roles.length != _imp.weights.length)
                revert LengthMismatch();
            if (_imp.weights.length != _imp.spots.length)
                revert LengthMismatch();
        }

        // Retrieve previous improvement, if available.
        uint256 impId = hasRaisedImprovement(propId, msg.sender);

        // Create new improvement or verify previous improvement.
        if (impId == 0) {
            imp = improvements[propId][++improvementIdsPerProposal[propId]];
            imp.proposer = msg.sender;
        } else {
            imp = improvements[propId][impId];
            if (imp.cosigns != 0) revert Denied();
        }

        // Store improvement.
        imp.subject = _imp.subject;
        if (bytes(_imp.doc).length > 0) imp.doc = _imp.doc;

        if (_imp.subject == Subject.ACTION) {
            if (bytes(_imp.payload).length == 0) revert Denied();
            imp.action = _imp.action;
            imp.payload = _imp.payload;
            if (bytes(_imp.doc).length > 0) imp.doc = _imp.doc;
        } else if (_imp.subject == Subject.ROLES) {
            if (_imp.roles.length == 0) revert Denied();
            imp.roles = _imp.roles;
            imp.weights = _imp.weights;
            imp.spots = _imp.spots;
            if (bytes(_imp.doc).length > 0) imp.doc = _imp.doc;
        } else if (_imp.subject == Subject.ACTION_AND_ROLES) {
            if (bytes(_imp.payload).length == 0) revert Denied();
            imp.action = _imp.action;
            imp.payload = _imp.payload;
            if (_imp.roles.length == 0) revert Denied();
            imp.roles = _imp.roles;
            imp.weights = _imp.weights;
            imp.spots = _imp.spots;
            if (bytes(_imp.doc).length > 0) imp.doc = _imp.doc;
        } else if (_imp.subject == Subject.ACTION_AND_ROLES) imp.doc = _imp.doc;
    }

    function cosign(
        uint256 propId,
        uint256 impId
    ) external credited undenounced {
        Proposal storage p = proposals[propId];
        Improvement storage imp = improvements[propId][impId];
        if (imp.proposer == address(0)) revert ImpNotReady();

        // Increment improvement cosign.
        unchecked {
            ++imp.cosigns;
        }

        // Pause proposal for deliberation.
        if (p.status != Status.PAUSED_FOR_IMPROVEMENT)
            p.status = Status.PAUSED_FOR_IMPROVEMENT;
        p.timestamp = uint40(block.timestamp);
    }

    function amend() external {
        // effectuate improvement
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal.                                 */
    /* -------------------------------------------------------------------------- */

    function handlePayload(
        bool execute,
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
            if (execute) credit(action, addr, number);
        } else if (
            action == Action.POST_REQUEST || action == Action.UPDATE_REQUEST
        ) {
            (subjectId, req) = abi.decode(
                payload,
                (uint256, IBulletin.Request)
            );
            if (execute) post(action, subjectId, req, res);
        } else if (
            action == Action.POST_RESOURCE || action == Action.UPDATE_RESOURCE
        ) {
            (subjectId, res) = abi.decode(
                payload,
                (uint256, IBulletin.Resource)
            );
            if (execute) post(action, subjectId, req, res);
        } else if (
            action == Action.APPROVE_RESPONSE ||
            action == Action.APPROVE_EXCHANGE
        ) {
            uint40 duration;
            (subjectId, tradeId, number, duration) = abi.decode(
                payload,
                (uint256, uint256, uint256, uint40)
            );
            if (execute) approve(action, subjectId, tradeId, number, duration);
        } else if (action == Action.TRADE) {
            (tt, subjectId, t) = abi.decode(
                payload,
                (IBulletin.TradeType, uint256, IBulletin.Trade)
            );
            if (execute) trade(tt, subjectId, t);
        } else if (
            action == Action.WITHDRAW_REQUEST ||
            action == Action.WITHDRAW_RESOURCE
        ) {
            subjectId = abi.decode(payload, (uint256));
            if (execute) withdraw(action, tt, subjectId, tradeId);
        } else if (action == Action.WITHDRAW_TRADE) {
            (tt, subjectId, tradeId) = abi.decode(
                payload,
                (IBulletin.TradeType, uint256, uint256)
            );
            if (execute) withdraw(action, tt, subjectId, tradeId);
        } else if (action == Action.CLAIM) {
            (tt, subjectId, tradeId) = abi.decode(
                payload,
                (IBulletin.TradeType, uint256, uint256)
            );
            if (execute) claim(tt, subjectId, tradeId);
        } else if (action == Action.PAUSE) {
            (subjectId, tradeId) = abi.decode(payload, (uint256, uint256));
            if (execute) pause(subjectId, tradeId);
        } else return false;
        return true;
    }

    function isQuorum(
        uint256 votes,
        Proposal storage p
    ) internal view returns (bool) {
        uint256 totalVotes;
        uint256 length = p.spots.length;
        for (uint256 i; i < length; ++i) totalVotes += p.spots[i];
        return ((votes * 100) / totalVotes >= p.quorum);
    }

    function hasVoted(
        uint256 propId,
        address voter
    ) internal view returns (uint256 id) {
        uint256 length = ballotIdsPerProposal[propId];

        Ballot storage b;
        for (uint256 i; i < length; ++i) {
            b = ballots[propId][i];
            if (b.voter == voter) return i;
        }
    }

    function hasRaisedImprovement(
        uint256 propId,
        address proposer
    ) internal view returns (uint256 id) {
        Improvement storage imp;
        uint256 length = improvementIdsPerProposal[propId];
        for (uint256 i; i < length; ++i) {
            imp = improvements[propId][i];
            if (imp.proposer == proposer) return i;
        }
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

    /* -------------------------------------------------------------------------- */
    /*                                 Public Get.                                */
    /* -------------------------------------------------------------------------- */

    function getProposal(uint256 id) external view returns (Proposal memory) {
        return proposals[id];
    }

    function getBallot(
        uint256 propId,
        uint256 ballotId
    ) external view returns (Ballot memory) {
        return ballots[propId][ballotId];
    }

    function getImprovement(
        uint256 propId,
        uint256 impId
    ) external view returns (Improvement memory) {
        return improvements[propId][impId];
    }

    receive() external payable {}
}
