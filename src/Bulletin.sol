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
    ) public onlyOwnerOrRoles(AGENTS) {
        credits[user] = Credit({limit: limit, amount: limit});
    }

    function adjust(
        address user,
        uint256 newLimit
    ) public onlyOwnerOrRoles(EXTENSIONS) {
        Credit storage c = credits[user];

        unchecked {
            if (newLimit > c.limit) {
                // TODO: test this logic
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

    function request(uint256 id, Request calldata r) external {
        _deposit(r.from, address(this), r.currency, r.drop);
        unchecked {
            _setRequest(id, r);
        }
    }

    function requestByAgent(Request calldata r) external onlyRoles(AGENTS) {
        _deposit(r.from, address(this), r.currency, r.drop);

        unchecked {
            _setRequest(0, r);
        }
    }

    function respond(
        uint256 _requestId,
        Trade calldata _t
    ) external isResourceAvailable(_t.resource) {
        _deposit(msg.sender, address(this), _t.currency, _t.amount);

        uint256 responseId = getTradeIdByUser(true, _requestId, msg.sender);

        Trade storage t;
        if (responseId == 0) {
            unchecked {
                responseId = ++responseIdsPerRequest[_requestId];
            }

            t = responsesPerRequest[_requestId][responseId];

            // Store trade.
            t.from = msg.sender;
            (_t.resource > 0) ? t.resource = _t.resource : t.resource;
            (_t.currency != address(0)) ? t.currency = _t.currency : t.currency;
            (_t.amount > 0) ? t.amount = _t.amount : t.amount;
            (bytes(_t.content).length > 0) ? t.content = _t.content : t.content;
            (bytes(_t.data).length > 0) ? t.data = _t.data : t.data;
        } else {
            t = responsesPerRequest[_requestId][responseId];
            if (t.approved) revert Approved();

            // Update payment if different. Other data stay intact.
            if (t.currency == address(0) && t.amount != 0)
                t.amount += _t.amount;
            if (t.amount != 0)
                route(t.currency, address(this), t.from, t.amount);
        }

        emit TradeUpdated(true, _requestId, responseId);
    }

    function resource(uint256 id, Resource calldata r) external {
        _setResource(id, r);
    }

    function resourceByAgent(Resource calldata r) external onlyRoles(AGENTS) {
        unchecked {
            _setResource(0, r);
        }
    }

    /// target `resourceId`
    /// proposed `Trade`
    function exchange(
        uint256 _resourceId,
        Trade calldata _t
    ) external isResourceAvailable(_t.resource) {
        _deposit(msg.sender, address(this), _t.currency, _t.amount);

        uint256 exchangeId = getTradeIdByUser(false, _resourceId, msg.sender);

        Trade storage t;
        if (exchangeId == 0) {
            unchecked {
                exchangeId = ++exchangeIdsPerResource[_resourceId];
            }

            t = exchangesPerResource[_resourceId][exchangeId];

            // Store trade.
            t.from = msg.sender;
            (_t.resource > 0) ? t.resource = _t.resource : t.resource;
            (_t.currency != address(0)) ? t.currency = _t.currency : t.currency;
            (_t.amount > 0) ? t.amount = _t.amount : t.amount;
            (bytes(_t.content).length > 0) ? t.content = _t.content : t.content;
            (bytes(_t.data).length > 0) ? t.data = _t.data : t.data;
        } else {
            t = exchangesPerResource[_resourceId][exchangeId];
            if (t.approved) revert Approved();

            // Update payment if different. Other data stay intact.
            if (t.currency == address(0) && t.amount != 0)
                t.amount += _t.amount;
            if (t.currency != address(0) && t.amount != 0)
                route(t.currency, address(this), t.from, t.amount);
        }

        emit TradeUpdated(false, _resourceId, exchangeId);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Manage Assets.                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Request

    function withdrawRequest(uint256 _requestId) external {
        Request storage r = requests[_requestId];
        if (r.from != msg.sender) revert NotOriginalPoster();

        (r.currency != address(0))
            ? route(r.currency, address(this), msg.sender, r.drop)
            : build(msg.sender, r.drop);
        delete requests[_requestId];
        emit RequestUpdated(_requestId);
    }

    /// @notice Resource

    function withdrawResource(uint256 _resourceId) external {
        Resource storage r = resources[_resourceId];
        if (r.from != msg.sender) revert NotOriginalPoster();

        delete resources[_resourceId];
        emit ResourceUpdated(_resourceId);
    }

    /// @notice Trade

    function approveResponse(
        uint256 _requestId,
        uint256 responseId,
        uint256 amount
    ) external {
        Request storage r = requests[_requestId];
        if (r.from != msg.sender) revert NotOriginalPoster();

        Trade storage t = responsesPerRequest[_requestId][responseId];
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

            emit TradeUpdated(true, _requestId, responseId);
        } else revert Approved();
    }

    function approveExchange(uint256 _resourceId, uint256 exchangeId) external {
        Resource storage r = resources[_resourceId];
        if (r.from != msg.sender) revert NotOriginalPoster();

        Trade storage t = exchangesPerResource[_resourceId][exchangeId];
        if (t.from == address(0)) revert InvalidTrade();
        if (!t.approved) {
            // Aprove trade.
            t.approved = true;

            // Accept payment.
            (t.currency != address(0))
                ? route(t.currency, address(this), r.beneficiary, t.amount)
                : build(r.beneficiary, t.amount);

            emit TradeUpdated(false, _resourceId, exchangeId);
        } else revert Approved();
    }

    function withdrawTrade(
        bool isResponse,
        uint256 subjectId,
        uint256 tradeId
    ) external {
        Trade storage t;
        (isResponse)
            ? t = responsesPerRequest[subjectId][tradeId]
            : t = exchangesPerResource[subjectId][tradeId];
        if (t.approved) revert Approved();
        if (t.from != msg.sender) revert NotOriginalPoster();

        // Refund payment.
        (t.currency != address(0))
            ? route(t.currency, address(this), msg.sender, t.amount)
            : build(msg.sender, t.amount);

        // Remove trade.
        (isResponse)
            ? delete responsesPerRequest[subjectId][tradeId]
            : delete exchangesPerResource[subjectId][tradeId];
        emit TradeUpdated(isResponse, subjectId, tradeId);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal.                                 */
    /* -------------------------------------------------------------------------- */

    function _setRequest(uint256 id, Request calldata _r) internal {
        if (id != 0) {
            Request storage r = requests[id];
            if (r.from != msg.sender) revert Unauthorized();
            (bytes(_r.title).length > 0) ? r.title = _r.title : r.title;
            (bytes(_r.detail).length > 0) ? r.detail = _r.detail : r.detail;
        } else {
            if (_r.from != msg.sender) revert Unauthorized();
            unchecked {
                requests[id = ++requestId] = _r;
            }
        }
        emit RequestUpdated(id);
    }

    function _setResource(uint256 id, Resource calldata _r) internal {
        if (id != 0) {
            Resource storage r = resources[id];
            if (r.from != msg.sender) revert Unauthorized();
            (_r.beneficiary != address(0))
                ? r.beneficiary = _r.beneficiary
                : r.beneficiary;
            (bytes(_r.title).length > 0) ? r.title = _r.title : r.title;
            (bytes(_r.detail).length > 0) ? r.detail = _r.detail : r.detail;
        } else {
            if (_r.from != msg.sender) revert Unauthorized();
            unchecked {
                resources[id = ++resourceId] = _r;
            }
        }
        emit ResourceUpdated(id);
    }

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
            Credit storage c = credits[from];
            c.amount -= amount;
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
        bool isResponse,
        uint256 subjectId,
        uint256 tradeId
    ) external view returns (Trade memory) {
        return
            (isResponse)
                ? responsesPerRequest[subjectId][tradeId]
                : exchangesPerResource[subjectId][tradeId];
    }

    function getTradeIdByUser(
        bool isResponse,
        uint256 subjectId,
        address user
    ) public view returns (uint256 tradeId) {
        Trade storage t;
        uint256 length = (isResponse)
            ? responseIdsPerRequest[subjectId]
            : exchangeIdsPerResource[subjectId];
        for (uint256 i = 1; i <= length; ++i) {
            (isResponse)
                ? t = responsesPerRequest[subjectId][i]
                : t = exchangesPerResource[subjectId][i];
            if (t.from == user) tradeId = i;
        }
    }

    function getCredit(address user) external view returns (Credit memory) {
        return credits[user];
    }
}
