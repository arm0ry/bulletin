// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";
import {IERC20} from "src/interface/IERC20.sol";

/// @title Bulletin
/// @notice A system to store and interact with requests and resources.
/// @author audsssy.eth
contract Bulletin is OwnableRoles, IBulletin {
    /* -------------------------------------------------------------------------- */
    /*                                 Constants.                                 */
    /* -------------------------------------------------------------------------- */

    // The permissioned role reserved for autonomous agents.
    uint8 internal constant AGENTS = 1 << 0;

    // The permissioned role reserved for autonomous agents.
    uint8 internal constant EXTENSIONS = 1 << 1;

    /* -------------------------------------------------------------------------- */
    /*                                  Storage.                                  */
    /* -------------------------------------------------------------------------- */

    uint40 public requestId;
    uint40 public resourceId;

    // Mappings by user.
    mapping(address => Credit) internal credits;

    // Mappings by `requestId`.
    mapping(uint256 => Request) internal requests;
    mapping(uint256 => uint256) public responseIdsPerRequest;
    mapping(uint256 => mapping(uint256 => Trade)) internal responsesPerRequest; // Reciprocal events.

    // Mappings by `resourceId`.
    mapping(uint256 => Resource) internal resources;
    mapping(uint256 => uint256) public exchangeIdsPerResource;
    mapping(uint256 => mapping(uint256 => Trade)) internal exchangesPerResource; // Reciprocal events.

    /* -------------------------------------------------------------------------- */
    /*                                 Modifiers.                                 */
    /* -------------------------------------------------------------------------- */

    modifier isResourceAvailable(bytes32 source) {
        if (source != 0) {
            (address _b, uint256 _r) = decodeAsset(source);
            Resource memory r = IBulletin(_b).getResource(_r);
            if (r.from != msg.sender) revert NotOriginalPoster();
        }

        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                                Constructor.                                */
    /* -------------------------------------------------------------------------- */

    function init(address owner) public {
        _initializeOwner(owner);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Credit.                                  */
    /* -------------------------------------------------------------------------- */

    function activate(
        address user,
        uint256 limit
    ) public onlyOwnerOrRoles(EXTENSIONS) {
        credits[user] = Credit({limit: limit, amount: limit});
    }

    function adjust(
        address user,
        uint256 newLimit
    ) public onlyOwnerOrRoles(EXTENSIONS) {
        Credit storage c = credits[user];

        unchecked {
            if (newLimit > c.limit) {
                c.amount += newLimit - c.limit;
                c.limit = newLimit;
            } else {
                uint256 gap = c.limit - newLimit;
                (gap > c.amount) ? c.amount = 0 : c.amount -= gap;
                c.limit = newLimit;
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Assets.                                  */
    /* -------------------------------------------------------------------------- */

    // TODO: deprecate AGENTS check for `requestBySig` function
    function request(uint256 id, Request calldata _r) external {
        if (id != 0) {
            Request storage r = requests[id];
            if (
                r.from == address(0) &&
                r.from != msg.sender &&
                rolesOf(msg.sender) != AGENTS
            ) revert Unauthorized();
            (bytes(_r.title).length > 0) ? r.title = _r.title : r.title;
            (bytes(_r.detail).length > 0) ? r.detail = _r.detail : r.detail;
        } else {
            if (_r.from != msg.sender && rolesOf(msg.sender) != AGENTS)
                revert Unauthorized();
            _deposit(_r.from, address(this), _r.currency, _r.drop);

            unchecked {
                requests[id = ++requestId] = _r;
            }
        }
        emit RequestUpdated(id);
    }

    // TODO: deprecate AGENTS check for `resourceBySig` function
    function resource(uint256 id, Resource calldata _r) external {
        if (id != 0) {
            Resource storage r = resources[id];
            if (
                r.from == address(0) &&
                r.from != msg.sender &&
                rolesOf(msg.sender) != AGENTS
            ) revert Unauthorized();

            (_r.from != address(0)) ? r.from = _r.from : r.from;
            (bytes(_r.title).length > 0) ? r.title = _r.title : r.title;
            (bytes(_r.detail).length > 0) ? r.detail = _r.detail : r.detail;
        } else {
            if (_r.from != msg.sender && rolesOf(msg.sender) != AGENTS)
                revert Unauthorized();
            unchecked {
                resources[id = ++resourceId] = _r;
            }
        }
        emit ResourceUpdated(id);
    }

    function trade(
        TradeType tradeType,
        uint256 subjectId,
        Trade calldata _t
    ) external isResourceAvailable(_t.resource) {
        if (_t.from != msg.sender && rolesOf(msg.sender) != AGENTS)
            revert Unauthorized();
        _deposit(_t.from, address(this), _t.currency, _t.amount);

        uint256 id = getTradeIdByUser(tradeType, subjectId, _t.from);

        Trade storage t;
        unchecked {
            if (id != 0) {
                t = (tradeType == TradeType.RESPONSE)
                    ? responsesPerRequest[subjectId][id]
                    : exchangesPerResource[subjectId][id];
                if (t.approved) revert Approved();

                // Update trade.
                (_t.resource > 0) ? t.resource = _t.resource : t.resource;
                if (t.currency == address(0) && t.amount != 0) {
                    Credit storage c = credits[t.from];
                    c.amount += t.amount;
                }
                if (t.currency != address(0) && t.amount != 0)
                    route(t.currency, address(this), t.from, t.amount);
                (bytes(_t.content).length > 0)
                    ? t.content = _t.content
                    : t.content;
                (bytes(_t.data).length > 0) ? t.data = _t.data : t.data;
            } else {
                // Store trade.
                t = (tradeType == TradeType.RESPONSE)
                    ? responsesPerRequest[subjectId][
                        ++responseIdsPerRequest[subjectId]
                    ]
                    : exchangesPerResource[subjectId][
                        ++exchangeIdsPerResource[subjectId]
                    ];
                t.approved = false;
                t.from = _t.from;
                t.resource = _t.resource;
                t.currency = _t.currency;
                t.amount = _t.amount;
                t.content = _t.content;
                t.data = _t.data;
            }
        }

        emit TradeUpdated(tradeType, subjectId, id);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Manage Assets.                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Request

    function withdrawRequest(uint256 id) external {
        Request storage r = requests[id];
        if (r.from != msg.sender) revert NotOriginalPoster();

        (r.currency != address(0))
            ? route(r.currency, address(this), msg.sender, r.drop)
            : build(msg.sender, r.drop);
        delete requests[id];
        emit RequestUpdated(id);
    }

    /// @notice Resource

    function withdrawResource(uint256 id) external {
        Resource storage r = resources[id];
        if (r.from != msg.sender) revert NotOriginalPoster();

        delete resources[id];
        emit ResourceUpdated(id);
    }

    /// @notice Trade

    function withdrawTrade(
        TradeType tradeType,
        uint256 subjectId,
        uint256 tradeId
    ) external {
        Trade storage t;
        (tradeType == TradeType.RESPONSE)
            ? t = responsesPerRequest[subjectId][tradeId]
            : t = exchangesPerResource[subjectId][tradeId];
        if (t.approved) revert Approved();
        if (t.from != msg.sender) revert NotOriginalPoster();

        // Refund payment.
        (t.currency != address(0))
            ? route(t.currency, address(this), msg.sender, t.amount)
            : build(msg.sender, t.amount);

        // Remove trade.
        (tradeType == TradeType.RESPONSE)
            ? delete responsesPerRequest[subjectId][tradeId]
            : delete exchangesPerResource[subjectId][tradeId];
        emit TradeUpdated(tradeType, subjectId, tradeId);
    }

    function approveResponse(
        uint256 subjectId,
        uint256 tradeId,
        uint256 amount
    ) external {
        Request storage r = requests[subjectId];
        if (r.from != msg.sender) revert NotOriginalPoster();

        Trade storage t = responsesPerRequest[subjectId][tradeId];
        if (t.from == address(0)) revert InvalidTrade();
        if (!t.approved) {
            // Aprove trade.
            t.approved = true;

            // Confirm amount is sufficient.
            if (amount != 0) r.drop -= amount;

            // Distribute payment.
            (r.currency != address(0))
                ? route(r.currency, address(this), t.from, amount)
                : build(t.from, amount);

            emit TradeUpdated(TradeType.RESPONSE, subjectId, tradeId);
        } else revert Approved();
    }

    function approveExchange(uint256 subjectId, uint256 tradeId) external {
        Resource storage r = resources[subjectId];
        if (r.from != msg.sender) revert NotOriginalPoster();

        Trade storage t = exchangesPerResource[subjectId][tradeId];
        if (t.from == address(0)) revert InvalidTrade();
        if (!t.approved) {
            // Aprove trade.
            t.approved = true;

            // Accept payment.
            (t.currency != address(0))
                ? route(t.currency, address(this), r.from, t.amount)
                : build(r.from, t.amount);

            emit TradeUpdated(TradeType.EXCHANGE, subjectId, tradeId);
        } else revert Approved();
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal.                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev Helper function to route currency.
    function route(
        address currency,
        address from,
        address to,
        uint256 amount
    ) internal {
        (from == address(this))
            ? SafeTransferLib.safeTransfer(currency, to, amount)
            : SafeTransferLib.safeTransferFrom(currency, from, to, amount);
    }

    /// @dev Helper function to build credit for user.
    function build(address user, uint256 amount) internal {
        unchecked {
            if (amount != 0) credits[user].amount += amount;
        }
    }

    function deposit(
        address from,
        address to,
        address currency,
        uint256 amount
    ) external onlyRoles(EXTENSIONS) {
        _deposit(from, to, currency, amount);
    }

    function _deposit(
        address from,
        address to,
        address currency,
        uint256 amount
    ) internal {
        if (currency == address(0) && amount != 0) {
            // Only activated address can deposit
            Credit storage c = credits[from];
            if (c.limit != 0) c.amount -= amount;
            else revert NotYetActivated();
        }

        if (currency != address(0) && amount != 0)
            route(currency, from, to, amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Helpers.                                  */
    /* -------------------------------------------------------------------------- */

    // Encode bulletin address and ask/resource id as asset.
    function encodeAsset(
        address bulletin,
        uint96 id
    ) public pure returns (bytes32) {
        return bytes32(abi.encodePacked(bulletin, id));
    }

    // Decode asset as bulletin address and ask/resource id.
    function decodeAsset(
        bytes32 asset
    ) public pure returns (address bulletin, uint96 id) {
        assembly {
            id := asset
            bulletin := shr(96, asset)
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Public Get.                                */
    /* -------------------------------------------------------------------------- */

    function getRequest(uint256 id) external view returns (Request memory) {
        return requests[id];
    }

    function getResource(uint256 id) external view returns (Resource memory) {
        return resources[id];
    }

    function getTrade(
        TradeType tradeType,
        uint256 subjectId,
        uint256 tradeId
    ) external view returns (Trade memory) {
        return
            (tradeType == TradeType.RESPONSE)
                ? responsesPerRequest[subjectId][tradeId]
                : exchangesPerResource[subjectId][tradeId];
    }

    function getTradeIdByUser(
        TradeType tradeType,
        uint256 subjectId,
        address user
    ) public view returns (uint256 tradeId) {
        Trade storage t;
        uint256 length = (tradeType == TradeType.RESPONSE)
            ? responseIdsPerRequest[subjectId]
            : exchangeIdsPerResource[subjectId];
        for (uint256 i = 1; i <= length; ++i) {
            (tradeType == TradeType.RESPONSE)
                ? t = responsesPerRequest[subjectId][i]
                : t = exchangesPerResource[subjectId][i];
            if (t.from == user) tradeId = i;
        }
    }

    function getCredit(address user) external view returns (Credit memory) {
        return credits[user];
    }
}
