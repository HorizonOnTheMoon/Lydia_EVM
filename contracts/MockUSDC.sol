// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @dev Simple mock USDC for testing purposes
 * Anyone can mint tokens (testnet only!)
 */
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /**
     * @dev Mint tokens to yourself (testnet only!)
     * @param amount Amount to mint (in USDC units, 6 decimals)
     */
    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    /**
     * @dev Mint tokens to any address (testnet only!)
     */
    function mintTo(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
