// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";

/// @title Bulletin
/// @notice A system to store and interact with asks and resources.
/// @author audsssy.eth
contract Bulletin is OwnableRoles, IBulletin {
    /* -------------------------------------------------------------------------- */
    /*                                 Constants.                                 */
    /* -------------------------------------------------------------------------- */

    /// The denominator for calculating distribution.
    uint16 public constant TEN_THOUSAND = 10_000;

    /// The permissioned role to call `incrementUsage()`.
    uint40 public constant BULLETIN_ROLE = 1 << 1;

    /// The permissioned role reserved for trade agents.
    uint40 public constant AGENT_ROLE = 1 << 2;

    /* -------------------------------------------------------------------------- */
    /*                                  Storage.                                  */
    /* -------------------------------------------------------------------------- */

    uint40 public askId;
    uint40 public resourceId;

    // Mappings by `askId`.
    mapping(uint256 => Ask) public asks;
    mapping(uint256 => uint256) public tradeIds;
    mapping(uint256 => mapping(bytes32 => bool)) public doesTradeExist;
    mapping(uint256 => mapping(uint256 => Trade)) public trades; // Reciprocal events.

    // Mappings by `resourceId`.
    mapping(uint256 => Resource) public resources;
    mapping(uint256 => uint256) public usageIds;
    mapping(uint256 => mapping(uint256 => Usage)) public usages; // Reciprocal events.

    /* -------------------------------------------------------------------------- */
    /*                                 Modifiers.                                 */
    /* -------------------------------------------------------------------------- */

    function checkSum(uint16[] calldata p) public pure {
        // Add up all percentages.
        uint256 totalPercentage;
        for (uint256 i; i < p.length; ++i) {
            totalPercentage += p[i];
        }

        // Throw when total percentage does not equal to TEN_THOUSAND.
        if (totalPercentage != TEN_THOUSAND)
            revert TotalPercentageMustBeTenThousand();
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

    function ask(Ask calldata a) external payable onlyOwnerOrRoles(a.role) {
        // Transfer currency drop to address(this).
        route(a.currency, msg.sender, address(this), a.drop);

        unchecked {
            _setAsk(++askId, a);
        }
    }

    function resource(Resource calldata r) external onlyOwnerOrRoles(r.role) {
        unchecked {
            _setResource(++resourceId, r);
        }
    }

    /// target `askId`
    /// proposed `Trade`
    function trade(
        uint256 _askId,
        Trade calldata t
    ) external onlyRoles(t.role) {
        if (doesTradeExist[_askId][t.resource]) revert DuplicativeTrade();

        // Check if `Ask` is fulfilled.
        if (asks[_askId].fulfilled) revert InvalidTrade();

        // Check if `t.resource` is a `Resource`.
        // resource of `Ask` may offer feedback on `Resource` after a trade is settled.
        if (bytes32(t.resource).length > 0) {
            (address _bulletin, uint256 _resourceId) = decodeAsset(t.resource);
            Resource memory r = IBulletin(_bulletin).getResource(_resourceId);
            if (r.owner != msg.sender) revert InvalidOriginalPoster();
            if (!r.active) revert ResourceNotActive();

            unchecked {
                trades[_askId][++tradeIds[_askId]] = Trade({
                    approved: false,
                    role: t.role,
                    resource: t.resource,
                    feedback: t.feedback,
                    data: t.data
                });
            }

            emit TradeAdded(_askId, t.resource);
        } else {
            // Otherwise, `msg.sender` becomes `Resource`.
            unchecked {
                trades[_askId][++tradeIds[_askId]] = Trade({
                    approved: true,
                    role: t.role,
                    resource: bytes32(uint256(uint160(msg.sender))),
                    feedback: t.feedback,
                    data: t.data
                });
            }

            emit TradeAdded(_askId, t.resource);
        }

        doesTradeExist[_askId][t.resource] = true;
    }

    /* -------------------------------------------------------------------------- */
    /*                               Manage Assets.                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Ask

    function updateAsk(uint256 _askId, Ask calldata a) external payable {
        Ask memory _a = asks[_askId];
        if (_a.owner != msg.sender) revert InvalidOriginalPoster();
        if (_a.fulfilled) revert AlreadyFulfilled();

        if (_a.drop != a.drop) {
            route(_a.currency, address(this), _a.owner, _a.drop);

            // Transfer currency drop to address(this).
            route(a.currency, _a.owner, address(this), a.drop);
        }

        _setAsk(_askId, a);
    }

    function withdrawAsk(uint256 _askId) external {
        Ask memory a = asks[_askId];
        if (a.owner != msg.sender) revert InvalidOriginalPoster();
        if (a.fulfilled) revert AlreadyFulfilled();

        route(a.currency, address(this), a.owner, a.drop);
        delete asks[_askId].currency;
        delete asks[_askId].drop;
    }

    function settleAsk(
        uint40 _askId,
        uint40 role,
        uint16[] calldata percentages
    ) public {
        checkSum(percentages);
        _settleAsk(_askId, role, percentages);
    }

    /// @notice Resource

    function updateResource(uint256 _resourceId, Resource calldata r) external {
        Resource memory _r = resources[_resourceId];
        if (_r.owner != msg.sender) revert InvalidOriginalPoster();

        _setResource(_resourceId, r);
    }

    /// @notice Trade

    function approveTrade(uint256 _askId, uint256 tradeId) external {
        _processTrade(_askId, tradeId, true);
    }

    function rejectTrade(uint256 _askId, uint256 tradeId) external {
        _processTrade(_askId, tradeId, false);
    }

    /// @notice Reciprocity

    // Only other Bulletins can access
    function incrementUsage(
        uint256 role,
        uint256 _resourceId,
        bytes32 bulletinAsk // encodeAsset(address(bulletin), uint96(askId))
    ) public onlyRoles(role) {
        unchecked {
            usages[_resourceId][++usageIds[_resourceId]] = Usage({
                ask: bulletinAsk,
                timestamp: uint40(block.timestamp),
                feedback: "",
                data: abi.encode(0)
            });
        }
    }

    // Users benefited from Resource can comment.
    function comment(
        uint256 _resourceId,
        uint256 _usageId,
        string calldata feedback,
        bytes calldata data
    ) public {
        // Check if user is owner of `Ask`.
        (address _bulletin, uint256 _askId) = decodeAsset(
            usages[_resourceId][_usageId].ask
        );
        Ask memory a = IBulletin(_bulletin).getAsk(_askId);
        if (a.owner != msg.sender) revert CannotComment();

        usages[_resourceId][_usageId].feedback = feedback;
        usages[_resourceId][_usageId].data = data;
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal.                                 */
    /* -------------------------------------------------------------------------- */

    function _setAsk(uint256 _askId, Ask calldata a) internal {
        // Store ask.
        asks[_askId] = Ask({
            fulfilled: false,
            role: (msg.sender == owner())
                ? uint40(uint256(_OWNER_SLOT))
                : a.role,
            owner: (msg.sender == owner()) ? msg.sender : a.owner,
            title: a.title,
            detail: a.detail,
            currency: a.currency,
            drop: a.drop
        });

        emit AskAdded(askId);
    }

    function _setResource(uint256 _resourceId, Resource calldata r) internal {
        resources[_resourceId] = Resource({
            active: r.active,
            role: (msg.sender == owner())
                ? uint40(uint256(_OWNER_SLOT))
                : r.role,
            owner: (msg.sender == owner()) ? msg.sender : r.owner,
            title: r.title,
            detail: r.detail
        });

        emit ResourceAdded(resourceId);
    }

    function _processTrade(
        uint256 _askId,
        uint256 tradeId,
        bool approved
    ) internal {
        Ask memory a = asks[_askId];

        // Check original poster.
        if (a.owner != msg.sender) revert InvalidOriginalPoster();

        // Check if `Ask` is already fulfilled.
        if (a.fulfilled) revert InvalidTrade();

        // Aprove trade.
        trades[_askId][tradeId].approved = approved;

        emit TradeApproved(_askId);
    }

    function _settleAsk(
        uint40 _askId,
        uint40 role,
        uint16[] calldata percentages
    ) internal {
        // Throw when owners mismatch.
        Ask memory a = asks[_askId];
        if (a.owner != msg.sender) revert InvalidOriginalPoster();

        // Tally and retrieve approved trades.
        Trade[] memory _trades = filterTrades(
            _askId,
            bytes32("approved"),
            role
        );

        // Throw when number of percentages does not match number of approved trades.
        if (_trades.length != percentages.length) revert SettlementMismatch();

        address _bulletin;
        uint256 _resourceId;
        for (uint256 i; i < _trades.length; ++i) {
            // Pay resource owner.
            route(
                a.currency,
                address(this),
                getResourceOwner(_trades[i].resource),
                (a.drop * percentages[i]) / TEN_THOUSAND
            );

            // Reciprocity.
            (_bulletin, _resourceId) = decodeAsset(_trades[i].resource);
            if (
                Bulletin(payable(_bulletin)).hasAnyRole(
                    address(this),
                    BULLETIN_ROLE
                )
            ) {
                IBulletin(_bulletin).incrementUsage(
                    BULLETIN_ROLE,
                    _resourceId,
                    encodeAsset(address(this), uint96(_askId))
                );
            }
        }

        // Mark ask as fulfilled.
        asks[_askId].fulfilled = true;

        emit AskSettled(_askId, _trades.length);
    }

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

    /* -------------------------------------------------------------------------- */
    /*                                  Helpers.                                  */
    /* -------------------------------------------------------------------------- */

    function filterTrades(
        uint256 id,
        bytes32 key,
        uint40 role
    ) public view returns (Trade[] memory _trades) {
        // Declare for use.
        Trade memory t;

        // Retrieve trade id, or number of trades.
        uint256 tId = tradeIds[id];

        // If trades exist, filter and return trades based on provided `key`.
        if (tId > 0) {
            _trades = new Trade[](tId);
            for (uint256 i = 1; i <= tId; ++i) {
                // Retrieve trade.
                t = trades[id][i];

                if (key == "approved") {
                    (t.approved) ? _trades[i - 1] = t : t;
                } else if (key == "role") {
                    (role == t.role) ? _trades[i - 1] = t : t;
                } else {
                    t;
                }
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

    function getAsk(uint256 id) external view returns (Ask memory a) {
        return asks[id];
    }

    function getResource(uint256 id) external view returns (Resource memory r) {
        return resources[id];
    }

    function getResource(
        bytes32 bulletinResource
    ) public view returns (Resource memory r) {
        (address _bulletin, uint256 _resourceId) = decodeAsset(
            bulletinResource
        );
        r = IBulletin(_bulletin).getResource(_resourceId);
    }

    function getResourceOwner(
        bytes32 bulletinResource
    ) public view returns (address owner) {
        (address _bulletin, uint256 _resourceId) = decodeAsset(
            bulletinResource
        );
        Resource memory r = IBulletin(_bulletin).getResource(_resourceId);
        owner = r.owner;
    }

    function getTrade(
        uint256 id,
        uint256 tradeId
    ) external view returns (Trade memory) {
        return trades[id][tradeId];
    }

    function getUsage(
        uint256 id,
        uint256 usageId
    ) external view returns (Usage memory) {
        return usages[id][usageId];
    }

    receive() external payable virtual {}
}
