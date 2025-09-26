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
    uint96 public proposalId;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => uint256) public ballotIdsPerProposal;
    mapping(uint256 => mapping(uint256 => Ballot)) public ballots;

    mapping(uint256 => Jar) jars;
    mapping(uint256 => mapping(address => uint256)) public deposits;

    /* -------------------------------------------------------------------------- */
    /*                                Constructor.                                */
    /* -------------------------------------------------------------------------- */

    function init(address _bulletin) external {
        bulletin = _bulletin;
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
    /*                           Interact w/ Proposals.                           */
    /* -------------------------------------------------------------------------- */

    function sponsor(uint256 propId) external credited undenounced {
        Proposal storage p = proposals[propId];
        if (p.proposer == msg.sender) revert Denied();
        if (p.status != Status.ACTIVE) revert PropNotReady();

        // Check role.
        uint256 length = p.roles.length;
        for (uint256 i; i < length; ++i)
            if (Bulletin(bulletin).hasAnyRole(msg.sender, p.roles[i]))
                (p.targetProp == 0)
                    ? p.status = Status.SPONSORED
                    : p.status = Status.COSIGNED;
    }

    function cancel(uint256 propId) external {
        Proposal storage p = proposals[propId];
        if (p.proposer != msg.sender) revert NotOriginalProposer();
        if (p.status == Status.ACTIVE || p.status == Status.SPONSORED) {
            p.status = Status.CANCELLED;
        } else revert PropNotReady();
    }

    // amend prop by requiring proposal proposer and improvement proposer to sign off. Proposers should represent the collective.
    function amend(
        Amendment amendment,
        uint256 propId,
        uint256 impPropId,
        string memory doc
    ) external undenounced {
        Proposal storage prop = proposals[propId];
        if (prop.status != Status.DELIBERATION) revert PropNotReady();
        if (prop.proposer != msg.sender) revert NotOriginalProposer();

        Proposal storage impProp = proposals[impPropId];
        if (prop.status != Status.COSIGNED) revert PropNotReady();

        // Update `doc` when available.
        if (bytes(impProp.doc).length != 0) {
            impProp.doc = LibString.concat(", ", impProp.doc);
            prop.doc = LibString.concat(prop.doc, impProp.doc);
        }

        // Update `doc` when available.
        if (bytes(doc).length != 0) {
            doc = LibString.concat(", ", doc);
            prop.doc = LibString.concat(prop.doc, doc);
        }

        if (amendment == Amendment.SUBSTANCE) {
            // `Amendment.SUBSTANCE` amendments can process immediately
            process(propId, true, impProp.action, impProp.payload);
            impProp.status = Status.PROCESSED;
        } else if (amendment == Amendment.PROCEDURAL) {
            // `Amendment.PROCEDURAL` amendments require voting on impProp
            impProp.status = Status.APPROVED;
        } else impProp.status = Status.REJECTED;
    }

    function close(uint256 propId) external credited undenounced {
        Proposal storage prop = proposals[propId];
        if (prop.status != Status.DELIBERATION) revert PropNotReady();
        if (prop.proposer != msg.sender) revert NotOriginalProposer();
        if (prop.targetProp != 0) revert Denied();
        prop.status = Status.CLOSED;
    }

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
        if (p.status != Status.SPONSORED && p.status != Status.APPROVED)
            revert PropNotReady();

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
                isQualified = true;
                if (ballotId == 0) {
                    --p.spots[i];

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
            if (p.targetProp == 0 && toDeliberate(propId)) {
                p.status = Status.DELIBERATION;
                return;
            }

            if (passProposal(propId, ballotIdsPerProposal[propId], p)) {
                process(propId, true, p.action, p.payload);
                p.status = Status.PROCESSED;
            } else p.status = Status.UNSUCCESSFUL;
        } else return;
    }

    function chipIn(uint256 propId, address currency, uint256 chip) public {
        Jar storage j = jars[propId];
        if (currency != j.currency) revert Denied();

        // amount need not exceed goal
        if (j.funded + chip > j.goal) {
            chip = j.funded + chip - j.goal;
        } else chip = chip;

        if (currency == address(0xc0d)) {
            IBulletin.Credit memory c = Bulletin(bulletin).getCredit(
                msg.sender
            );
            if (chip > c.amount) revert Denied();
            // todo. adjust credit in bulletin.sol
            // if (currency == address(0xc0d)) credits[from].amount -= amount;
        } else
            Bulletin(bulletin).route(currency, msg.sender, address(this), chip);

        // j.funded += amount;
        deposits[propId][msg.sender] += chip;
    }

    // todo. need a function for members to withdraw amount they chipped in

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
        process(propId, false, prop.action, prop.payload);

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

    function process(
        uint256 propId,
        bool execute,
        Action action,
        bytes memory payload
    ) internal {
        address addr;
        uint256 subjectId;
        uint256 tradeId;
        uint256 amount;

        if (
            action == Action.ACTIVATE_CREDIT || action == Action.ADJUST_CREDIT
        ) {
            (addr, amount) = abi.decode(payload, (address, uint256));
            if (execute) credit(action, addr, amount);
        } else if (action == Action.POST_OR_UPDATE_REQUEST) {
            IBulletin.Request memory req;
            (subjectId, req) = abi.decode(
                payload,
                (uint256, IBulletin.Request)
            );

            Jar storage j = jars[propId];
            if (execute) {
                if (j.goal != 0) revert Denied();
                IBulletin(bulletin).request(subjectId, req);
            } else {
                if (req.from != address(this)) revert Denied();
                j.currency = req.currency;
                j.goal = req.drop; // todo. need to consider update instances where req.drop is diff from j.goal, maybe can only increase funding when updating
            }
        } else if (action == Action.POST_OR_UPDATE_RESOURCE) {
            IBulletin.Resource memory res;
            (subjectId, res) = abi.decode(
                payload,
                (uint256, IBulletin.Resource)
            );
            if (execute) IBulletin(bulletin).resource(subjectId, res);
            else if (res.from != address(this)) revert Denied();
        } else if (action == Action.APPROVE_RESPONSE) {
            (subjectId, tradeId, amount) = abi.decode(
                payload,
                (uint256, uint256, uint256)
            );
            if (execute)
                IBulletin(bulletin).approveTradeToRequest(
                    subjectId,
                    tradeId,
                    amount
                );
        } else if (action == Action.APPROVE_EXCHANGE) {
            uint40 duration;
            (subjectId, tradeId, duration) = abi.decode(
                payload,
                (uint256, uint256, uint40)
            );
            if (execute)
                IBulletin(bulletin).approveTradeForResource(
                    subjectId,
                    tradeId,
                    duration
                );
        } else if (action == Action.TRADE) {
            IBulletin.TradeType tt;
            IBulletin.Trade memory t;
            (tt, subjectId, t) = abi.decode(
                payload,
                (IBulletin.TradeType, uint256, IBulletin.Trade)
            );
            if (execute) trade(tt, subjectId, t);
            // todo. need to set aside and lock drop, credit or currency, amount in this contract
        } else if (
            action == Action.WITHDRAW_REQUEST ||
            action == Action.WITHDRAW_RESOURCE
        ) {
            IBulletin.TradeType tt;
            subjectId = abi.decode(payload, (uint256));
            if (execute) withdraw(action, tt, subjectId, tradeId);
        } else if (action == Action.WITHDRAW_TRADE) {
            IBulletin.TradeType tt;
            (tt, subjectId, tradeId) = abi.decode(
                payload,
                (IBulletin.TradeType, uint256, uint256)
            );
            if (execute) withdraw(action, tt, subjectId, tradeId);
            // todo. members need to be able to withdraw spent credit/currency
        } else if (action == Action.CLAIM) {
            IBulletin.TradeType tt;
            (tt, subjectId, tradeId) = abi.decode(
                payload,
                (IBulletin.TradeType, uint256, uint256)
            );
            if (execute) claim(tt, subjectId, tradeId);
            // todo. members need to be able to reap benefits from collective claiming drop or payment for resources
        } else if (action == Action.PAUSE) {
            (subjectId, tradeId) = abi.decode(payload, (uint256, uint256));
            if (execute) pause(subjectId, tradeId);
        } else return;
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

    function toDeliberate(
        uint256 propId
    ) internal view returns (bool deliberate) {
        Proposal storage p;
        // Loops through all proposals for improvement proposals.
        for (uint256 i; i <= proposalId; ++i) {
            p = proposals[i];
            if (p.targetProp == propId && p.status == Status.SPONSORED)
                deliberate = true;
        }
    }

    function passProposal(
        uint256 propId,
        uint256 numOfBallots,
        Proposal storage p
    ) internal view returns (bool passed) {
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
    /*                                  Helpers.                                  */
    /* -------------------------------------------------------------------------- */

    function removeDenounced(address user) external {
        if (
            !Bulletin(bulletin).hasAnyRole(user, Bulletin(bulletin).DENOUNCED())
        ) revert Denied();

        Proposal storage p;
        for (uint256 i; i <= proposalId; ++i) {
            p = proposals[i];
            if (
                p.status == Status.ACTIVE ||
                p.status == Status.SPONSORED ||
                p.status == Status.COSIGNED
            ) {
                uint256 id = hasVoted(i, user);
                if (id != 0) delete ballots[i][id];
            }
        }
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

    receive() external payable {}
}
