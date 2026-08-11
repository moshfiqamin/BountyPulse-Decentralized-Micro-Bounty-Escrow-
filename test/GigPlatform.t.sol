// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {GigPlatform} from "../src/GigPlatform.sol";

contract GigPlatformTest is Test {
    GigPlatform public gigPlatform;

    address arbiter = address(1);
    address client1 = address(2);
    address freelancer1 = address(3);
    address freelancer2 = address(4);

    function setUp() public {
        vm.prank(arbiter);
        gigPlatform = new GigPlatform();
    }

    function test_RegisterUser() public {
        vm.startPrank(client1);
        gigPlatform.registerUser("Alice", GigPlatform.Role.Client, "hash1");
        (string memory name, GigPlatform.Role role, string memory hash, uint256 rep, bool isReg) =
            gigPlatform.users(client1);
        assertEq(name, "Alice");
        assertEq(uint256(role), uint256(GigPlatform.Role.Client));
        assertEq(hash, "hash1");
        assertEq(rep, 0);
        assertTrue(isReg);
        vm.stopPrank();

        vm.startPrank(freelancer1);
        gigPlatform.registerUser("Bob", GigPlatform.Role.Freelancer, "hash2");
        (name, role, hash, rep, isReg) = gigPlatform.users(freelancer1);
        assertEq(name, "Bob");
        assertEq(uint256(role), uint256(GigPlatform.Role.Freelancer));
        assertEq(hash, "hash2");
        assertEq(rep, 100);
        assertTrue(isReg);
        vm.stopPrank();
    }

    function test_RevertIf_UserAlreadyRegistered() public {
        vm.startPrank(client1);
        gigPlatform.registerUser("Alice", GigPlatform.Role.Client, "hash1");
        vm.expectRevert("User already registered");
        gigPlatform.registerUser("Alice2", GigPlatform.Role.Client, "hash1");
        vm.stopPrank();
    }

    function test_PostBounty() public {
        vm.startPrank(client1);
        gigPlatform.registerUser("Alice", GigPlatform.Role.Client, "hash1");
        gigPlatform.postBounty(1 ether, "bountyHash1");

        (
            address client,
            uint256 maxBudget,
            string memory detailsHash,
            GigPlatform.BountyStatus status,
            address selected
        ) = gigPlatform.bounties(0);
        assertEq(client, client1);
        assertEq(maxBudget, 1 ether);
        assertEq(detailsHash, "bountyHash1");
        assertEq(uint256(status), uint256(GigPlatform.BountyStatus.Open));
        assertEq(selected, address(0));
        assertEq(gigPlatform.bountyCount(), 1);
        vm.stopPrank();
    }

    function test_SubmitBid() public {
        vm.startPrank(client1);
        gigPlatform.registerUser("Alice", GigPlatform.Role.Client, "hash1");
        gigPlatform.postBounty(1 ether, "bountyHash1");
        vm.stopPrank();

        vm.startPrank(freelancer1);
        gigPlatform.registerUser("Bob", GigPlatform.Role.Freelancer, "hash2");
        gigPlatform.submitBid(0, 0.5 ether);

        (uint256 amount, bool exists) = gigPlatform.bids(0, freelancer1);
        assertEq(amount, 0.5 ether);
        assertTrue(exists);
        vm.stopPrank();
    }

    function test_RevertIf_BidExceedsMaxBudget() public {
        vm.startPrank(client1);
        gigPlatform.registerUser("Alice", GigPlatform.Role.Client, "hash1");
        gigPlatform.postBounty(1 ether, "bountyHash1");
        vm.stopPrank();

        vm.startPrank(freelancer1);
        gigPlatform.registerUser("Bob", GigPlatform.Role.Freelancer, "hash2");
        vm.expectRevert("Bid exceeds max budget");
        gigPlatform.submitBid(0, 1.5 ether);
        vm.stopPrank();
    }

    function test_FundBounty_ExactAmount() public {
        vm.startPrank(client1);
        gigPlatform.registerUser("Alice", GigPlatform.Role.Client, "hash1");
        gigPlatform.postBounty(1 ether, "bountyHash1");
        vm.stopPrank();

        vm.startPrank(freelancer1);
        gigPlatform.registerUser("Bob", GigPlatform.Role.Freelancer, "hash2");
        gigPlatform.submitBid(0, 0.5 ether);
        vm.stopPrank();

        vm.deal(client1, 2 ether);
        vm.startPrank(client1);
        gigPlatform.fundBounty{value: 0.5 ether}(0, freelancer1);

        (,,, GigPlatform.BountyStatus status, address selected) = gigPlatform.bounties(0);
        assertEq(uint256(status), uint256(GigPlatform.BountyStatus.Locked));
        assertEq(selected, freelancer1);
        assertEq(address(gigPlatform).balance, 0.5 ether);
        vm.stopPrank();
    }

    function test_FundBounty_RefundsExcessAmount() public {
        vm.startPrank(client1);
        gigPlatform.registerUser("Alice", GigPlatform.Role.Client, "hash1");
        gigPlatform.postBounty(1 ether, "bountyHash1");
        vm.stopPrank();

        vm.startPrank(freelancer1);
        gigPlatform.registerUser("Bob", GigPlatform.Role.Freelancer, "hash2");
        gigPlatform.submitBid(0, 0.5 ether);
        vm.stopPrank();

        vm.deal(client1, 2 ether);
        vm.startPrank(client1);
        uint256 balanceBefore = client1.balance;
        gigPlatform.fundBounty{value: 0.8 ether}(0, freelancer1);
        uint256 balanceAfter = client1.balance;

        (,,, GigPlatform.BountyStatus status, address selected) = gigPlatform.bounties(0);
        assertEq(uint256(status), uint256(GigPlatform.BountyStatus.Locked));
        assertEq(selected, freelancer1);
        assertEq(address(gigPlatform).balance, 0.5 ether);
        // User should have spent exactly 0.5 ether, despite sending 0.8 ether
        assertEq(balanceBefore - balanceAfter, 0.5 ether);
        vm.stopPrank();
    }

    function test_RevertIf_FundBountyLessThanBidAmount() public {
        vm.startPrank(client1);
        gigPlatform.registerUser("Alice", GigPlatform.Role.Client, "hash1");
        gigPlatform.postBounty(1 ether, "bountyHash1");
        vm.stopPrank();

        vm.startPrank(freelancer1);
        gigPlatform.registerUser("Bob", GigPlatform.Role.Freelancer, "hash2");
        gigPlatform.submitBid(0, 0.5 ether);
        vm.stopPrank();

        vm.deal(client1, 2 ether);
        vm.startPrank(client1);
        vm.expectRevert("Sent ETH is less than the bid amount");
        gigPlatform.fundBounty{value: 0.4 ether}(0, freelancer1);
        vm.stopPrank();
    }
}
