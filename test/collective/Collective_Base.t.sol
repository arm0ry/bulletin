// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {Bulletin} from "src/Bulletin.sol";
import {Collective} from "src/Collective.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {ICollective} from "src/interface/ICollective.sol";

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
    uint256 ARTISTS = 1 << 5;
    uint256 OPERATIONS = 1 << 6;
    uint256 RELATIONS = 1 << 7;
    uint256[] roles = new uint256[](2);
    uint256[] weights = new uint256[](2);
    uint256[] spotsCap = new uint256[](2);

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
            bulletin.COLLECTIVE()
        );

        // Credits.
        activate(address(bulletin), owner, address(collective), 10 ether);
        activate(address(bulletin), owner, owner, 10 ether);
        activate(address(bulletin), owner, alice, 10 ether);
        activate(address(bulletin), owner, bob, 10 ether);

        // Proposal roles, weights, and spotsCap.
        roles[0] = ARTISTS;
        roles[1] = OPERATIONS;
        weights[0] = 3;
        weights[1] = 5;
        spotsCap[0] = 1;
        spotsCap[1] = 1;
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
    ) public payable returns (uint256) {
        vm.prank(_owner);
        Bulletin(payable(_bulletin)).grantRoles(user, role);

        return Bulletin(payable(_bulletin)).rolesOf(user);
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

    function postProposal(
        address proposer,
        uint8 quorum,
        ICollective.Tally tally,
        ICollective.Action action,
        bytes memory payload,
        string memory doc
    ) public returns (uint256 id) {
        ICollective.Proposal memory p = ICollective.Proposal({
            status: ICollective.Status.COSIGNED,
            action: action,
            tally: tally,
            targetProp: 0,
            quorum: quorum,
            proposer: proposer,
            payload: payload,
            doc: doc,
            roles: roles,
            weights: weights,
            spotsUsed: spotsCap,
            spotsCap: spotsCap
        });
        vm.prank(proposer);
        collective.propose(0, p);

        return collective.proposalId();
    }

    function postImpProposal(
        uint40 targetProp,
        address proposer,
        uint8 quorum,
        ICollective.Tally tally,
        ICollective.Action action,
        bytes memory payload,
        string memory doc
    ) public returns (uint256 id) {
        ICollective.Proposal memory p = ICollective.Proposal({
            status: ICollective.Status.COSIGNED,
            action: action,
            tally: tally,
            quorum: quorum,
            targetProp: targetProp,
            proposer: proposer,
            payload: payload,
            doc: doc,
            roles: roles,
            weights: weights,
            spotsUsed: spotsCap,
            spotsCap: spotsCap
        });
        vm.prank(proposer);
        collective.raise(0, p);

        return collective.proposalId();
    }

    function getPayload_Credit(
        address user,
        uint256 amount
    ) public pure returns (bytes memory) {
        return abi.encode(user, amount);
    }

    function getPayload_Request(
        uint256 id,
        IBulletin.Request memory req
    ) public pure returns (bytes memory) {
        return abi.encode(id, req);
    }
    function getPayload_Resource(
        uint256 id,
        IBulletin.Resource memory res
    ) public pure returns (bytes memory) {
        return abi.encode(id, res);
    }

    function getPayload_ApproveTradeToRequest(
        uint256 subjectId,
        uint256 tradeId,
        uint256 amount
    ) public pure returns (bytes memory) {
        return abi.encode(subjectId, tradeId, amount);
    }
    function getPayload_ApproveTradeForResource(
        uint256 subjectId,
        uint256 tradeId,
        uint256 duration
    ) public pure returns (bytes memory) {
        return abi.encode(subjectId, tradeId, duration);
    }

    function getPayload_Trade(
        IBulletin.TradeType tt,
        uint256 subjectId,
        IBulletin.Trade memory trade
    ) public pure returns (bytes memory) {
        return abi.encode(tt, subjectId, trade);
    }

    function getPayload_WithdrawRequestOrResource(
        uint256 subjectId
    ) public pure returns (bytes memory) {
        return abi.encode(subjectId);
    }

    function getPayload_WithdrawTrade(
        IBulletin.TradeType tt,
        uint256 subjectId,
        uint256 tradeId
    ) public pure returns (bytes memory) {
        return abi.encode(tt, subjectId, tradeId);
    }

    function getPayload_Claim(
        IBulletin.TradeType tt,
        uint256 subjectId,
        uint256 tradeId
    ) public pure returns (bytes memory) {
        return abi.encode(tt, subjectId, tradeId);
    }

    function getPayload_Pause(
        uint256 subjectId,
        uint256 tradeId
    ) public pure returns (bytes memory) {
        return abi.encode(subjectId, tradeId);
    }

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
