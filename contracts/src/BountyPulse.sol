// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BountyPulse {
    address public arbiter;

    enum Role { None, Client, Freelancer }
    enum BountyStatus { Open, Locked, Disputed, Resolved }

    struct User {
        string name;
        Role role;
        string ipfsAvatarHash;
        uint256 reputation;
        bool isRegistered;
    }

    struct Bid {
        address freelancer;
        uint256 quote;
    }

    struct Bounty {
        address client;
        uint256 maxBudget;
        string ipfsBountyDetailsHash;
        BountyStatus status;
        address selectedFreelancer;
        uint256 acceptedBidAmount;
        string ipfsWorkFileHash;
        uint256 arbiterFee;
        uint256 freelancerPayment;
    }

    mapping(address => User) public users;
    mapping(uint256 => Bounty) public bounties;
    mapping(uint256 => Bid[]) public bountyBids;
    mapping(address => uint256) public balances;

    uint256 public bountyCount;

    event UserRegistered(address indexed user, Role role, string name);
    event BountyPosted(uint256 indexed bountyId, address indexed client, uint256 maxBudget);
    event BidPlaced(uint256 indexed bountyId, address indexed freelancer, uint256 quote);
    event BountyFunded(uint256 indexed bountyId, address indexed freelancer, uint256 amount);
    event WorkSubmitted(uint256 indexed bountyId, string ipfsWorkFileHash);
    event WorkApproved(uint256 indexed bountyId);
    event BountyDisputed(uint256 indexed bountyId);
    event DisputeResolved(uint256 indexed bountyId, bool freelancerFault);
    event FundsClaimed(address indexed user, uint256 amount);

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter");
        _;
    }

    modifier onlyRegistered() {
        require(users[msg.sender].isRegistered, "Not registered");
        _;
    }

    modifier onlyClient() {
        require(users[msg.sender].role == Role.Client, "Only client");
        _;
    }

    modifier onlyFreelancer() {
        require(users[msg.sender].role == Role.Freelancer, "Only freelancer");
        _;
    }

    constructor() {
        arbiter = msg.sender;
    }

    function register(string memory name, Role role, string memory ipfsAvatarHash) external {
        require(!users[msg.sender].isRegistered, "Already registered");
        require(role == Role.Client || role == Role.Freelancer, "Invalid role");

        users[msg.sender] = User({
            name: name,
            role: role,
            ipfsAvatarHash: ipfsAvatarHash,
            reputation: role == Role.Freelancer ? 100 : 0,
            isRegistered: true
        });

        emit UserRegistered(msg.sender, role, name);
    }

    function postBounty(uint256 maxBudget, string memory ipfsBountyDetailsHash) external onlyRegistered onlyClient {
        uint256 id = bountyCount++;
        bounties[id] = Bounty({
            client: msg.sender,
            maxBudget: maxBudget,
            ipfsBountyDetailsHash: ipfsBountyDetailsHash,
            status: BountyStatus.Open,
            selectedFreelancer: address(0),
            acceptedBidAmount: 0,
            ipfsWorkFileHash: "",
            arbiterFee: 0,
            freelancerPayment: 0
        });

        emit BountyPosted(id, msg.sender, maxBudget);
    }

    function bid(uint256 bountyId, uint256 quote) external onlyRegistered onlyFreelancer {
        Bounty storage b = bounties[bountyId];
        require(b.status == BountyStatus.Open, "Bounty not open");
        require(quote <= b.maxBudget, "Quote exceeds max budget");
        require(users[msg.sender].reputation >= 40, "Reputation too low");

        bountyBids[bountyId].push(Bid({
            freelancer: msg.sender,
            quote: quote
        }));

        emit BidPlaced(bountyId, msg.sender, quote);
    }

    function fundBounty(uint256 bountyId, uint256 bidIndex) external payable onlyRegistered onlyClient {
        Bounty storage b = bounties[bountyId];
        require(b.status == BountyStatus.Open, "Bounty not open");
        require(b.client == msg.sender, "Not the client");
        require(bidIndex < bountyBids[bountyId].length, "Invalid bid index");

        Bid memory selectedBid = bountyBids[bountyId][bidIndex];
        require(msg.value >= selectedBid.quote, "Insufficient funds");

        b.status = BountyStatus.Locked;
        b.selectedFreelancer = selectedBid.quote > 0 ? selectedBid.freelancer : selectedBid.freelancer; // maintain reference
        b.acceptedBidAmount = selectedBid.quote;
        b.selectedFreelancer = selectedBid.freelancer;

        if (msg.value > selectedBid.quote) {
            uint256 excess = msg.value - selectedBid.quote;
            (bool success, ) = msg.sender.call{value: excess}("");
            require(success, "Refund failed");
        }

        emit BountyFunded(bountyId, b.selectedFreelancer, b.acceptedBidAmount);
    }

    function submitWork(uint256 bountyId, string memory ipfsWorkFileHash) external onlyRegistered onlyFreelancer {
        Bounty storage b = bounties[bountyId];
        require(b.status == BountyStatus.Locked, "Bounty not locked");
        require(b.selectedFreelancer == msg.sender, "Not the selected freelancer");

        b.ipfsWorkFileHash = ipfsWorkFileHash;
        emit WorkSubmitted(bountyId, ipfsWorkFileHash);
    }

    function approveWork(uint256 bountyId) external onlyRegistered onlyClient {
        Bounty storage b = bounties[bountyId];
        require(b.status == BountyStatus.Locked, "Bounty not locked");
        require(b.client == msg.sender, "Not the client");
        require(bytes(b.ipfsWorkFileHash).length > 0, "Work not submitted");

        b.status = BountyStatus.Resolved;

        uint256 fee = (b.acceptedBidAmount * 2) / 100;
        uint256 payment = b.acceptedBidAmount - fee;

        balances[arbiter] += fee;
        balances[b.selectedFreelancer] += payment;

        users[b.selectedFreelancer].reputation += 15;

        emit WorkApproved(bountyId);
    }

    function disputeBounty(uint256 bountyId) external onlyRegistered onlyClient {
        Bounty storage b = bounties[bountyId];
        require(b.status == BountyStatus.Locked, "Bounty not locked");
        require(b.client == msg.sender, "Not the client");

        b.status = BountyStatus.Disputed;
        emit BountyDisputed(bountyId);
    }

    function resolveDispute(uint256 bountyId, bool freelancerFault) external onlyArbiter {
        Bounty storage b = bounties[bountyId];
        require(b.status == BountyStatus.Disputed, "Bounty not disputed");

        b.status = BountyStatus.Resolved;

        if (freelancerFault) {
            // Refund client
            balances[b.client] += b.acceptedBidAmount;

            // Penalize freelancer (e.g. -20 rep)
            if (users[b.selectedFreelancer].reputation > 20) {
                users[b.selectedFreelancer].reputation -= 20;
            } else {
                users[b.selectedFreelancer].reputation = 0;
            }
        } else {
            // Pay freelancer and arbiter
            uint256 fee = (b.acceptedBidAmount * 2) / 100;
            uint256 payment = b.acceptedBidAmount - fee;

            balances[arbiter] += fee;
            balances[b.selectedFreelancer] += payment;

            users[b.selectedFreelancer].reputation += 15;
        }

        emit DisputeResolved(bountyId, freelancerFault);
    }

    function claimFunds() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No funds to claim");

        balances[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsClaimed(msg.sender, amount);
    }

    function getBids(uint256 bountyId) external view returns (Bid[] memory) {
        return bountyBids[bountyId];
    }
}
