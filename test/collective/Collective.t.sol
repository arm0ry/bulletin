// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {Bulletin} from "src/Bulletin.sol";
import {Collective} from "src/Collective.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract CollectiveTest is Test {
    Collective collective;
    Bulletin bulletin;
    MockERC20 mock;
    MockERC20 mock2;

    /// @dev Mock Users.
    address immutable alice = makeAddr("alice");
    address immutable bob = makeAddr("bob");
    address immutable charlie = makeAddr("charlie");
    address immutable owner = makeAddr("owner");

    /// @dev Roles.
    bytes32 internal constant _OWNER_SLOT =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff74873927;
    uint40 public constant BULLETIN_ROLE = 1 << 0;

    /// @dev Mock Data.
    uint40 constant PAST = 100000;
    uint40 constant FUTURE = 2527482181;
    string TEST = "TEST";
    string TEST2 = "TEST2";
    bytes32 constant BYTES32 = bytes32("BYTES32");
    bytes constant BYTES = bytes(string("BYTES"));
    bytes constant BYTES2 = bytes(string("BYTES2"));

    uint256[] itemIds;

    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        deployCollective(owner);
    }

    function testReceiveETH() public payable {
        (bool sent, ) = address(collective).call{value: 5 ether}("");
        assert(sent);
    }

    function deployCollective(address user) public payable {
        collective = new Collective();
        collective.init(user, 1 weeks);
        assertEq(collective.bulletin(), user);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Propose.                                  */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------------------------------------------------- */
    /*                              Cancel Proposals.                             */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------------------------------------------------- */
    /*                                  Sponsor.                                  */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------------------------------------------------- */
    /*                                    Vote.                                   */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------------------------------------------------- */
    /*                                   Object.                                  */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------------------------------------------------- */
    /*                                  Process.                                  */
    /* -------------------------------------------------------------------------- */
}
