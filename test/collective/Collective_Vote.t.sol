// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {CollectiveTest_Base} from "test/collective/Collective_Base.t.sol";
import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {ICollective} from "src/interface/ICollective.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

contract CollectiveTest_Vote is Test, CollectiveTest_Base {
    function test_Sponsor() public {
        // uint256 _roles = bulletin.rolesOf(bob);
        // emit ICollective.CheckNumber(_roles);
        // bool isDenounced = bulletin.hasAnyRole(bob, bulletin.DENOUNCED());
        // emit ICollective.CheckBool(isDenounced);

        bytes memory payload;
        uint256 id = postProposal(
            owner,
            10,
            ICollective.Tally.QUADRATIC,
            ICollective.Action.NONE,
            payload,
            TEST
        );

        grantRole(address(bulletin), owner, bob, ARTISTS);

        vm.prank(bob);
        collective.sponsor(id);
        ICollective.Proposal memory p = collective.getProposal(id);
        assertEq(uint8(p.status), uint8(ICollective.Status.SPONSORED));
    }
}
