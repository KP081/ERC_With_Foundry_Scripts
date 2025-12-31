// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);

    function transferFrom(address from, address to, uint256 tokenId) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId) external view returns (address);

    function setApprovalForAll(address operator, bool approved) external;

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
