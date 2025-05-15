// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IPolicyNFT.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title PolicyNFT
 * @dev NFT representation of insurance policies
 * @notice Allows for secondary market trading of policies
 */
contract PolicyNFT is IPolicyNFT, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable {
    using Counters for Counters.Counter;
    
    // Custom errors
    error UnauthorizedCaller();
    error PolicyAlreadyTokenized();
    error PolicyNotFound();
    error InvalidMetadata();
    
    // Token counter
    Counters.Counter private _tokenIdCounter;
    
    // Insurance contract address
    address private _insuranceContract;
    
    // Mapping from policy ID to token ID
    mapping(uint256 => uint256) private _policyIdToTokenId;
    
    // Mapping from token ID to policy ID
    mapping(uint256 => uint256) private _tokenIdToPolicyId;
    
    // Policy metadata
    struct PolicyMetadata {
        string region;
        string cropType;
        uint256 coverageAmount;
        uint256 startDate;
        uint256 endDate;
        uint256 premium;
        string climateParameters;
    }
    
    // Mapping from token ID to metadata
    mapping(uint256 => PolicyMetadata) private _tokenMetadata;
    
    // Events
    event PolicyTokenized(uint256 indexed policyId, uint256 indexed tokenId, address owner);
    event PolicyNFTBurned(uint256 indexed policyId, uint256 indexed tokenId);
    
    /**
     * @dev Constructor
     * @param insuranceContract Address of the insurance contract
     */
    constructor(address insuranceContract) ERC721("AgroChain Policy", "AGROP") {
        require(insuranceContract != address(0), "Invalid insurance contract");
        _insuranceContract = insuranceContract;
    }
    
    /**
     * @dev Modifier to check if caller is the insurance contract
     */
    modifier onlyInsurance() {
        if (msg.sender != _insuranceContract) revert UnauthorizedCaller();
        _;
    }
    
    /**
     * @dev Mint a new policy NFT
     */
    function mintPolicy(uint256 policyId, address to) 
        external 
        override 
        onlyInsurance 
        returns (uint256 tokenId) 
    {
        // Check if policy already tokenized
        if (_policyIdToTokenId[policyId] != 0) revert PolicyAlreadyTokenized();
        
        // Increment token counter
        _tokenIdCounter.increment();
        tokenId = _tokenIdCounter.current();
        
        // Set mappings
        _policyIdToTokenId[policyId] = tokenId;
        _tokenIdToPolicyId[tokenId] = policyId;
        
        // Mint token
        _safeMint(to, tokenId);
        
        emit PolicyTokenized(policyId, tokenId, to);
        
        return tokenId;
    }
    
    /**
     * @dev Burn a policy NFT
     */
    function burnPolicy(uint256 tokenId) 
        external 
        override 
        onlyInsurance 
    {
        // Check if token exists
        require(_exists(tokenId), "Token does not exist");
        
        // Get policy ID
        uint256 policyId = _tokenIdToPolicyId[tokenId];
        
        // Remove mappings
        delete _policyIdToTokenId[policyId];
        delete _tokenIdToPolicyId[tokenId];
        delete _tokenMetadata[tokenId];
        
        // Burn token
        _burn(tokenId);
        
        emit PolicyNFTBurned(policyId, tokenId);
    }
    
    /**
     * @dev Set policy metadata
     */
    function setMetadata(
        uint256 tokenId,
        string memory region,
        string memory cropType,
        uint256 coverageAmount,
        uint256 startDate,
        uint256 endDate,
        uint256 premium,
        string memory climateParameters
    ) 
        external 
        onlyInsurance 
    {
        // Check if token exists
        require(_exists(tokenId), "Token does not exist");
        
        // Set metadata
        _tokenMetadata[tokenId] = PolicyMetadata({
            region: region,
            cropType: cropType,
            coverageAmount: coverageAmount,
            startDate: startDate,
            endDate: endDate,
            premium: premium,
            climateParameters: climateParameters
        });
        
        // Generate token URI string
        string memory uri = generateTokenURI(tokenId);
        
        // Set token URI
        _setTokenURI(tokenId, uri);
    }
    
    /**
     * @dev Get policy ID associated with an NFT
     */
    function getPolicyId(uint256 tokenId) 
        external 
        view 
        override 
        returns (uint256 policyId) 
    {
        if (!_exists(tokenId)) revert PolicyNotFound();
        return _tokenIdToPolicyId[tokenId];
    }
    
    /**
     * @dev Get token ID associated with a policy
     */
    function getTokenId(uint256 policyId) 
        external 
        view 
        returns (uint256 tokenId) 
    {
        tokenId = _policyIdToTokenId[policyId];
        if (tokenId == 0) revert PolicyNotFound();
        return tokenId;
    }
    
    /**
     * @dev Check if a policy NFT exists
     */
    function policyExists(uint256 policyId) 
        external 
        view 
        override 
        returns (bool exists) 
    {
        return _policyIdToTokenId[policyId] != 0;
    }
    
    /**
     * @dev Get policy metadata
     */
    function getMetadata(uint256 tokenId) 
        external 
        view 
        returns (
            string memory region,
            string memory cropType,
            uint256 coverageAmount,
            uint256 startDate,
            uint256 endDate,
            uint256 premium,
            string memory climateParameters
        ) 
    {
        if (!_exists(tokenId)) revert PolicyNotFound();
        
        PolicyMetadata memory metadata = _tokenMetadata[tokenId];
        
        return (
            metadata.region,
            metadata.cropType,
            metadata.coverageAmount,
            metadata.startDate,
            metadata.endDate,
            metadata.premium,
            metadata.climateParameters
        );
    }
    
    /**
     * @dev Generate token URI with on-chain metadata
     */
    function generateTokenURI(uint256 tokenId) internal view returns (string memory) {
        PolicyMetadata memory metadata = _tokenMetadata[tokenId];
        
        // Convert dates to readable format
        string memory startDateStr = uint256ToString(metadata.startDate);
        string memory endDateStr = uint256ToString(metadata.endDate);
        
        // Format coverage amount
        string memory coverageStr = formatAmount(metadata.coverageAmount);
        string memory premiumStr = formatAmount(metadata.premium);
        
        // Create JSON metadata
        string memory json = string(
            abi.encodePacked(
                '{',
                '"name": "AgroChain Policy #', uint256ToString(tokenId), '",',
                '"description": "Agricultural parametric insurance policy on AgroChain",',
                '"attributes": [',
                '{"trait_type": "Region", "value": "', metadata.region, '"},',
                '{"trait_type": "Crop Type", "value": "', metadata.cropType, '"},',
                '{"trait_type": "Coverage", "value": "', coverageStr, ' ETH"},',
                '{"trait_type": "Premium", "value": "', premiumStr, ' ETH"},',
                '{"trait_type": "Start Date", "value": "', startDateStr, '"},',
                '{"trait_type": "End Date", "value": "', endDateStr, '"},',
                '{"trait_type": "Parameters", "value": "', metadata.climateParameters, '"}',
                ']',
                '}'
            )
        );
        
        // Encode as base64
        string memory base64Json = Base64.encode(bytes(json));
        
        // Create data URI
        return string(abi.encodePacked("data:application/json;base64,", base64Json));
    }
    
    /**
     * @dev Convert uint256 to string
     */
    function uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        
        uint256 temp = value;
        uint256 digits;
        
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
    
    /**
     * @dev Format amount with 2 decimal places
     */
    function formatAmount(uint256 amount) internal pure returns (string memory) {
        // Convert to ether units with 2 decimal places
        uint256 ethValue = amount / 1e16; // Convert wei to eth / 100
        
        string memory integerPart = uint256ToString(ethValue / 100);
        string memory decimalPart = uint256ToString(ethValue % 100);
        
        // Pad decimal part with leading zeros
        if (ethValue % 100 < 10) {
            decimalPart = string(abi.encodePacked("0", decimalPart));
        }
        
        return string(abi.encodePacked(integerPart, ".", decimalPart));
    }
    
    /**
     * @dev Pause token transfers
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause token transfers
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Update insurance contract
     */
    function setInsuranceContract(address newInsuranceContract) external onlyOwner {
        require(newInsuranceContract != address(0), "Invalid insurance contract");
        _insuranceContract = newInsuranceContract;
    }
    
    // Override required functions
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}