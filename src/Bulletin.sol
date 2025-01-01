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

    modifier isResourceAvailable(bytes32 source) {
        if (source != 0) {
            (address _b, uint256 _r) = decodeAsset(source);
            Resource memory r = IBulletin(_b).getResource(_r);
            if (r.from != msg.sender) revert NotOriginalPoster();
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
    ) external payable deposit(r.from, address(this), r.currency, r.drop) {
        if (r.from != msg.sender) revert Unauthorized();

        unchecked {
            _setRequest(++requestId, r);
        }
    }

    function requestByAgent(
        Request calldata r
    ) external payable onlyRoles(AGENT_ROLE) {
        // Transfer currency drop.
        route(r.currency, r.from, address(this), r.drop);

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
        if (r.from != msg.sender) revert Unauthorized();
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
        if (r.from != msg.sender) revert NotOriginalPoster();

        route(r.currency, address(this), r.from, r.drop);
        delete requests[_requestId];
        emit RequestUpdated(_requestId);
    }

    /// @notice Resource

    function withdrawResource(uint256 _resourceId) external {
        Resource memory _r = resources[_resourceId];
        if (_r.from != msg.sender) revert NotOriginalPoster();

        delete resources[_resourceId];
        emit ResourceUpdated(_resourceId);
    }

    /// @notice Trade

    function approveResponse(
        uint256 _requestId,
        uint256 responseId,
        uint256 amount
    ) external {
        Request memory r = requests[_requestId];
        if (r.from != msg.sender) revert NotOriginalPoster();

        if (!responsesPerRequest[_requestId][responseId].approved) {
            // Aprove trade.
            responsesPerRequest[_requestId][responseId].approved = true;

            // todo: check if request has enough currency to drop `amount`
            if (amount > 0) {
                if (amount > r.drop) revert InsufficientAmount();
                requests[_requestId].drop = r.drop - amount;

                route(
                    r.currency,
                    address(this),
                    responsesPerRequest[_requestId][responseId].from,
                    amount
                );
            }

            emit ResponseUpdated(_requestId, responseId, msg.sender);
        } else revert Approved();
    }

    function withdrawResponse(
        uint256 _requestId,
        uint256 _responseId
    ) external {
        Trade memory t = responsesPerRequest[_requestId][_responseId];
        if (t.approved) revert Approved();
        if (t.from != msg.sender) revert NotOriginalPoster();

        route(t.currency, address(this), t.from, t.amount);
        delete responsesPerRequest[_requestId][_responseId];
        emit RequestUpdated(_requestId);
    }

    function approveExchange(uint256 _resourceId, uint256 exchangeId) external {
        Resource memory r = resources[_resourceId];
        if (r.from != msg.sender) revert NotOriginalPoster();

        Trade memory t = exchangesPerResource[_resourceId][exchangeId];
        if (!t.approved) {
            // Aprove trade.
            exchangesPerResource[_resourceId][exchangeId].approved = true;

            // Accept payment.
            if (t.amount != 0)
                route(t.currency, address(this), r.from, t.amount);

            emit ExchangeUpdated(_resourceId, exchangeId, msg.sender);
        } else revert Approved();
    }

    function withdrawExchange(
        uint256 _resourceId,
        uint256 _exchangeId
    ) external {
        Trade memory t = exchangesPerResource[_resourceId][_exchangeId];
        if (t.approved) revert Approved();
        if (t.from != msg.sender) revert NotOriginalPoster();

        route(t.currency, address(this), t.from, t.amount);
        delete exchangesPerResource[_resourceId][_exchangeId];
        emit RequestUpdated(_resourceId);
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

    function getResponse(
        uint256 _requestId,
        uint256 _responseId
    ) external view returns (Trade memory) {
        return responsesPerRequest[_requestId][_responseId];
    }

    function getExchange(
        uint256 _resourceId,
        uint256 _exchangeId
    ) external view returns (Trade memory) {
        return exchangesPerResource[_resourceId][_exchangeId];
    }

    function getResponseByUser(
        uint256 _requestId,
        address user
    ) public view returns (uint256 responseId, Trade memory t) {
        uint256 length = responseIdsPerRequest[_requestId];
        for (uint256 i = 1; i <= length; ++i) {
            if (responsesPerRequest[_requestId][i].from == user) {
                t = responsesPerRequest[_requestId][i];
                responseId = i;
            }
        }
    }

    function getExchangeByUser(
        uint256 _resourceId,
        address user
    ) public view returns (uint256 exchangeId, Trade memory t) {
        uint256 length = exchangeIdsPerResource[_resourceId];
        for (uint256 i = 1; i <= length; ++i) {
            if (exchangesPerResource[_resourceId][i].from == user) {
                t = exchangesPerResource[_resourceId][i];
                exchangeId = i;
            }
        }
    }

    receive() external payable virtual {}
}
