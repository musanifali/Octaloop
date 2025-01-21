 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTWithCollections is ERC721Enumerable, Ownable {
    struct Collection {
        address owner;
        string name;
        uint256[] tokenIds; 
    }
    struct NFT {
    uint256 tokenId;          
    address owner;           
    string metadataURI;      
    uint256 collectionId;     
    uint256 timestamp;        
    }

    uint256 public nextCollectionId; 

    mapping(uint256 => Collection) public collections; 
    mapping(uint256 => uint256) public tokenToCollection; 
    mapping(uint256 => NFT) public nfts;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {
        name = name;
        symbol = symbol;
    }

    // Create a new collection
    function createCollection(string calldata  name) external returns (uint256) {
        nextCollectionId = randomId();
        // check if id already exist or not
        require(collections[nextCollectionId].owner == address(0)," Collection id already exists");
        collections[nextCollectionId] = Collection({
            owner: msg.sender,
            name: name,
            tokenIds: new uint256[](0)
        });
        return nextCollectionId;
    }

    // Modifier to ensure collection exists and is owned by the sender
    modifier onlyCollectionOwner(uint256 collectionId) {
        require(collections[collectionId].owner == msg.sender, "Not the collection owner");
        _;
    }


    // Mint a new NFT with a random token ID and add it to a collection
    function mintWithRandomId(uint256 collectionId, string memory metadataURI) external onlyCollectionOwner(collectionId) returns (address){
        uint256 tokenId = randomId();
        require(_ownerOf(tokenId)==address(0), "NFT already exists");
        require(bytes(metadataURI).length > 0, "Metadata URI cannot be empty");

        _safeMint(msg.sender, tokenId);
        Collection storage collection = collections[collectionId];
        collection.tokenIds.push(tokenId);
        nfts[tokenId] = NFT({
            tokenId: tokenId,
            owner: msg.sender,
            metadataURI: metadataURI,
            collectionId: collectionId,
            timestamp: block.timestamp
        });
        // Associate the token with the collection
        tokenToCollection[tokenId] = collectionId;

        return msg.sender;
    }

    // Get all NFTs owned by a specific address
    function getNFTsByOwner(address owner) external view returns (uint256[] memory,uint256) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokens = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokens[i] = tokenOfOwnerByIndex(owner, i);
        }
        return (tokens ,tokenCount);
    }

    // Get all NFTs in a specific collection
     function getNFTsInCollection(uint256 collectionId)
    external
    view
    virtual
    returns (uint256[] memory, NFT[] memory)
{
    // Check if the collection exists
    require(collections[collectionId].owner != address(0), "Collection does not exist");

    // Get the token IDs in the collection
    uint256[] memory tokenIds = collections[collectionId].tokenIds;

    // Create an array to hold the NFT details
    NFT[] memory nftDetails = new NFT[](tokenIds.length);

    // Populate the NFT details array
    for (uint256 i = 0; i < tokenIds.length; i++) {
        nftDetails[i] = nfts[tokenIds[i]];
    }

    // Return the token IDs and their details
    return (tokenIds, nftDetails);
}

    function randomId() internal view returns  (uint256){
        return uint256(keccak256(abi.encodePacked(block.number,totalSupply()))) % 1e18;
    }
    
    // Get Nft detail
    function getNFTDetail( uint256 tokenId) public view returns (NFT memory){
        return nfts[tokenId];
    }
    
}
