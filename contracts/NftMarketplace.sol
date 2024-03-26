// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error NftMarketPlace__PriceMustBeAboveZero();
error NftMarketPlace__NotApprovedForMarketplace();
error NftMarketPlace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketPlace__NotOwner();
error NftMarketPlace__NotListed(address nftAddress, uint256 tokenId);
error NftMarketPlace__PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error NftMarketPlace__NoProceeds();
error NftMarketPlace__TransferFailed();

contract NftMarketPlace is ReentrancyGuard {
  struct Listing {
    uint256 price;
    address seller;
  }

  event ItemListed(
    address indexed seller,
    address indexed nftAddress,
    uint256 indexed tokenId,
    uint256 price
  );

  event ItemBought(
    address indexed buyer,
    address indexed nftAddress,
    uint256 indexed tokenId,
    uint256 price
  );

  event ItemCanceled(address indexed seller, address indexed nftAddress, uint256 indexed tokenId);

  // NFT Contract address -> NFT TokenID -> Listing(Price, Seller, TimeStamp)
  mapping(address => mapping(uint256 => Listing)) private s_listings;
  // Seller address -> Amount earned
  mapping(address => uint256) private s_proceeds;

  modifier notListed(
    address nftAddress,
    uint256 tokenId,
    address owner
  ) {
    Listing memory listing = s_listings[nftAddress][tokenId];
    if (listing.price > 0) {
      revert NftMarketPlace__AlreadyListed(nftAddress, tokenId);
    }
    _;
  }

  modifier isOwner(
    address nftAddress,
    uint256 tokenId,
    address spender
  ) {
    IERC721 nft = IERC721(nftAddress);
    if (spender != nft.ownerOf(tokenId)) {
      revert NftMarketPlace__NotOwner();
    }
    _;
  }

  modifier isListed(address nftAddress, uint256 tokenId) {
    Listing memory listing = s_listings[nftAddress][tokenId];
    if (listing.price <= 0) {
      revert NftMarketPlace__NotListed(nftAddress, tokenId);
    }
    _;
  }

  /*
   * @notice List an NFT for sale on the marketplace
   * @param nftAddress: Address of the NFT contract
   * @param tokenId: Token ID of the NFT
   * @param price: Price of the NFT
   * @dev Only the owner of the NFT can list it for sale
   */

  // Check if the owner of the NFT is msg.sender so only they can call the function

  function listItem(
    address nftAddress,
    uint256 tokenId,
    uint256 price
  ) external notListed(nftAddress, tokenId, msg.sender) isOwner(nftAddress, tokenId, msg.sender) {
    if (price <= 0) {
      revert NftMarketPlace__PriceMustBeAboveZero();
    }
    /* To list the NFT we can 
        1. Transfer the NFT to this contract. Contract "hold" the NFT. (Gas expensive, needs approval)
        2. Owner can hold the NFT and approve the marketplace to sell the NFT for them.
    */
    IERC721 nft = IERC721(nftAddress); // Create an instance of the NFT contract
    if (nft.getApproved(tokenId) != address(this)) {
      revert NftMarketPlace__NotApprovedForMarketplace();
    }
    s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
    emit ItemListed(msg.sender, nftAddress, tokenId, price);
  }

  function buyItem(
    address nftAdress,
    uint256 tokenId
  ) external payable nonReentrant isListed(nftAdress, tokenId) {
    Listing memory listedItem = s_listings[nftAdress][tokenId];
    if (msg.value < listedItem.price) {
      revert NftMarketPlace__PriceNotMet(nftAdress, tokenId, listedItem.price);
    }
    // Why don't we just send the seller the money?
    // Sending the money to the user is a security risk, they could have a fallback function that reverts
    // Have them withdraw the money themselves
    s_proceeds[listedItem.seller] += msg.value; // Add the amount to the seller's proceeds
    // Once the item is bought, we need to delete the listing
    delete s_listings[nftAdress][tokenId];
    // the transferFrom function will transfer the NFT from the seller to the buyer(msg.sender)
    IERC721(nftAdress).safeTransferFrom(listedItem.seller, msg.sender, tokenId);
    emit ItemBought(msg.sender, nftAdress, tokenId, listedItem.price);
  }

  function cancelListing(
    address nftAddress,
    uint256 tokenId
  ) external isOwner(nftAddress, tokenId, msg.sender) isListed(nftAddress, tokenId) {
    delete s_listings[nftAddress][tokenId];
    emit ItemCanceled(msg.sender, nftAddress, tokenId);
  }

  function updateListing(
    address nftAddress,
    uint256 tokenId,
    uint256 price
  ) external isOwner(nftAddress, tokenId, msg.sender) isListed(nftAddress, tokenId) {
    s_listings[nftAddress][tokenId].price = price;
    emit ItemListed(msg.sender, nftAddress, tokenId, price);
  }

  function withdrawProceeds() external {
    uint256 proceeds = s_proceeds[msg.sender];
    if (proceeds <= 0) {
      revert NftMarketPlace__NoProceeds();
    }
    s_proceeds[msg.sender] = 0;
    // With transfer function, the gas is paid by the recipient
    // payable(msg.sender).transfer(proceeds);
    (bool success, ) = payable(msg.sender).call{value: proceeds}("");
    if (!success) {
      revert NftMarketPlace__TransferFailed();
    }
  }

  function getListing(address nftAddress, uint256 tokenId) external view returns (Listing memory) {
    return s_listings[nftAddress][tokenId];
  }

  function getProceeds(address seller) external view returns (uint256) {
    return s_proceeds[seller];
  }
}
