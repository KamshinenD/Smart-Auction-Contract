// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0 <0.9.0;

contract Auction {
    address payable public owner;
    uint public startBlock;
    uint public endBlock;
    string public ipfsHash;
    enum State { Started, Running, Ended, Canceled }
    State public auctionState;

    uint public highestBindingBid;
    address payable public highestBidder;
    mapping(address => uint) public bids;
    address[] public bidders; // Array to store bidder addresses
    uint bidIncrement;

    constructor() {
        owner = payable(msg.sender);
        auctionState = State.Running;
        startBlock = block.number;
        endBlock = startBlock + 4;
        ipfsHash = "";
        bidIncrement = 1 ether;
    }

    modifier notOwner() {
        require(msg.sender != owner, "Owner cannot bid");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier afterStart() {
        require(block.number >= startBlock, "Auction not started yet");
        _;
    }

    modifier beforeEnd() {
        require(block.number <= endBlock, "Auction already ended");
        _;
    }

    function min(uint a, uint b) pure internal returns (uint) {
        return a <= b ? a : b;
    }

    function placeBid() public payable notOwner afterStart beforeEnd {
        require(auctionState == State.Running, "Auction is not running");
        require(msg.value >= 100, "Bid amount too low");

        uint currentBid = bids[msg.sender] + msg.value;
        require(currentBid > highestBindingBid, "Current bid is not higher");

        if (bids[msg.sender] == 0) {
            bidders.push(msg.sender); // Add new bidder to array
        }
        
        bids[msg.sender] = currentBid;

        if (currentBid <= bids[highestBidder]) {
            highestBindingBid = min(currentBid + bidIncrement, bids[highestBidder]);
        } else {
            highestBindingBid = min(currentBid, bids[highestBidder] + bidIncrement);
            highestBidder = payable(msg.sender);
        }
    }

    function cancelAuction() public onlyOwner {
        require(auctionState == State.Running, "Auction is not running");
        auctionState = State.Canceled;
    }

    function finaliseAuction() public {
        require(auctionState == State.Canceled || block.number > endBlock, "Auction not ended or canceled");
        require(msg.sender == owner || bids[msg.sender] > 0, "Not authorized");

        if (auctionState == State.Canceled) {
            // Refund all bidders if auction is canceled
            for (uint i = 0; i < bidders.length; i++) {
                address payable bidder = payable(bidders[i]);
                uint amount = bids[bidder];
                if (amount > 0) {
                    bidder.transfer(amount);
                    bids[bidder] = 0;
                }
            }
        } else {
            // Transfer the highestBindingBid to the owner
            owner.transfer(highestBindingBid);

            // Refund the difference to the highest bidder
            uint refund = bids[highestBidder] - highestBindingBid;
            if (refund > 0) {
                highestBidder.transfer(refund);
            }

            // Refund all other bidders
            for (uint i = 0; i < bidders.length; i++) {
                address payable bidder = payable(bidders[i]);
                if (bidder != highestBidder && bids[bidder] > 0) {
                    bidder.transfer(bids[bidder]);
                    bids[bidder] = 0;
                }
            }
        }

        // End the auction
        auctionState = State.Ended;
    }
}
