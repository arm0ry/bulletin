// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {BulletinTest} from "test/bulletin/Bulletin_Setup.t.sol";
import {MockERC20} from "lib/solady/test/utils/mocks/MockERC20.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract BulletinTest_Post is Test, BulletinTest {
    function test_Request(uint256 amount) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);
        activate(address(bulletin), owner, owner, 10 ether);

        uint256 requestId = requestByCredit(true, owner, amount);
        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, owner);
        assertEq(_request.data, BYTES);
        assertEq(_request.currency, address(0xc0d));
        assertEq(_request.drop, amount);
    }

    function test_RequestByCredit(uint256 amount) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);
        activate(address(bulletin), owner, owner, 10 ether);

        uint256 requestId = requestByCredit(true, owner, amount);
        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, owner);
        assertEq(_request.data, BYTES);
        assertEq(_request.currency, address(0xc0d));
        assertEq(_request.drop, amount);
    }

    function test_RequestByCurrency(uint256 amount) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

        activate(address(bulletin), owner, owner, 10 ether);
        mock.mint(owner, amount);
        uint256 requestId = requestByCurrency(true, owner, amount);
        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, owner);
        assertEq(_request.data, BYTES);
        assertEq(_request.currency, address(mock));
        assertEq(_request.drop, amount);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), amount);
        assertEq(MockERC20(mock).balanceOf(owner), 0);
    }

    function test_RequestByCredit_UpdateCreditAmount() public payable {
        activate(address(bulletin), owner, owner, 20 ether);
        uint256 requestId = requestByCredit(true, owner, 5 ether);
        updateRequest(owner, requestId, address(0xc0d), 10 ether);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, owner);
        assertEq(_request.data, BYTES);
        assertEq(_request.currency, address(0xc0d));
        assertEq(_request.drop, 10 ether);
    }

    // TODO:
    function test_RequestByCurrency_UpdateCurrencyAmount() public payable {}

    // TODO:
    function test_Request_UpdateCurrency_CreditToCurrency() public payable {}

    // TODO:
    function test_Request_UpdateCurrency_CurrencyToCredit() public payable {}

    function test_Resource() public payable {
        activate(address(bulletin), owner, owner, 10 ether);
        uint256 resourceId = resource(true, owner);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        uint256 role = Bulletin(bulletin).rolesOf(owner);
        emit log_uint(role);

        assertEq(_resource.from, owner);
        assertEq(_resource.data, BYTES);
    }

    function test_Resource_Update() public payable {
        activate(address(bulletin), owner, owner, 10 ether);
        uint256 resourceId = resource(true, owner);

        activate(address(bulletin), owner, charlie, 10 ether);
        updateResource(owner, charlie, resourceId);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);

        assertEq(_resource.from, charlie);
        assertEq(_resource.data, BYTES);
    }

    function test_updateSimpleResponse_NotOriginalPoster(
        uint256 _requestId,
        uint256 _tradeId
    ) public payable {
        vm.prank(owner);
        vm.expectRevert(IBulletin.NotOriginalPoster.selector);
        bulletin.approveTradeToRequest(_requestId, _tradeId, 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Reverts.                                  */
    /* -------------------------------------------------------------------------- */

    function testRevert_RequestByCredit_DropRequired(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);
        activate(address(bulletin), owner, owner, 10 ether);

        IBulletin.Request memory r = IBulletin.Request({
            from: owner,
            currency: address(0xc0d),
            drop: 0,
            data: BYTES,
            uri: TEST
        });

        vm.prank(owner);
        vm.expectRevert(IBulletin.DropRequired.selector);
        bulletin.request(0, r);
    }

    function testRevert_RequestByCurrency_DropRequired(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);
        // activate(address(bulletin), owner, owner, 10 ether);

        vm.prank(owner);
        mock.mint(owner, 10 ether);

        IBulletin.Request memory r = IBulletin.Request({
            from: owner,
            currency: address(mock),
            drop: 0,
            data: BYTES,
            uri: TEST
        });

        vm.prank(owner);
        vm.expectRevert(IBulletin.DropRequired.selector);
        bulletin.request(0, r);
    }

    function testRevert_RequestByCredit_NotEnoughCreditToPost(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

        vm.prank(owner);
        bulletin.updateCreditLimitToPost(1 ether, 0);

        IBulletin.Request memory r = IBulletin.Request({
            from: owner,
            currency: address(0xc0d),
            drop: 0,
            data: BYTES,
            uri: TEST
        });

        vm.prank(owner);
        vm.expectRevert(IBulletin.NotEnoughCreditToPost.selector);
        bulletin.request(0, r);
    }
}
