// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @dev Contract for Bulletin.
/// Bulletin is a board of on-chain asks and offerings.
interface ICollective {
    // Proposal Enums.
    enum Status {
        ACTIVE,
        SPONSORED,
        DELIBERATION,
        COSIGNED,
        APPROVED,
        REJECTED,
        PROCESSED,
        UNSUCCESSFUL,
        CANCELLED,
        CLOSED
    }

    enum Tally {
        SIMPLE_MAJORITY,
        SUPERMAJORITY,
        QUADRATIC
    }

    enum Action {
        NONE,
        ACTIVATE_CREDIT,
        ADJUST_CREDIT,
        POST_OR_UPDATE_REQUEST,
        WITHDRAW_REQUEST,
        APPROVE_RESPONSE,
        POST_OR_UPDATE_RESOURCE,
        WITHDRAW_RESOURCE,
        APPROVE_EXCHANGE,
        CLAIM,
        PAUSE,
        TRADE,
        WITHDRAW_TRADE
    }

    // Improvement Enums.
    enum Amendment {
        SUBSTANCE,
        PROCEDURAL,
        REJECT
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Structs.                                  */
    /* -------------------------------------------------------------------------- */

    struct Proposal {
        Status status;
        Action action;
        Tally tally;
        uint8 targetProp; // reserved for improvement proposals
        uint8 quorum;
        address proposer;
        bytes payload;
        string doc;
        // voters
        uint256[] roles;
        uint256[] weights; // unsigned integer, 0 decimal
        uint256[] spots; // unsigned integer, 0 decimal
    }

    struct Ballot {
        bool decision;
        address voter;
        uint256 amount;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Events.                                  */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------------------------------------------------- */
    /*                                   Errors.                                  */
    /* -------------------------------------------------------------------------- */

    error Denied();
    error NotVoter();
    error Denounced();
    error ImpNotReady();
    error NotProposer();
    error NotQualified();
    error PropNotReady();
    error InvalidVoter();
    error NotCollective();
    error InvalidQuorum();
    error PropInProgress();
    error LengthMismatch();
    error RolesUndefined();

    event CheckNumber(uint256);
    event CheckBool(bool);

    /* -------------------------------------------------------------------------- */
    /*                                 Governance.                                */
    /* -------------------------------------------------------------------------- */

    function propose(uint256 propId, Proposal calldata prop) external;
    function raise(uint256 propId, Proposal calldata prop) external;
    function sponsor(uint256 propId) external;
    function terminate(uint256 propId, bool toCancel, bool toClose) external;
    function vote(
        bool vote,
        uint256 propId,
        uint256 role,
        uint256 amount
    ) external;

    /* -------------------------------------------------------------------------- */
    /*                      Public / External View Functions.                     */
    /* -------------------------------------------------------------------------- */

    function getProposal(uint256 id) external view returns (Proposal memory);
    function getBallot(
        uint256 propId,
        uint256 ballotId
    ) external view returns (Ballot memory);
}
