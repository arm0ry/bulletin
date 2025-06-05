// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";
import {IERC20} from "src/interface/IERC20.sol";
import {BERC6909} from "src/BERC6909.sol";

import {console} from "lib/forge-std/src/console.sol";

/// @title Bulletin
/// @notice A system to store and interact with requests and resources.
/// @author audsssy.eth
contract Voting is OwnableRoles, IBulletin {
    // TODO: calculate votes based on IBulletin.Credit
    // TODO: submit an action (distribute(), request(), resource(), claim()) for collective to decide on
    // TODO: pick a way (majority, supermajority) to resolve decision
    // TODO: execute action
    // TODO: deposit() to deposit nft
    // TODO: distribute()
}
