// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

/**
 * @title AgroChainToken
 * @dev Governance token for the AgroChain system
 * @notice This token is used for governance voting and staking
 */
contract AgroChainToken is ERC20, ERC20Burnable, ERC20Snapshot, Ownable, ERC20Permit, ERC20Votes {
    // Minting caps
    uint256 private _maxSupplyCap;
    
    // Treasury address
    address private _treasuryAddress;
    
    /**
     * @dev Constructor
     * @param treasuryAddr Address of the treasury contract
     * @param initialSupply Initial token supply to mint
     * @param maxSupplyCap Maximum supply cap
     */
    constructor(
        address treasuryAddr,
        uint256 initialSupply,
        uint256 maxSupplyCap
    )
        ERC20("AgroChain", "AGRO")
        ERC20Permit("AgroChain")
        Ownable()
    {
        require(treasuryAddr != address(0), "Treasury address cannot be zero");
        require(maxSupplyCap > 0, "Cap must be positive");
        require(initialSupply <= maxSupplyCap, "Initial supply exceeds cap");
        
        _maxSupplyCap = maxSupplyCap;
        _treasuryAddress = treasuryAddr;
        
        // Mint initial supply to treasury
        _mint(treasuryAddr, initialSupply);
    }
    
    /**
     * @dev Create a new snapshot
     */
    function snapshot() public onlyOwner {
        _snapshot();
    }
    
    /**
     * @dev Mint new tokens (respecting cap)
     * @param to Address to mint tokens to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) public onlyOwner {
        require(ERC20.totalSupply() + amount <= _maxSupplyCap, "ERC20Capped: cap exceeded");
        _mint(to, amount);
    }
    
    /**
     * @dev Get the cap on total supply
     */
    function cap() public view returns (uint256) {
        return _maxSupplyCap;
    }
    
    /**
     * @dev Set new treasury address
     */
    function setTreasury(address newTreasury) public onlyOwner {
        require(newTreasury != address(0), "Treasury address cannot be zero");
        _treasuryAddress = newTreasury;
    }
    
    /**
     * @dev Get treasury address
     */
    function treasury() public view returns (address) {
        return _treasuryAddress;
    }
    
    // The following functions are overrides required by Solidity

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}