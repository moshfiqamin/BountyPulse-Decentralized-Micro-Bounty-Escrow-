// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GigPlatform {
    enum Role {
        Arbiter,
        Client,
        Freelancer
    }
    enum BountyStatus {
        Open,
        Locked,
        Completed,
        Cancelled
    }

    struct User {
        string name;
        Role role;
        string ipfsAvatarHash;
        uint256 reputationScore;
        bool isRegistered;
    }

    struct Bounty {
        address client;
        uint256 maxBudget;
        string ipfsBountyDetailsHash;
        BountyStatus status;
        address selectedFreelancer;
    }

    struct Bid {
        uint256 amount;
        bool exists;
    }

    mapping(address => User) public users;
    mapping(uint256 => Bounty) public bounties;
    uint256 public bountyCount;

    // bountyId => freelancer => Bid
    mapping(uint256 => mapping(address => Bid)) public bids;

    event UserRegistered(address indexed userAddress, string name, Role role);
    event BountyPosted(uint256 indexed bountyId, address indexed client, uint256 maxBudget);
    event BidSubmitted(uint256 indexed bountyId, address indexed freelancer, uint256 bidAmount);
    event BountyFunded(uint256 indexed bountyId, address indexed freelancer, uint256 amount);

    function registerUser(string memory _name, Role _role, string memory _ipfsAvatarHash) external {
        require(!users[msg.sender].isRegistered, "User already registered");
        require(_role == Role.Client || _role == Role.Freelancer, "Can only register as Client or Freelancer");

        uint256 repScore = 0;
        if (_role == Role.Freelancer) {
            repScore = 100;
        }

        users[msg.sender] = User({
            name: _name, role: _role, ipfsAvatarHash: _ipfsAvatarHash, reputationScore: repScore, isRegistered: true
        });

        emit UserRegistered(msg.sender, _name, _role);
    }

    function postBounty(uint256 maxBudget, string memory ipfsBountyDetailsHash) external {
        require(users[msg.sender].isRegistered, "User not registered");
        require(users[msg.sender].role == Role.Client, "Only Client can post bounties");

        uint256 bountyId = bountyCount++;

        bounties[bountyId] = Bounty({
            client: msg.sender,
            maxBudget: maxBudget,
            ipfsBountyDetailsHash: ipfsBountyDetailsHash,
            status: BountyStatus.Open,
            selectedFreelancer: address(0)
        });

        emit BountyPosted(bountyId, msg.sender, maxBudget);
    }

    function submitBid(uint256 bountyId, uint256 bidAmount) external {
        require(users[msg.sender].isRegistered, "User not registered");
        require(users[msg.sender].role == Role.Freelancer, "Only Freelancers can bid");
        require(users[msg.sender].reputationScore >= 40, "Reputation score too low");
        require(bountyId < bountyCount, "Bounty does not exist");
        require(bounties[bountyId].status == BountyStatus.Open, "Bounty is not open");
        require(bidAmount <= bounties[bountyId].maxBudget, "Bid exceeds max budget");

        bids[bountyId][msg.sender] = Bid({amount: bidAmount, exists: true});

        emit BidSubmitted(bountyId, msg.sender, bidAmount);
    }

    function fundBounty(uint256 bountyId, address freelancer) external payable {
        require(bountyId < bountyCount, "Bounty does not exist");
        Bounty storage bounty = bounties[bountyId];
        require(msg.sender == bounty.client, "Only the client can fund this bounty");
        require(bounty.status == BountyStatus.Open, "Bounty is not open");

        Bid memory selectedBid = bids[bountyId][freelancer];
        require(selectedBid.exists, "Bid does not exist for this freelancer");

        require(msg.value >= selectedBid.amount, "Sent ETH is less than the bid amount");

        bounty.status = BountyStatus.Locked;
        bounty.selectedFreelancer = freelancer;

        if (msg.value > selectedBid.amount) {
            uint256 excess = msg.value - selectedBid.amount;
            (bool success,) = msg.sender.call{value: excess}("");
            require(success, "Refund of excess ETH failed");
        }

        emit BountyFunded(bountyId, freelancer, selectedBid.amount);
    }
}
