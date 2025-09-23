// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {Bulletin} from "src/Bulletin.sol";
import {Collective} from "src/Collective.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {ICollective} from "src/interface/ICollective.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract CollectiveTest_Base is Test {
    Collective collective;
    Bulletin bulletin;
    MockERC20 mock;
    MockERC20 mock2;

    /// @dev Mock Users.
    address immutable alice = makeAddr("alice");
    address immutable bob = makeAddr("bob");
    address immutable charlie = makeAddr("charlie");
    address immutable owner = makeAddr("owner");

    /// @dev Mock Data.
    string TEST = "TEST";
    string TEST2 = "TEST2";
    bytes32 constant BYTES32 = bytes32("BYTES32");
    bytes constant BYTES = bytes(string("BYTES"));
    bytes constant BYTES2 = bytes(string("BYTES2"));

    /// @dev Roles, Weights, Spots.
    uint256[] roles = new uint256[](2);
    uint256[] weights = new uint256[](2);
    uint256[] spots = new uint256[](2);

    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        deployBulletin(owner);
        deployCollective(address(bulletin));

        // Roles.
        grantRole(
            address(bulletin),
            owner,
            address(collective),
            bulletin.AGENT()
        );

        // Credits.
        activate(address(bulletin), owner, owner, 10 ether);
        activate(address(bulletin), owner, alice, 10 ether);
        activate(address(bulletin), owner, bob, 10 ether);

        // Proposal roles, weights, and spots.
        roles[0] = 2;
        roles[1] = 3;
        weights[0] = 3;
        weights[1] = 5;
        spots[0] = 1;
        spots[1] = 1;
    }

    function testReceiveETH() public payable {
        (bool sent, ) = address(collective).call{value: 5 ether}("");
        assert(sent);
    }

    function deployCollective(address b) public payable {
        collective = new Collective();
        collective.init(b);
        assertEq(collective.bulletin(), b);
    }

    function deployBulletin(address user) public payable {
        bulletin = new Bulletin();
        bulletin.init(user);
        assertEq(bulletin.owner(), user);
    }

    function grantRole(
        address _bulletin,
        address _owner,
        address user,
        uint256 role
    ) public payable {
        vm.prank(_owner);
        Bulletin(payable(_bulletin)).grantRoles(user, role);
    }

    function activate(
        address _bulletin,
        address _owner,
        address user,
        uint256 amount
    ) public payable {
        vm.prank(_owner);
        Bulletin(payable(_bulletin)).activate(user, amount);
    }

    function newDocProposal(
        address proposer,
        uint256 quorum,
        string memory doc
    ) public payable returns (uint256 id) {
        bytes memory payload;
        ICollective.Proposal memory p = ICollective.Proposal({
            status: ICollective.Status.SPONSORED,
            action: ICollective.Action.NONE,
            tally: ICollective.Tally.SIMPLE_MAJORITY,
            targetProp: 0,
            quorum: uint8(quorum),
            proposer: proposer,
            payload: payload,
            doc: doc,
            roles: roles,
            weights: weights,
            spots: spots
        });
        vm.prank(proposer);
        collective.propose(0, p);

        return collective.proposalId();
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Propose.                                  */
    /* -------------------------------------------------------------------------- */

    function test_Propose_NewDoc(uint256 quorum) public {
        vm.assume(quorum > 0);
        vm.assume(100 > quorum);
        uint256 id = newDocProposal(owner, quorum, TEST);

        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.ACTIVE));
        assertEq(uint8(p.action), uint8(ICollective.Action.NONE));
        assertEq(uint8(p.tally), uint8(ICollective.Tally.SIMPLE_MAJORITY));
        assertEq(p.targetProp, 0);
        assertEq(p.quorum, quorum);
        assertEq(p.proposer, owner);
        assertEq(p.payload.length, 0);
        assertEq(p.doc, TEST);
        assertEq(p.roles.length, roles.length);
        assertEq(p.weights.length, weights.length);
        assertEq(p.spots.length, spots.length);
    }

    // function test_Propose_UpdateDoc() public {
    //     uint256 id = newDocProposal(owner, TEST);

    //     ICollective.Proposal memory p = collective.getProposal(id);
    //     assertEq(p.proposer, owner);
    // }

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
    /*                                Improvements.                               */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------------------------------------------------- */
    /*                                  Process.                                  */
    /* -------------------------------------------------------------------------- */
}
