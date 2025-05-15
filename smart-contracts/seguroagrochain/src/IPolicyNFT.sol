// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title PolicyNFT
 * @dev NFT representation of insurance policies
 * @notice Allows for secondary market trading of policies
 */
interface IPolicyNFT {
    /**
     * @dev Mint a new policy NFT
     * @param policyId ID of the insurance policy
     * @param to Address to mint the NFT to
     * @return tokenId ID of the minted NFT
     */
    function mintPolicy(uint256 policyId, address to) external returns (uint256 tokenId);
    
    /**
     * @dev Burn a policy NFT (e.g., when policy expires or is fully claimed)
     * @param tokenId ID of the NFT to burn
     */
    function burnPolicy(uint256 tokenId) external;
    
    /**
     * @dev Get policy ID associated with an NFT
     * @param tokenId ID of the NFT
     * @return policyId ID of the associated insurance policy
     */
    function getPolicyId(uint256 tokenId) external view returns (uint256 policyId);
    
    /**
     * @dev Check if a policy NFT exists
     * @param policyId ID of the insurance policy
     * @return exists Whether the NFT exists
     */
    function policyExists(uint256 policyId) external view returns (bool exists);
}