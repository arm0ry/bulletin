// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @dev Contract for Bulletin.
/// Bulletin is a board of on-chain asks and offerings.
interface IBulletin {
    /* -------------------------------------------------------------------------- */
    /*                                  Structs.                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev A struct containing all the data required for creating a request.
     */
    struct Request {
        bool fulfilled;
        address owner;
        string title;
        string detail;
        address currency;
        uint256 drop;
    }

    /**
     * @dev A struct containing all the data required for providing a resource.
     */
    struct Resource {
        bool active;
        address owner;
        string title;
        string detail;
    }

    /**
     * @dev A struct containing all the data required for a trade for request and resource.
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

    event RequestUpdated(uint256 indexed requestId);
    event ResourceUpdated(uint256 indexed resourceId);
    event ResponseUpdated(uint256 requestId, uint256 responseId, address from);
    event ExchangeUpdated(uint256 resourceId, uint256 exchangeId, address from);
    event TradeProcessed(
        uint256 indexed requestId,
        uint256 tradeId,
        bool approved
    );
    event RequestSettled(
        uint256 indexed requestId,
        uint256 indexed numOfTrades
    );

    /* -------------------------------------------------------------------------- */
    /*                                   Errors.                                  */
    /* -------------------------------------------------------------------------- */

    error InsufficientAmount();
    error InvalidOriginalPoster();
    error DuplicativeTrade();
    error AlreadyFulfilled();
    error Approved();
    error SettlementMismatch();
    error TotalPercentageMustBeTenThousand();
    error ResourceNotActive();
    error ResourceNotValid();

    /* -------------------------------------------------------------------------- */
    /*                     Public / External Write Functions.                     */
    /* -------------------------------------------------------------------------- */

    function request(Request calldata r) external payable;
    function respond(
        uint256 requestId,
        uint256 respondId,
        Trade calldata t
    ) external payable;
    function resource(Resource calldata r) external;
    function exchange(
        uint256 resourceId,
        uint256 exchangeId,
        Trade calldata t
    ) external payable;

    function withdrawRequest(uint256 requestId) external;
    function settleRequest(
        uint40 _requestId,
        bool approved,
        uint40 role,
        uint16[] calldata percentages
    ) external;
    function withdrawResource(uint256 _resourceId) external;
    function approveResponse(uint256 requestId, uint256 responseId) external;
    function approveExchange(uint256 _resourceId, uint256 exchangeId) external;

    /* -------------------------------------------------------------------------- */
    /*                      Public / External View Functions.                     */
    /* -------------------------------------------------------------------------- */

    function getRequest(uint256 id) external view returns (Request memory r);

    function getResource(uint256 id) external view returns (Resource memory r);

    function getTrade(
        uint256 id,
        uint256 tradeId
    ) external view returns (Trade memory t);

    function filterTrades(
        uint256 id,
        bool approved,
        uint40 role
    ) external returns (Trade[] memory _trades);

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
