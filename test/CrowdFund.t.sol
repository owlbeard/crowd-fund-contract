// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {CrowdFund} from "../src/CrowdFund.sol";

contract TestCrowdFund is Test {
    CrowdFund public crowdFund;
    address public user = makeAddr("user");
    uint256 public constant AMOUNT = 100 ether;

    function setUp() public {
        crowdFund = new CrowdFund();
        deal(user, AMOUNT);
    }

    modifier startedCampaign() {
        vm.prank(user);
        crowdFund.startCampaign(
            "title",
            "description",
            AMOUNT,
            block.timestamp + 60
        );
        _;
    }

    // startCampaign() tests

    function testStartCampaign() public {
        vm.prank(user);
        crowdFund.startCampaign(
            "title",
            "description",
            AMOUNT,
            block.timestamp + 60
        );

        (
            address manager,
            uint256 id,
            string memory title,
            string memory description,
            uint256 target,
            uint256 startAt,
            uint256 deadline,
            bool finished,
            bool success
        ) = crowdFund.campaigns(0);

        assertEq(manager, user);
        assertEq(id, 0);
        assertEq(title, "title");
        assertEq(description, "description");
        assertEq(target, AMOUNT);
        assertEq(startAt, block.timestamp);
        assertEq(deadline, block.timestamp + 60);
        assertEq(finished, false);
        assertEq(success, false);
    }

    function testStartCampaignEvent() public {
        vm.expectEmit(true, true, true, true);
        emit CrowdFund.CampaignStarted(
            user,
            0,
            "title",
            "description",
            AMOUNT,
            block.timestamp,
            block.timestamp + 60
        );

        vm.prank(user);
        crowdFund.startCampaign(
            "title",
            "description",
            AMOUNT,
            block.timestamp + 60
        );
    }

    // cancelCampaign() tests

    function testCancelCampaign() public startedCampaign {
        vm.prank(user);
        crowdFund.cancelCampaign(0);

        (, , , , , , , bool finished, ) = crowdFund.campaigns(0);
        assertEq(finished, true);
    }

    function testCancelCampaignRevertsIfNotManager() public startedCampaign {
        vm.expectRevert(CrowdFund.OnlyManager.selector);
        crowdFund.cancelCampaign(0);
    }

    function testCancelCampaignRevertsIfFinished() public startedCampaign {
        vm.warp(61);
        vm.expectRevert(
            abi.encodeWithSelector(
                CrowdFund.CampaignEndedOrSucceeded.selector,
                0
            )
        );
        vm.prank(user);
        crowdFund.cancelCampaign(0);
    }

    function testCancelCampaignRevertsIfSucceded() public startedCampaign {
        vm.prank(user);
        crowdFund.contribute{value: AMOUNT}(0, AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                CrowdFund.CampaignEndedOrSucceeded.selector,
                0
            )
        );

        vm.prank(user);
        crowdFund.cancelCampaign(0);
    }

    function testCancelCampaignEvent() public startedCampaign {
        vm.expectEmit(true, false, false, false);
        emit CrowdFund.CampaignCancelled(0);

        vm.prank(user);
        crowdFund.cancelCampaign(0);
    }

    // withdraw() tests

    function testWithdraw() public startedCampaign {
        vm.prank(user);
        crowdFund.contribute{value: AMOUNT}(0, AMOUNT);

        vm.warp(61);
        console.log(
            "Ether locked in crowd fund contract: ",
            address(crowdFund).balance
        );
        uint256 campaignBalance = crowdFund.campaignBalanceOf(0);
        console.log("campaign balance before withdraw: ", campaignBalance);
        vm.prank(user);
        crowdFund.withdraw(0);
        uint256 campaignBalanceAfter = crowdFund.campaignBalanceOf(0);
        assertEq(address(crowdFund).balance, 0, "balance should be 0");
        assertEq(campaignBalanceAfter, 0);
        assertEq(user.balance, campaignBalance);
    }

    function testWithdrawRevertsIfNotManager() public startedCampaign {
        vm.expectRevert(CrowdFund.OnlyManager.selector);
        crowdFund.withdraw(0);
    }

    function testWithdrawRevertsIfCampaignNotEnded() public startedCampaign {
        crowdFund.contribute{value: AMOUNT}(0, AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(
                CrowdFund.CampaignNotFinishedOrSucceeded.selector,
                0,
                true
            )
        );
        vm.prank(user);
        crowdFund.withdraw(0);
    }

    function testWithdrawRevertsIfCampaignNotSucceded() public startedCampaign {
        vm.expectRevert(
            abi.encodeWithSelector(
                CrowdFund.CampaignNotFinishedOrSucceeded.selector,
                0,
                false
            )
        );
        vm.prank(user);
        crowdFund.withdraw(0);
    }

    function testWithdrawEvent() public startedCampaign {
        crowdFund.contribute{value: AMOUNT}(0, AMOUNT);
        vm.warp(61);
        vm.expectEmit(true, true, true, false);
        emit CrowdFund.Withdraw(0, AMOUNT, user);

        vm.prank(user);
        crowdFund.withdraw(0);
    }

    // refund() tests

    function testRefund() public startedCampaign {
        vm.prank(user);
        crowdFund.contribute{value: AMOUNT / 2}(0, AMOUNT / 2);
        vm.warp(61);

        uint256 balBeforeRefund = user.balance;
        console.log("balance before: ", balBeforeRefund);

        uint256 campaignBalanceBeforeRefund = crowdFund.campaignBalanceOf(0);
        console.log(
            "campaign balance before refund: ",
            campaignBalanceBeforeRefund
        );

        uint256 accountBalanceBeforeRefund = crowdFund.accountBalanceOf(
            user,
            0
        );
        console.log(
            "account balance before refund: ",
            accountBalanceBeforeRefund
        );

        vm.prank(user);
        crowdFund.refund(0);

        uint256 balAfterRefund = user.balance;
        console.log("balance after: ", balAfterRefund);

        uint256 campaignBalanceAfterRefund = crowdFund.campaignBalanceOf(0);
        console.log(
            "campaign balance after refund: ",
            campaignBalanceAfterRefund
        );

        uint256 accountBalanceAfterRefund = crowdFund.accountBalanceOf(user, 0);
        console.log(
            "account balance after refund: ",
            accountBalanceAfterRefund
        );

        assertEq(balAfterRefund, balBeforeRefund + campaignBalanceBeforeRefund);

        assertEq(campaignBalanceAfterRefund, 0);

        assertEq(accountBalanceAfterRefund, 0);
    }

    function testRefundRevertsIfCampaignNotBacked() public startedCampaign {
        vm.expectRevert(
            abi.encodeWithSelector(CrowdFund.CampaignNotBacked.selector, 0)
        );
        vm.warp(61);
        vm.prank(user);
        crowdFund.refund(0);
    }

    function testRefundRevertsIfCampaignSucceeded() public startedCampaign {
        vm.startPrank(user);
        crowdFund.contribute{value: AMOUNT}(0, AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(CrowdFund.CampaignSucceeded.selector, 0)
        );
        crowdFund.refund(0);
        vm.stopPrank();
    }

    function testRefundRevertsIfCampaignNotEnded() public startedCampaign {
        vm.startPrank(user);
        crowdFund.contribute{value: AMOUNT / 2}(0, AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(CrowdFund.CampaignNotEnded.selector, 0)
        );
        crowdFund.refund(0);
        vm.stopPrank();
    }

    function testRefundEvent() public startedCampaign {
        vm.startPrank(user);
        crowdFund.contribute{value: AMOUNT / 2}(0, AMOUNT / 2);
        vm.warp(61);
        vm.expectEmit(true, true, true, false);
        emit CrowdFund.Refund(0, AMOUNT / 2, user);

        crowdFund.refund(0);

        vm.stopPrank();
    }

    // contribute() tests

    function testContribute() public startedCampaign {
        vm.prank(user);
        crowdFund.contribute{value: AMOUNT / 2}(0, AMOUNT / 2);

        assertEq(crowdFund.accountBalanceOf(user, 0), AMOUNT / 2);
        assertEq(crowdFund.campaignBalanceOf(0), AMOUNT / 2);
    }

    function testContributeSetsSuccess() public startedCampaign {
        (, , , , , , , , bool success) = crowdFund.campaigns(0);

        vm.prank(user);
        crowdFund.contribute{value: AMOUNT}(0, AMOUNT);

        (, , , , , , , , bool success2) = crowdFund.campaigns(0);

        assert(success != success2);
    }

    function testContributeSetSuccessOnlyTargetAmountIsMet()
        public
        startedCampaign
    {
        (, , , , , , , , bool success) = crowdFund.campaigns(0);

        vm.prank(user);
        crowdFund.contribute{value: AMOUNT / 2}(0, AMOUNT / 2);

        (, , , , , , , , bool success2) = crowdFund.campaigns(0);

        assert(success == success2);
    }

    function testContributeRevertsIfAmountIsZero() public startedCampaign {
        vm.expectRevert(CrowdFund.AmountMustBeGreaterThanZero.selector);
        crowdFund.contribute{value: 0}(0, 0);
    }

    function testContributeRevertsIfCampaignDoesntExist()
        public
        startedCampaign
    {
        vm.expectRevert(
            abi.encodeWithSelector(CrowdFund.CampaignDoesNotExist.selector, 1)
        );
        crowdFund.contribute{value: AMOUNT}(1, AMOUNT);
    }

    function testContributeRevertsIfCampaignEnded() public startedCampaign {
        vm.warp(61);
        console.log(block.timestamp);
        vm.expectRevert(
            abi.encodeWithSelector(CrowdFund.CampaignEnded.selector, 0)
        );
        crowdFund.contribute{value: AMOUNT}(0, AMOUNT);
    }

    function testContributeEvent() public startedCampaign {
        vm.expectEmit(true, true, true, false);
        emit CrowdFund.Contribute(user, 0, AMOUNT / 2);

        vm.startPrank(user);
        crowdFund.contribute{value: AMOUNT / 2}(0, AMOUNT / 2);
        vm.stopPrank();
    }
}
