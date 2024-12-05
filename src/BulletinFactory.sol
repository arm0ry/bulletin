// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {Bulletin} from "src/Bulletin.sol";
import {LibClone} from "src/utils/LibClone.sol";

/// @notice Keep Factory.
contract BulletinFactory {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Deployed(
        uint256 indexed id,
        address indexed bulletin,
        address indexed owner
    );

    /// -----------------------------------------------------------------------
    /// Immutables
    /// -----------------------------------------------------------------------

    address internal immutable bulletinTemplate;

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    uint256 public bulletinId;
    mapping(uint256 => address) public bulletins;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _bulletinTemplate) payable {
        bulletinTemplate = _bulletinTemplate;
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function determineBulletin(
        bytes32 name
    ) public view virtual returns (address) {
        return
            bulletinTemplate.predictDeterministicAddress(
                abi.encode(name),
                name,
                address(this)
            );
    }

    function deployBulletin(
        bytes32 name // create2 salt as used in `determineBulletin()`.
    ) public payable virtual returns (address) {
        // Determine bulletin address.
        address payable bulletin = payable(
            bulletinTemplate.cloneDeterministic(abi.encode(name), name)
        );

        // Initialize `msg.sender` as bulletin owner.
        Bulletin(bulletin).init(msg.sender);

        // Store bulletin by bulletinId.
        unchecked {
            ++bulletinId;
            bulletins[bulletinId] = bulletin;
        }

        emit Deployed(bulletinId, bulletin, msg.sender);

        return bulletin;
    }
}
