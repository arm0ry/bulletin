// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {BulletinFactory} from "src/BulletinFactory.sol";
import {Bulletin} from "src/Bulletin.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract BulletinFactoryTest is Test {
    address payable addr;
    BulletinFactory factory;
    Bulletin bulletin;

    /// @dev Mock Users.
    address immutable alice = makeAddr("alice");
    address immutable bob = makeAddr("bob");
    address immutable charlie = makeAddr("charlie");

    /// @dev Mock Data.
    bytes32 TEST = "TEST";

    function setUp() public payable {
        bulletin = new Bulletin();
        factory = new BulletinFactory(address(bulletin));
    }

    function testDeploy(bytes32 name, address user) public payable {
        uint256 id = factory.bulletinId();
        vm.prank(user);
        address deployed = factory.deployBulletin(name);
        uint256 id_ = factory.bulletinId();
        address deployed_ = factory.bulletins(id_);
        bulletin = Bulletin(payable(deployed_));
        assertEq(id + 1, id_);
        assertEq(deployed_, deployed);
        assertEq(bulletin.owner(), user);
    }

    function testDetermination(bytes32 name, address user) public payable {
        addr = payable(factory.determineBulletin(name));
        bulletin = Bulletin(addr);

        vm.prank(user);
        factory.deployBulletin(name);
        assertEq(address(bulletin), addr);
        assertEq(bulletin.owner(), user);
    }

    function testReceiveETH() public payable {
        (bool sent, ) = address(factory).call{value: 5 ether}("");
        assert(!sent);
    }
}
