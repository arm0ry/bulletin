// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @dev Contract for Bulletin.
/// Bulletin is a board of on-chain asks and offerings.
interface IBulletin {
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
        string title;
        string detail;
        address currency;
        uint256 drop;
    }

    /**
     * @dev A struct containing data required for creating a resource.
     */
    struct Resource {
        address from;
        address beneficiary;
        string title;
        string detail;
    }

    /**
     * @dev A struct containing data required for creating responses and exchanges.
     */
    struct Trade {
        bool approved;
        address from;
        bytes32 resource;
        address currency;
        uint256 amount;
        string content;
        bytes data; // reserved for responses, externalities, etc.
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Events.                                  */
    /* -------------------------------------------------------------------------- */

    event RequestUpdated(uint256 requestId);
    event ResourceUpdated(uint256 resourceId);
    event TradeUpdated(bool isResponse, uint256 subjectId, uint256 tradeId);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors.                                  */
    /* -------------------------------------------------------------------------- */

    error NotOriginalPoster();
    error Approved();

    /* -------------------------------------------------------------------------- */
    /*                     Public / External Write Functions.                     */
    /* -------------------------------------------------------------------------- */

    function request(Request calldata r) external;
    function respond(uint256 requestId, Trade calldata t) external;
    function resource(Resource calldata r) external;
    function exchange(uint256 resourceId, Trade calldata t) external;

    function withdrawRequest(uint256 requestId) external;
    function withdrawResource(uint256 resourceId) external;

    function withdrawTrade(
        bool isResponse,
        uint256 requestId,
        uint256 responseId
    ) external;

    function approveResponse(
        uint256 requestId,
        uint256 responseId,
        uint256 amount
    ) external;
    function approveExchange(uint256 resourceId, uint256 exchangeId) external;

    /* -------------------------------------------------------------------------- */
    /*                      Public / External View Functions.                     */
    /* -------------------------------------------------------------------------- */

    function getRequest(uint256 id) external view returns (Request memory r);

    function getResource(uint256 id) external view returns (Resource memory r);

    function getTrade(
        bool isResponse,
        uint256 requestId,
        uint256 responseId
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
