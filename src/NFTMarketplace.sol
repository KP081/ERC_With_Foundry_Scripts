// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "./interfaces/IERC20.sol";
import {IERC721} from "./interfaces/IERC721.sol";

contract NFTMarketplace {
    address public owner;
    uint256 public platformFee;
    uint256 public constant MAX_FEE = 1000;
    uint256 public constant FEE_DENOMINATOR = 10000;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        address paymentToken;
        bool active;
    }

    struct Offer {
        address offerer;
        uint256 price;
        address paymentToken;
        uint256 expireAt;
        bool active;
    }

    mapping(bytes32 => Listing) public listings;

    mapping(address => mapping(uint256 => mapping(bytes32 => Offer)))
        public offers;

    mapping(address => uint256) public platformEarnings;

    event Listed(
        bytes32 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price,
        address paymentToken
    );

    event Sold(
        bytes32 indexed listingId,
        address indexed buyer,
        address indexed seller,
        uint256 price,
        uint256 royalty,
        uint256 platformFee
    );

    event ListingCancelled(bytes32 indexed listingId);

    event OfferMade(
        bytes32 indexed offerId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address offerer,
        uint256 price
    );

    event OfferAccepted(
        bytes32 indexed offerId,
        address indexed seller,
        address indexed buyer,
        uint256 price
    );

    event OfferCancelled(bytes32 indexed offerId);

    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);

    error NotOwner();
    error NotSeller();
    error ListingNotActive();
    error InvalidPrice();
    error InvalidPayment();
    error NotNFTOwner();
    error NotApproved();
    error FeeTooHigh();
    error TransferFailed();
    error OfferExpired();
    error OfferNotActive();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(uint256 _platformFee) {
        owner = msg.sender;

        if (_platformFee > MAX_FEE) revert FeeTooHigh();
        platformFee = _platformFee;
    }

    function listItem(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address paymentToken
    ) external returns (bytes32 listingId) {
        if (price == 0) revert InvalidPrice();

        IERC721 nft = IERC721(nftContract);

        if (nft.ownerOf(tokenId) != msg.sender) revert NotNFTOwner();

        if (
            nft.getApproved(tokenId) != address(this) &&
            !nft.isApprovedForAll(msg.sender, address(this))
        ) {
            revert NotApproved();
        }

        listingId = keccak256(
            abi.encodePacked(nftContract, tokenId, msg.sender, block.timestamp)
        );

        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            paymentToken: paymentToken,
            active: true
        });

        emit Listed(
            listingId,
            msg.sender,
            nftContract,
            tokenId,
            price,
            paymentToken
        );
    }

    function buyItem(bytes32 listingId) external payable {
        Listing storage listing = listings[listingId];

        if (!listing.active) revert ListingNotActive();

        listing.active = false;

        (uint256 royaltyAmount, address royaltyReceiver) = _getRoyalty(
            listing.nftContract,
            listing.tokenId,
            listing.price
        );

        uint256 platformFeeAmount = (listing.price * platformFee) /
            FEE_DENOMINATOR;
        uint256 sellerAmount = listing.price -
            royaltyAmount -
            platformFeeAmount;

        if (listing.paymentToken == address(0)) {
            if (msg.value != listing.price) revert InvalidPayment();

            _sendETH(royaltyReceiver, royaltyAmount);
            _sendETH(listing.seller, sellerAmount);

            platformEarnings[address(0)] += platformFeeAmount;
        } else {
            IERC20 token = IERC20(listing.paymentToken);

            token.transferFrom(msg.sender, royaltyReceiver, royaltyAmount);
            token.transferFrom(msg.sender, listing.seller, sellerAmount);
            token.transferFrom(msg.sender, address(this), platformFeeAmount);

            platformEarnings[listing.paymentToken] += platformFeeAmount;
        }

        IERC721(listing.nftContract).transferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );

        emit Sold(
            listingId,
            msg.sender,
            listing.seller,
            listing.price,
            royaltyAmount,
            platformFeeAmount
        );
    }

    function cancelListing(bytes32 listingId) external {
        Listing storage listing = listings[listingId];

        if (listing.seller != msg.sender) revert NotSeller();
        if (!listing.active) revert ListingNotActive();

        listing.active = false;

        emit ListingCancelled(listingId);
    }

    function makeOffer(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address paymentToken,
        uint256 duration
    ) external payable returns (bytes32 offerId) {
        if (price == 0) revert InvalidPrice();

        offerId = keccak256(
            abi.encodePacked(nftContract, tokenId, msg.sender, block.timestamp)
        );

        if (paymentToken != address(0)) {
            IERC20(paymentToken).transferFrom(msg.sender, address(this), price);
        } else {
            if (msg.value != price) revert InvalidPayment();
        }

        offers[nftContract][tokenId][offerId] = Offer({
            offerer: msg.sender,
            price: price,
            paymentToken: paymentToken,
            expireAt: block.timestamp + duration,
            active: true
        });

        emit OfferMade(offerId, nftContract, tokenId, msg.sender, price);
    }

    function acceptOffer(
        address nftContract,
        uint256 tokenId,
        bytes32 offerId
    ) external {
        IERC721 nft = IERC721(nftContract);

        if (nft.ownerOf(tokenId) != msg.sender) revert NotNFTOwner();

        Offer storage offer = offers[nftContract][tokenId][offerId];

        if (!offer.active) revert OfferNotActive();
        if (block.timestamp > offer.expireAt) revert OfferExpired();

        offer.active = false;

        (uint256 royaltyAmount, address royaltyReceiver) = _getRoyalty(
            nftContract,
            tokenId,
            offer.price
        );

        uint256 platformFeeAmount = (offer.price * platformFee) /
            FEE_DENOMINATOR;
        uint256 sellerAmount = offer.price - royaltyAmount - platformFeeAmount;

        if (offer.paymentToken == address(0)) {
            _sendETH(royaltyReceiver, royaltyAmount);
            _sendETH(msg.sender, sellerAmount);
            platformEarnings[address(0)] += platformFeeAmount;
        } else {
            IERC20 token = IERC20(offer.paymentToken);
            token.transfer(royaltyReceiver, royaltyAmount);
            token.transfer(msg.sender, sellerAmount);
            platformEarnings[offer.paymentToken] += platformFeeAmount;
        }

        nft.transferFrom(msg.sender, offer.offerer, tokenId);

        emit OfferAccepted(offerId, msg.sender, offer.offerer, offer.price);
    }

    function cancelOffer(
        address nftContract,
        uint256 tokenId,
        bytes32 offerId
    ) external {
        Offer storage offer = offers[nftContract][tokenId][offerId];

        if (offer.offerer != msg.sender) revert NotOwner();
        if (!offer.active) revert OfferNotActive();

        offer.active = false;

        if (offer.paymentToken == address(0)) {
            _sendETH(msg.sender, offer.price);
        } else {
            IERC20(offer.paymentToken).transfer(msg.sender, offer.price);
        }

        emit OfferCancelled(offerId);
    }

    function setPlatformFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE) revert FeeTooHigh();

        uint256 oldFee = platformFee;
        platformFee = newFee;

        emit PlatformFeeUpdated(oldFee, newFee);
    }

    function withdrawEarnings(address token) external onlyOwner {
        uint256 amount = platformEarnings[token];
        platformEarnings[token] = 0;

        if (token == address(0)) {
            _sendETH(owner, amount);
        } else {
            IERC20(token).transfer(owner, amount);
        }
    }

    function _getRoyalty(
        address nftContract,
        uint256 tokenId,
        uint256 salePrice
    ) internal view returns (uint256 royaltyAmount, address receiver) {
        // Try ERC-2981
        try IERC721(nftContract).supportsInterface(0x2a55205a) returns (
            bool supported
        ) {
            if (supported) {
                (bool success, bytes memory data) = nftContract.staticcall(
                    abi.encodeWithSignature(
                        "royaltyInfo(uint256,uint256)",
                        tokenId,
                        salePrice
                    )
                );

                if (success) {
                    (receiver, royaltyAmount) = abi.decode(
                        data,
                        (address, uint256)
                    );
                    return (royaltyAmount, receiver);
                }
            }
        } catch {}

        return (0, address(0));
    }

    function _sendETH(address to, uint256 amount) internal {
        if (amount == 0 || to == address(0)) return;

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    function getListing(
        bytes32 listingId
    ) external view returns (Listing memory) {
        return listings[listingId];
    }

    function getOffer(
        address nftContract,
        uint256 tokenId,
        bytes32 offerId
    ) external view returns (Offer memory) {
        return offers[nftContract][tokenId][offerId];
    }
}
