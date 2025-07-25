// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @dev Contract for Bulletin.
/// Bulletin is a board of on-chain asks and offerings.
interface IBulletin {
    enum TradeType {
        RESPONSE, // responses to requests
        EXCHANGE // exchanges for resources
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Structs.                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev A struct containing data required for creating a credit line.
     */
    struct Credit {
        uint256 limit; // Spending limit
        uint256 amount;
    }

    /**
     * @dev A struct containing data required for creating a request.
     */
    struct Request {
        address from;
        address currency;
        uint256 drop;
        bytes data;
        string uri;
    }

    /**
     * @dev A struct containing data required for creating a resource.
     */
    struct Resource {
        address from;
        // uint48 supply;
        bytes data; // title, detail
        string uri;
    }

    /**
     * @dev A struct containing data required for creating responses and exchanges.
     */
    struct Trade {
        bool approved;
        bool paused;
        uint40 timestamp; // reserved for `access()` and `claim()`
        uint40 duration;
        address from;
        bytes32 resource;
        address currency; // `0xbeef` reserved for staking, `address(0)` reserved for credit uses
        uint256 amount;
        string content;
        bytes data; // reserved for responses, externalities, etc.
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Events.                                  */
    /* -------------------------------------------------------------------------- */

    event RequestUpdated(uint256 requestId);
    event ResourceUpdated(uint256 resourceId);
    event TradeUpdated(TradeType tradeType, uint256 subjectId, uint256 tradeId);
    event Accessed(uint256 subjectId, uint256 tradeId);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors.                                  */
    /* -------------------------------------------------------------------------- */

    error Denied();
    error Approved();
    error Activated();
    error Denounced();

    error DropRequired();
    error InvalidTrade();
    error InvalidTransfer();
    error NotYetActivated();
    error NotOriginalPoster();

    /* -------------------------------------------------------------------------- */
    /*                                Permissoins.                                */
    /* -------------------------------------------------------------------------- */

    function hasAnyRole(address user, uint256 roles) external returns (bool);

    /* -------------------------------------------------------------------------- */
    /*                                   Credit.                                  */
    /* -------------------------------------------------------------------------- */

    function activate(address user, uint256 limit) external;
    function adjust(address user, uint256 limit) external;

    /* -------------------------------------------------------------------------- */
    /*                     Public / External Write Functions.                     */
    /* -------------------------------------------------------------------------- */

    function request(uint256 requestId, Request calldata r) external;
    function resource(uint256 resourceId, Resource calldata r) external;
    function trade(
        TradeType tradeType,
        uint256 resourceId,
        Trade calldata t
    ) external;

    function withdrawRequest(uint256 requestId) external;
    function withdrawResource(uint256 resourceId) external;
    function withdrawTrade(
        TradeType tradeType,
        uint256 subjectId,
        uint256 tradeId
    ) external;

    function approveResponse(
        uint256 requestId,
        uint256 responseId,
        uint256 amount
    ) external;
    function approveExchange(
        uint256 resourceId,
        uint256 exchangeId,
        uint40 deadline
    ) external;

    function claim(
        TradeType tradeType,
        uint256 subjectId,
        uint256 tradeId
    ) external;

    function pause(uint256 subjectId, uint256 tradeId) external;

    /* -------------------------------------------------------------------------- */
    /*                      Public / External View Functions.                     */
    /* -------------------------------------------------------------------------- */

    function getRequest(uint256 id) external view returns (Request memory r);

    function getResource(uint256 id) external view returns (Resource memory r);

    function getTrade(
        TradeType tradeType,
        uint256 subjectId,
        uint256 tradeId
    ) external view returns (Trade memory);

    function getCredit(address user) external view returns (Credit memory c);

    /* -------------------------------------------------------------------------- */
    /*                      Public / External Pure Functions.                     */
    /* -------------------------------------------------------------------------- */

    function encodeAsset(
        address bulletin,
        uint96 id
    ) external pure returns (bytes32 asset);

    function decodeAsset(
        bytes32 asset
    ) external pure returns (address bulletin, uint96 id);
}
