// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ERC721Auction is ReentrancyGuard {
    struct Auction {
        uint256 tokenId;
        address nftContract;
        address payable seller;
        uint256 startingBid;
        uint256 highestBid;
        address payable highestBidder;
        uint256 endTime;
        bool active;
    }

    mapping(uint256 => Auction) public auctions; 
    mapping(uint256 => mapping(address => uint256)) public bids; 

    event AuctionCreated(
        uint256 indexed tokenId,
        address indexed nftContract,
        uint256 startingBid,
        uint256 endTime
    );

    event BidPlaced(
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 amount
    );

    event AuctionFinalized(
        uint256 indexed tokenId,
        address indexed winner,
        uint256 winningBid
    );

    event AuctionCancelled(
        uint256 indexed tokenId,
        address indexed seller
    );

    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startingBid,
        uint256 duration
    ) external nonReentrant {
        IERC721 nft = IERC721(nftContract);

        require(nft.ownerOf(tokenId) == msg.sender, "Only the owner can create an auction");
        require(startingBid > 0, "Starting bid must be greater than zero");

        // Transfer the NFT to the contract for escrow
        nft.transferFrom(msg.sender, address(this), tokenId);

        // Create the auction
        auctions[tokenId] = Auction({
            tokenId: tokenId,
            nftContract: nftContract,
            seller: payable(msg.sender),
            startingBid: startingBid,
            highestBid: 0,
            highestBidder: payable(address(0)),
            endTime: block.timestamp + duration,
            active: true
        });

        emit AuctionCreated(tokenId, nftContract, startingBid, block.timestamp + duration);
    }

   
    function placeBid(uint256 tokenId) external payable nonReentrant {
        Auction storage auction = auctions[tokenId];

        require(auction.active, "Auction is not active");
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(msg.value > auction.highestBid, "Bid must be higher than the current highest bid");
        require(msg.value >= auction.startingBid, "Bid must be at least the starting bid");

        // Refund the previous highest bidder
        if (auction.highestBid > 0) {
            auction.highestBidder.transfer(auction.highestBid);
        }

        // Update the auction with the new highest bid
        auction.highestBid = msg.value;
        auction.highestBidder = payable(msg.sender);

        bids[tokenId][msg.sender] = msg.value;

        emit BidPlaced(tokenId, msg.sender, msg.value);
    }

    function finalizeAuction(uint256 tokenId) external nonReentrant {
        Auction storage auction = auctions[tokenId];

        require(auction.active, "Auction is not active");
        require(block.timestamp >= auction.endTime, "Auction has not ended");

        IERC721 nft = IERC721(auction.nftContract);

        if (auction.highestBid > 0) {
            nft.transferFrom(address(this), auction.highestBidder, tokenId);

            auction.seller.transfer(auction.highestBid);

            emit AuctionFinalized(tokenId, auction.highestBidder, auction.highestBid);
        } else {
            nft.transferFrom(address(this), auction.seller, tokenId);

            emit AuctionFinalized(tokenId, auction.seller, 0);
        }

        auction.active = false;
    }

   
    function cancelAuction(uint256 tokenId) external nonReentrant {
        Auction storage auction = auctions[tokenId];

        require(auction.active, "Auction is not active");
        require(auction.seller == msg.sender, "Only the seller can cancel the auction");
        require(auction.highestBid == 0, "Cannot cancel auction with bids");

        IERC721 nft = IERC721(auction.nftContract);

        nft.transferFrom(address(this), auction.seller, tokenId);

        auction.active = false;

        emit AuctionCancelled(tokenId, msg.sender);
    }
}
