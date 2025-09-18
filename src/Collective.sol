// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IBulletin} from "src/interface/IBulletin.sol";
import {ICollective} from "src/interface/ICollective.sol";
import {Bulletin} from "src/Bulletin.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "lib/solady/src/utils/FixedPointMathLib.sol";
import {LibString} from "lib/solady/src/utils/LibString.sol";
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
    // mapping(uint256 => uint256) public improvementIdsPerProposal;

    mapping(uint256 => mapping(uint256 => Ballot)) public ballots;
    // mapping(uint256 => mapping(uint256 => Improvement)) public improvements;

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
    /*                               Post Proposals.                              */
    /* -------------------------------------------------------------------------- */

    function propose(
        uint256 propId,
        Proposal calldata prop
    ) public credited undenounced {
        _propose(false, propId, prop);
    }

    // Raise improvement proposals.
    function raise(
        uint256 propId,
        Proposal calldata prop
    ) external credited undenounced {
        Proposal storage p = proposals[prop.targetProp];
        if (p.status != Status.SPONSORED) revert PropNotReady();

        _propose(true, propId, prop);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Update Proposals.                             */
    /* -------------------------------------------------------------------------- */

    function sponsor(uint256 propId) external credited undenounced {
        Proposal storage p = proposals[propId];
        if (p.proposer == msg.sender) revert Denied();
        if (p.status != Status.ACTIVE) revert PropNotReady();

        // Check role.
        uint256 length = p.roles.length;
        for (uint256 i; i < length; ++i)
            if (Bulletin(bulletin).hasAnyRole(msg.sender, p.roles[i]))
                p.status = Status.SPONSORED;
    }

    function cancel(uint256 propId) external {
        Proposal storage p = proposals[propId];
        if (p.proposer != msg.sender) revert NotOriginalProposer();
        if (p.status == Status.ACTIVE || p.status == Status.SPONSORED) {
            p.status = Status.CANCELLED;
        } else revert PropNotReady();
    }

    // amend prop by requiring proposal proposer and improvement proposer to sign off. Proposers should represent the collective.
    function amend(uint256 propId, Subject subject) external undenounced {
        Proposal storage p = proposals[propId];
        if (p.status != Status.DELIBERATION) revert PropNotReady();

        string memory doc = p.doc;

        // Proposer of target proposal can amend.
        p = proposals[p.targetProp];
        if (p.proposer != msg.sender) revert NotOriginalProposer();

        if (subject == Subject.ACTION) {
            // todo: `Subject.ACTION` amendments can process immediately
        } else if (
            subject == Subject.SETTING || subject == Subject.ACTION_AND_SETTING
        ) {
            // todo: `Subject.SETTING` and `Subject.ACTION_AND_SETTING` amendments require revote
        }

        if (bytes(doc).length != 0) {
            doc = LibString.concat(", ", doc);
            doc = LibString.concat(p.doc, doc);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                               Vote & Process.                              */
    /* -------------------------------------------------------------------------- */

    // Voter may vote until proposal is processed.
    // If voter has multiple roles, Voter may pick a role to vote with
    function vote(
        bool decision,
        uint256 propId,
        uint256 role,
        uint256 amount
    ) external undenounced {
        Ballot storage b;
        Proposal storage p = proposals[propId];

        // Prop not ready to be voted on.
        if (p.status != Status.SPONSORED) revert PropNotReady();

        // Insufficient `Bulletin.Credit.limit`.
        IBulletin.Credit memory c = IBulletin(bulletin).getCredit(msg.sender);
        if (c.limit == 0) revert Denied();

        // Cap number of votes by voters' at credit limit.
        (amount > c.limit) ? amount = c.limit : amount;

        // If voter role is qualified to vote on proposal, add/update ballot.
        bool isQualified;
        uint256 length = p.roles.length;
        uint256 ballotId = hasVoted(propId, msg.sender);
        for (uint256 i; i < length; ++i) {
            if (role == p.roles[i]) {
                if (ballotId == 0) {
                    --p.spots[i];
                    isQualified = true;

                    b = ballots[propId][++ballotIdsPerProposal[propId]];
                    b.voter = msg.sender;
                    b.vote = decision;
                    b.amount = (p.weights[i] == 0)
                        ? 1 ether
                        : amount * p.weights[i];
                } else {
                    // Verify original voter.
                    b = ballots[propId][ballotId];
                    if (b.voter != msg.sender) revert NotOriginalVoter();
                    b.vote = decision;
                    b.amount = (p.weights[i] == 0)
                        ? 1 ether
                        : amount * p.weights[i];
                }
            }
        }
        if (!isQualified) revert InvalidVoter();

        // Check quorum.
        if (atQuorum(ballotIdsPerProposal[propId], p)) {
            // if improvement prop exists and sponsored, prop moves to deliberation
            // otherwise, count votes to execute prop
            if (toDeliberate(propId)) p.status = Status.DELIBERATION;
            else if (passProposal(propId, ballotIdsPerProposal[propId], p))
                handlePayload(true, p.action, p.payload);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal.                                 */
    /* -------------------------------------------------------------------------- */

    function _propose(
        bool isImprovementProp,
        uint256 propId,
        Proposal memory prop
    ) internal {
        // Check array parity.
        if (prop.roles.length == 0) revert RolesUndefined();
        if (prop.roles.length != prop.weights.length) revert LengthMismatch();
        if (prop.weights.length != prop.spots.length) revert LengthMismatch();

        // Check quorum.
        if (prop.quorum > 100) revert InvalidQuorum();

        // Check proposal payload and throws when payload cannot be decoded.
        handlePayload(false, prop.action, prop.payload);

        // Create proposal.
        Proposal storage p;
        if (propId == 0) {
            p = proposals[++proposalId];
            p.proposer = msg.sender;
        } else {
            p = proposals[propId];
            if (p.proposer != msg.sender) revert Denied();
        }

        unchecked {
            // Store vote setting.
            p.tally = prop.tally;
            if (isImprovementProp) p.targetProp = prop.targetProp;
            p.quorum = prop.quorum;
            p.roles = prop.roles;
            p.weights = prop.weights;
            p.spots = prop.spots;

            // Store proposed action.
            p.action = prop.action;
            p.payload = prop.payload;
            p.doc = prop.doc;
        }
    }

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

    function atQuorum(
        uint256 numOfBallots,
        Proposal storage p
    ) internal view returns (bool) {
        uint256 totalBallots;
        uint256 length = p.spots.length;
        for (uint256 i; i < length; ++i) totalBallots += p.spots[i];
        return ((numOfBallots * 100) / totalBallots >= p.quorum);
    }

    function toDeliberate(uint256 propId) internal view returns (bool) {
        Proposal storage p;
        for (uint256 i; i < proposalId; ++i) {
            p = proposals[i];
            if (p.targetProp == propId && p.status == Status.SPONSORED)
                return true;
        }
    }

    function passProposal(
        uint256 propId,
        uint256 numOfBallots,
        Proposal storage p
    ) internal returns (bool passed) {
        uint256 yTotal;
        uint256 nTotal;
        Ballot storage b;

        unchecked {
            // Count votes.
            for (uint256 i; i < numOfBallots; ++i) {
                b = ballots[propId][i];
                if (p.tally == Tally.QUADRATIC)
                    (b.vote)
                        ? yTotal += FixedPointMathLib.sqrt(b.amount)
                        : nTotal += FixedPointMathLib.sqrt(b.amount);
                else (b.vote) ? yTotal += b.amount : nTotal += b.amount;
            }

            // Decide if proposal passes.
            if (p.tally == Tally.SUPERMAJORITY) {
                if (yTotal > (2 * (yTotal + nTotal)) / 3) passed = true;
            } else {
                if (yTotal > nTotal) passed = true;
            }
        }
    }

    /// @notice Action-based internal functions.

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

    // function getImprovement(
    //     uint256 propId,
    //     uint256 impId
    // ) external view returns (Improvement memory) {
    //     return improvements[propId][impId];
    // }

    receive() external payable {}
}
