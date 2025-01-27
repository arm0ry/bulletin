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
            Resource memory r = getResource(_r);
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

    function credit(
        address user,
        uint256 newLimit
    ) public onlyOwnerOrRoles(EXTENSIONS) {
        Credit storage c = credits[user];
        c.limit = newLimit;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Assets.                                  */
    /* -------------------------------------------------------------------------- */

    function request(Request calldata r) external {
        deposit(r.from, address(this), r.currency, r.drop);
        unchecked {
            _setRequest(++requestId, r);
        }
    }

    function requestByAgent(Request calldata r) external onlyRoles(AGENTS) {
        // Transfer currency drop.
        route(r.currency, r.from, address(this), r.drop);

        unchecked {
            _setRequest(++requestId, r);
        }
    }

    function respond(
        uint256 _requestId,
        Trade calldata t
    ) external isResourceAvailable(t.resource) {
        deposit(msg.sender, address(this), t.currency, t.amount);

        (uint256 responseId, Trade memory _t) = getTradeByUser(
            true,
            _requestId,
            msg.sender
        );
        if (responseId == 0) {
            unchecked {
                responseId = ++responseIdsPerRequest[_requestId];
            }
        } else {
            if (_t.approved) revert Approved();
            if (_t.amount != 0)
                route(_t.currency, address(this), _t.from, _t.amount);
        }

        // Store trade.
        responsesPerRequest[_requestId][responseId] = Trade({
            approved: false,
            from: msg.sender,
            resource: t.resource,
            currency: t.currency,
            amount: t.amount,
            content: t.content,
            data: t.data
        });

        emit TradeUpdated(true, _requestId, responseId);
    }

    function resource(Resource calldata r) external {
        if (r.from != msg.sender) revert Unauthorized();
        unchecked {
            _setResource(++resourceId, r);
        }
    }

    function resourceByAgent(Resource calldata r) external onlyRoles(AGENTS) {
        unchecked {
            _setResource(++resourceId, r);
        }
    }

    /// target `resourceId`
    /// proposed `Trade`
    function exchange(
        uint256 _resourceId,
        Trade calldata t
    ) external isResourceAvailable(t.resource) {
        deposit(msg.sender, address(this), t.currency, t.amount);

        (uint256 exchangeId, Trade memory _t) = getTradeByUser(
            false,
            _resourceId,
            msg.sender
        );

        if (exchangeId == 0) {
            unchecked {
                exchangeId = ++exchangeIdsPerResource[_resourceId];
            }
        } else {
            if (_t.approved) revert Approved();
            if (_t.amount != 0)
                route(_t.currency, address(this), _t.from, _t.amount);
        }

        // Store trade.
        exchangesPerResource[_resourceId][exchangeId] = Trade({
            approved: false,
            from: msg.sender,
            resource: t.resource,
            currency: t.currency,
            amount: t.amount,
            content: t.content,
            data: t.data
        });

        emit TradeUpdated(false, _resourceId, exchangeId);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Manage Assets.                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Request

    function withdrawRequest(uint256 _requestId) external {
        Request storage r = requests[_requestId];
        if (r.from != msg.sender) revert NotOriginalPoster();

        route(r.currency, address(this), r.from, r.drop);
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
        if (!t.approved) {
            // Aprove trade.
            t.approved = true;

            // Confirm amount is sufficient.
            if (amount != 0) {
                r.drop -= amount;
            }

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
        if (!t.approved) {
            // Aprove trade.
            t.approved = true;

            // Accept payment.
            (t.currency != address(0))
                ? route(t.currency, address(this), r.from, t.amount)
                : build(r.from, t.amount);

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

        (t.currency != address(0))
            ? route(t.currency, address(this), t.from, t.amount)
            : build(t.from, t.amount);

        (isResponse)
            ? delete responsesPerRequest[subjectId][tradeId]
            : delete exchangesPerResource[subjectId][tradeId];
        emit TradeUpdated(isResponse, subjectId, tradeId);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal.                                 */
    /* -------------------------------------------------------------------------- */

    function _setRequest(uint256 _requestId, Request calldata r) internal {
        requests[_requestId] = Request({
            from: r.from,
            title: r.title,
            detail: r.detail,
            currency: r.currency,
            drop: r.drop
        });

        emit RequestUpdated(requestId);
    }

    function _setResource(uint256 _resourceId, Resource calldata r) internal {
        resources[_resourceId] = Resource({
            from: r.from,
            title: r.title,
            detail: r.detail
        });

        emit ResourceUpdated(resourceId);
    }

    /// @dev Helper function to route currency.
    function route(
        address currency,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (currency != address(0)) {
            (from == address(this))
                ? SafeTransferLib.safeTransfer(currency, to, amount)
                : SafeTransferLib.safeTransferFrom(currency, from, to, amount);
        } else return;
    }

    /// @dev Helper function to build credit for user.
    function build(address user, uint256 amount) internal {
        Credit storage c = credits[user];
        uint256 gap = c.limit - c.amount;
        if (c.limit > 0) {
            if (gap > amount) {
                // Build credit.
                c.amount += amount;
            } else {
                // Build credit and route excess.
                c.amount += gap;
            }
        } else c.amount += amount;
    }

    function deposit(
        address from,
        address to,
        address currency,
        uint256 amount
    ) internal {
        if (from != msg.sender) revert Unauthorized();
        Credit storage c = credits[from];
        if (currency == address(0) && c.limit > 0) c.amount -= amount;
        else route(currency, from, to, amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Helpers.                                  */
    /* -------------------------------------------------------------------------- */

    // Encode bulletin address and ask/resource id as asset.
    function encodeAsset(
        address bulletin,
        uint96 id
    ) public pure returns (bytes32 asset) {
        asset = bytes32(abi.encodePacked(bulletin, id));
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

    function getRequest(uint256 id) public view returns (Request memory r) {
        return requests[id];
    }

    function getResource(uint256 id) public view returns (Resource memory r) {
        return resources[id];
    }

    function getTrade(
        bool isResponse,
        uint256 subjectId,
        uint256 tradeId
    ) public view returns (Trade memory) {
        return
            (isResponse)
                ? responsesPerRequest[subjectId][tradeId]
                : exchangesPerResource[subjectId][tradeId];
    }

    function getTradeByUser(
        bool isResponse,
        uint256 subjectId,
        address user
    ) public view returns (uint256 tradeId, Trade memory t) {
        uint256 length = (isResponse)
            ? responseIdsPerRequest[subjectId]
            : exchangeIdsPerResource[subjectId];
        for (uint256 i = 1; i <= length; ++i) {
            if (isResponse) {
                if (responsesPerRequest[subjectId][i].from == user) {
                    t = responsesPerRequest[subjectId][i];
                    tradeId = i;
                }
            } else {
                if (exchangesPerResource[subjectId][i].from == user) {
                    t = exchangesPerResource[subjectId][i];
                    tradeId = i;
                }
            }
        }
    }

    function getCredit(address user) external view returns (Credit memory c) {
        c = credits[user];
    }
}
