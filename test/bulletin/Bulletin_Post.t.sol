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
    function test_RequestByCredit(uint256 amount) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);
        activate(address(bulletin), owner, owner, 10 ether);

        uint256 requestId = requestByCredit(owner, amount);
        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, owner);
        assertEq(_request.data, BYTES);
        assertEq(_request.currency, address(0xc0d));
        assertEq(_request.drop, amount);

        IBulletin.Credit memory credit = bulletin.getCredit(owner);
        assertEq(credit.amount, 10 ether - amount);
    }

    function test_RequestByCurrency(uint256 amount) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

        mock.mint(owner, amount);
        uint256 requestId = requestByCurrency(owner, amount);
        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, owner);
        assertEq(_request.data, BYTES);
        assertEq(_request.currency, address(mock));
        assertEq(_request.drop, amount);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), amount);
        assertEq(MockERC20(mock).balanceOf(owner), 0);
    }

    function test_RequestByCredit_UpdateCreditAmount(
        uint256 newAmount
    ) public payable {
        vm.assume(15 ether > newAmount);
        vm.assume(newAmount > 0);

        activate(address(bulletin), owner, owner, 20 ether);
        uint256 requestId = requestByCredit(owner, 5 ether);
        updateRequest(owner, requestId, address(0xc0d), newAmount);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, owner);
        assertEq(_request.data, BYTES);
        assertEq(_request.currency, address(0xc0d));
        assertEq(_request.drop, newAmount);

        IBulletin.Credit memory credit = bulletin.getCredit(owner);
        assertEq(credit.amount, 20 ether - newAmount);
    }

    function test_RequestByCurrency_UpdateCurrencyAmount(
        uint256 newAmount
    ) public payable {
        vm.assume(15 ether > newAmount);
        vm.assume(newAmount > 0);

        mock.mint(owner, 20 ether);
        uint256 requestId = requestByCurrency(owner, 5 ether);

        mockApprove(owner, address(bulletin), 15 ether);
        updateRequest(owner, requestId, address(mock), newAmount);
        IBulletin.Request memory _request = bulletin.getRequest(requestId);

        assertEq(_request.from, owner);
        assertEq(_request.data, BYTES);
        assertEq(_request.currency, address(mock));
        assertEq(_request.drop, newAmount);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), newAmount);
        assertEq(MockERC20(mock).balanceOf(owner), 20 ether - newAmount);
    }

    function test_RequestByCredit_UpdatePaymentToCurrency(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);
        activate(address(bulletin), owner, owner, 10 ether);

        uint256 requestId = requestByCredit(owner, amount);

        mock.mint(owner, 10 ether);
        mockApprove(owner, address(bulletin), 10 ether);
        updateRequest(owner, requestId, address(mock), amount);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);
        assertEq(_request.from, owner);
        assertEq(_request.data, BYTES);
        assertEq(_request.currency, address(mock));
        assertEq(_request.drop, amount);

        assertEq(MockERC20(mock).balanceOf(address(bulletin)), amount);
        assertEq(MockERC20(mock).balanceOf(owner), 10 ether - amount);

        IBulletin.Credit memory credit = bulletin.getCredit(owner);
        assertEq(credit.amount, 10 ether);
    }

    function test_RequestByCurrency_UpdatePaymentToCredit(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

        mock.mint(owner, amount);
        uint256 requestId = requestByCurrency(owner, amount);

        activate(address(bulletin), owner, owner, 10 ether);
        updateRequest(owner, requestId, address(0xc0d), amount);

        IBulletin.Request memory _request = bulletin.getRequest(requestId);
        assertEq(_request.from, owner);
        assertEq(_request.data, BYTES);
        assertEq(_request.currency, address(0xc0d));
        assertEq(_request.drop, amount);

        assertEq(MockERC20(mock).balanceOf(owner), amount);

        IBulletin.Credit memory credit = bulletin.getCredit(owner);
        assertEq(credit.amount, 10 ether - amount);
    }

    function test_Resource() public payable {
        activate(address(bulletin), owner, owner, 10 ether);
        uint256 resourceId = resource(true, owner);
        IBulletin.Resource memory _resource = bulletin.getResource(resourceId);
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

    function testRevert_RequestByCredit_InsufficientCredit(
        uint256 amount
    ) public payable {
        vm.assume(amount > 2 ether);
        activate(address(bulletin), owner, owner, 2 ether);

        IBulletin.Request memory r = IBulletin.Request({
            from: owner,
            currency: address(0xc0d),
            drop: amount,
            data: BYTES,
            uri: TEST
        });

        vm.prank(owner);
        vm.expectRevert(IBulletin.InsufficientCredit.selector);
        bulletin.request(0, r);
    }

    function testRevert_RequestByCurrency_DropRequired(
        uint256 amount
    ) public payable {
        vm.assume(10 ether > amount);
        vm.assume(amount > 0);

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
