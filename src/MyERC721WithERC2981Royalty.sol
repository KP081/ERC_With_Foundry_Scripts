// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MyERC721} from "./MyERC721.sol";

contract MyERC721WithERC2981Royalty is MyERC721 {
    struct RoylatyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoylatyInfo private _defalultRoyaltyInfo;

    mapping(uint256 => RoylatyInfo) private _tokenRoyaltyInfo;

    uint96 public constant FEE_DENOMINATOR = 10000;

    event DeflaultRoyalrySet(address indexed receiver, uint96 feeNumerator);
    event TokenRolyaltySet(
        uint256 indexed tokenId,
        address indexed recevier,
        uint96 feeNumerator
    );
    event TokenRolyaltyReSet(uint256 indexed tokenId);

    error InvalidRoyaltyReceiver();
    error RoyaltyTooHigh();
    error NotOwner();

    constructor(
        string memory _name,
        string memory _symbol,
        address defaultRoyalryRceiver,
        uint96 defalultRoyaltyFraction
    ) MyERC721(_name, _symbol) {
        _setDefaultRoyalty(defaultRoyalryRceiver, defalultRoyaltyFraction);
    }

    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount) {
        RoylatyInfo memory royalty = _tokenRoyaltyInfo[tokenId];

        if (royalty.receiver == address(0)) {
            royalty = _defalultRoyaltyInfo;
        }

        royaltyAmount = (salePrice * royalty.royaltyFraction) / FEE_DENOMINATOR;
        receiver = royalty.receiver;

        return (receiver, royaltyAmount);
    }

    function setDefaultRoyalty(address recevier, uint96 feeNumerator) external {
        _setDefaultRoyalty(recevier, feeNumerator);
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external {
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();

        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();

        _resetTokenRoyalty(tokenId);
    }

    function deleteDefaultRoyalty() external {
        delete _defalultRoyaltyInfo;
        emit DeflaultRoyalrySet(address(0), 0);
    }

    function getDefaultRoyaltyInfo()
        external
        view
        returns (address receiver, uint96 royaltyFraction)
    {
        return (
            _defalultRoyaltyInfo.receiver,
            _defalultRoyaltyInfo.royaltyFraction
        );
    }

    function getTokenRoyaltyInfo(
        uint256 tokenId
    ) external view returns (address receiver, uint96 royaltyFraction) {
        RoylatyInfo memory royalty = _tokenRoyaltyInfo[tokenId];
        return (royalty.receiver, royalty.royaltyFraction);
    }

    function calculateRoyalty(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (uint256) {
        (, uint256 royaltyAmount) = this.royaltyInfo(tokenId, salePrice);

        return royaltyAmount;
    }

    function _setDefaultRoyalty(
        address receiver,
        uint96 feeNumerator
    ) internal {
        if (receiver == address(0)) revert InvalidRoyaltyReceiver();
        if (feeNumerator > FEE_DENOMINATOR) revert RoyaltyTooHigh();

        _defalultRoyaltyInfo = RoylatyInfo(receiver, feeNumerator);

        emit DeflaultRoyalrySet(receiver, feeNumerator);
    }

    function _setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) internal {
        if (receiver == address(0)) revert InvalidRoyaltyReceiver();
        if (feeNumerator > FEE_DENOMINATOR) revert RoyaltyTooHigh();

        _tokenRoyaltyInfo[tokenId] = RoylatyInfo(receiver, feeNumerator);

        emit TokenRolyaltySet(tokenId, receiver, feeNumerator);
    }

    function _resetTokenRoyalty(uint256 tokenId) internal {
        delete _tokenRoyaltyInfo[tokenId];
        emit TokenRolyaltyReSet(tokenId);
    }

    function burn(uint256 tokenId) public override {
        super.burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public pure override returns (bool) {
        return
            interfaceId == 0x2a55205a || // ERC-2981
            super.supportsInterface(interfaceId);
    }
}
