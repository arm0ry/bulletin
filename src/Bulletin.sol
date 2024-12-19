// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";

/// @title Bulletin
/// @notice A system to store and interact with requests and resources.
/// @author audsssy.eth
contract Bulletin is OwnableRoles, IBulletin {
    /* -------------------------------------------------------------------------- */
    /*                                 Constants.                                 */
    /* -------------------------------------------------------------------------- */

    /// The denominator for calculating distribution.
    uint16 public constant TEN_THOUSAND = 10_000;

    /// The permissioned role to call `incrementUsage()`.
    uint40 internal constant BULLETIN_ROLE = 1 << 0;

    /// The permissioned role reserved for autonomous agents.
    uint40 internal constant AGENT_ROLE = 1 << 1;

    /* -------------------------------------------------------------------------- */
    /*                                  Storage.                                  */
    /* -------------------------------------------------------------------------- */

    uint40 public requestId;
    uint40 public resourceId;

    // Mappings by `requestId`.
    mapping(uint256 => Request) public requests;
    mapping(uint256 => uint256) public responseIdsPerRequest;
    mapping(uint256 => mapping(uint256 => Trade)) public responsesPerRequest; // Reciprocal events.

    // Mappings by `resourceId`.
    mapping(uint256 => Resource) public resources;
    mapping(uint256 => uint256) public exchangeIdsPerResource;
    mapping(uint256 => mapping(uint256 => Trade)) public exchangesPerResource; // Reciprocal events.

    /* -------------------------------------------------------------------------- */
    /*                                 Modifiers.                                 */
    /* -------------------------------------------------------------------------- */

    modifier checkSum(uint16[] calldata p) {
        // Add up all percentages.
        uint256 totalPercentage;
        for (uint256 i; i < p.length; ++i) {
            totalPercentage += p[i];
        }

        // Throw when total percentage does not equal to TEN_THOUSAND.
        if (totalPercentage != TEN_THOUSAND)
            revert TotalPercentageMustBeTenThousand();

        _;
    }

    modifier isResourceAvailable(bytes32 source) {
        if (source != 0) {
            (address _b, uint256 _r) = decodeAsset(source);
            Resource memory r = IBulletin(_b).getResource(_r);
            if (r.owner != msg.sender) revert InvalidOriginalPoster();
            if (!r.active) revert ResourceNotActive();
        }

        _;
    }

    modifier deposit(
        address from,
        address to,
        address currency,
        uint256 amount
    ) {
        if (amount != 0) route(currency, from, to, amount);
        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                                Constructor.                                */
    /* -------------------------------------------------------------------------- */

    function init(address owner) public {
        _initializeOwner(owner);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Assets.                                  */
    /* -------------------------------------------------------------------------- */

    function request(
        Request calldata r
    ) external payable deposit(r.owner, address(this), r.currency, r.drop) {
        if (r.owner != msg.sender) revert Unauthorized();

        unchecked {
            _setRequest(++requestId, r);
        }
    }

    function askByAgent(
        Request calldata r
    ) external payable onlyRoles(AGENT_ROLE) {
        // Transfer currency drop.
        route(r.currency, r.owner, address(this), r.drop);

        unchecked {
            _setRequest(++requestId, r);
        }
    }

    function respond(
        uint256 _requestId,
        uint256 responseId,
        Trade calldata t
    )
        external
        payable
        isResourceAvailable(t.resource)
        deposit(t.from, address(this), t.currency, t.amount)
    {
        // Check if `Request` is fulfilled.
        if (requests[_requestId].fulfilled) revert AlreadyFulfilled();

        if (responseId > 0) {
            Trade memory _t = responsesPerRequest[_requestId][responseId];
            if (_t.from != msg.sender) revert Unauthorized();
            if (_t.approved) revert Approved();
            if (_t.amount != 0)
                route(_t.currency, address(this), _t.from, _t.amount);
        } else {
            // Create new `responseId`.
            unchecked {
                responseId = ++responseIdsPerRequest[_requestId];
            }
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

        emit ResponseUpdated(_requestId, responseId, t.from);
    }

    function resource(Resource calldata r) external {
        if (r.owner != msg.sender) revert Unauthorized();
        unchecked {
            _setResource(++resourceId, r);
        }
    }

    function resourceByAgent(
        Resource calldata r
    ) external onlyRoles(AGENT_ROLE) {
        unchecked {
            _setResource(++resourceId, r);
        }
    }

    /// target `resourceId`
    /// proposed `Trade`
    function exchange(
        uint256 _resourceId,
        uint256 exchangeId,
        Trade calldata t
    )
        external
        payable
        isResourceAvailable(t.resource)
        deposit(t.from, address(this), t.currency, t.amount)
    {
        if (exchangeId > 0) {
            Trade memory _t = exchangesPerResource[_resourceId][exchangeId];
            if (_t.from != msg.sender) revert Unauthorized();
            if (_t.approved) revert Approved();
            if (_t.amount != 0)
                route(_t.currency, address(this), _t.from, _t.amount);
        } else {
            // Create new `exchangeId`.
            unchecked {
                exchangeId = ++exchangeIdsPerResource[_resourceId];
            }
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

        emit ExchangeUpdated(_resourceId, exchangeId, t.from);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Manage Assets.                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Request

    function withdrawRequest(uint256 _requestId) external {
        Request memory r = requests[_requestId];
        if (r.owner != msg.sender) revert InvalidOriginalPoster();
        if (r.fulfilled) revert AlreadyFulfilled();

        route(r.currency, address(this), r.owner, r.drop);
        delete requests[_requestId];

        emit RequestUpdated(_requestId);
    }

    function settleRequest(
        uint40 _requestId,
        bool approved,
        uint40 role,
        uint16[] calldata percentages
    ) public checkSum(percentages) {
        _settleRequest(_requestId, approved, role, percentages);
    }

    /// @notice Resource

    function withdrawResource(uint256 _resourceId) external {
        Resource memory _r = resources[_resourceId];
        if (_r.owner != msg.sender) revert InvalidOriginalPoster();

        delete resources[_resourceId];

        emit ResourceUpdated(_resourceId);
    }

    /// @notice Trade

    function approveResponse(uint256 _requestId, uint256 responseId) external {
        Request memory r = requests[_requestId];

        // Check original poster.
        if (r.owner != msg.sender) revert InvalidOriginalPoster();

        // Check if `Request` is already fulfilled.
        if (r.fulfilled) revert AlreadyFulfilled();

        // Aprove trade.
        responsesPerRequest[_requestId][responseId].approved = true;

        emit ResponseUpdated(_requestId, responseId, msg.sender);
    }

    function approveExchange(uint256 _resourceId, uint256 exchangeId) external {
        // Check original poster.
        Resource memory r = resources[_resourceId];
        if (r.owner != msg.sender) revert InvalidOriginalPoster();

        Trade memory t = exchangesPerResource[_resourceId][exchangeId];
        if (!t.approved) {
            // Aprove trade.
            exchangesPerResource[_resourceId][exchangeId].approved = true;

            // Accept payment.
            if (t.amount != 0)
                route(t.currency, address(this), r.owner, t.amount);
        }

        emit ExchangeUpdated(_resourceId, exchangeId, msg.sender);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal.                                 */
    /* -------------------------------------------------------------------------- */

    function _setRequest(uint256 _requestId, Request calldata a) internal {
        // Store ask.
        requests[_requestId] = Request({
            fulfilled: false,
            owner: a.owner,
            title: a.title,
            detail: a.detail,
            currency: a.currency,
            drop: a.drop
        });

        emit RequestUpdated(requestId);
    }

    function _setResource(uint256 _resourceId, Resource calldata r) internal {
        resources[_resourceId] = Resource({
            active: r.active,
            owner: r.owner,
            title: r.title,
            detail: r.detail
        });

        emit ResourceUpdated(resourceId);
    }

    function _settleRequest(
        uint40 _requestId,
        bool approved,
        uint40 role,
        uint16[] calldata percentages
    ) internal {
        // Throw when owners mismatch.
        Request memory r = requests[_requestId];
        if (r.owner != msg.sender) revert InvalidOriginalPoster();

        // Tally and retrieve approved trades.
        Trade[] memory _trades = filterTrades(_requestId, approved, role);

        // Throw when number of percentages does not match number of approved trades.
        if (_trades.length != percentages.length) revert SettlementMismatch();

        for (uint256 i; i < _trades.length; ++i) {
            // Pay resource owner.
            route(
                r.currency,
                address(this),
                _trades[i].from,
                (r.drop * percentages[i]) / TEN_THOUSAND
            );
        }

        // Mark `Request` as fulfilled.
        requests[_requestId].fulfilled = true;

        emit RequestSettled(_requestId, _trades.length);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Helpers.                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Helper function to route Ether and ERC20 tokens.
    function route(
        address currency,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (currency == address(0)) {
            if (from == address(this))
                SafeTransferLib.safeTransferETH(to, amount);
            else if (msg.value != amount) revert InsufficientAmount();
        } else {
            (from == address(this))
                ? SafeTransferLib.safeTransfer(currency, to, amount)
                : SafeTransferLib.safeTransferFrom(currency, from, to, amount);
        }
    }

    function filterTrades(
        uint256 id,
        bool approved,
        uint40 role
    ) public view returns (Trade[] memory _trades) {
        // Declare for use.
        Trade memory t;

        // Retrieve trade id, or number of trades.
        uint256 tId = responseIdsPerRequest[id];

        // If trades exist, filter and return trades based on provided `key`.
        if (tId > 0) {
            _trades = new Trade[](tId);
            for (uint256 i = 1; i <= tId; ++i) {
                // Retrieve trade.
                t = responsesPerRequest[id][i];

                (approved == t.approved && hasAnyRole(t.from, role))
                    ? _trades[i - 1] = t
                    : t;
            }
        }
    }

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

    function getRequest(uint256 id) external view returns (Request memory r) {
        return requests[id];
    }

    function getResource(uint256 id) external view returns (Resource memory r) {
        return resources[id];
    }

    function getTrade(
        uint256 id,
        uint256 tradeId
    ) external view returns (Trade memory) {
        return responsesPerRequest[id][tradeId];
    }

    function getResponseByUser(
        uint256 _requestId,
        address user
    ) public view returns (uint256 tradeId, Trade memory t) {
        uint256 length = responseIdsPerRequest[_requestId];
        for (uint256 i = 1; i <= length; ++i) {
            (responsesPerRequest[_requestId][i].from == user)
                ? t = responsesPerRequest[_requestId][i]
                : t;
            tradeId = i;
        }
    }

    function getExchangeByUser(
        uint256 _resourceId,
        address user
    ) public view returns (uint256 tradeId, Trade memory t) {
        uint256 length = exchangeIdsPerResource[_resourceId];
        for (uint256 i = 1; i <= length; ++i) {
            (exchangesPerResource[_resourceId][i].from == user)
                ? t = exchangesPerResource[_resourceId][i]
                : t;
            tradeId = i;
        }
    }

    receive() external payable virtual {}
}
