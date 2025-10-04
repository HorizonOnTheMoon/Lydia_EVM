# Lydia Spot Token

An ERC20 token smart contract with integrated Pyth Network oracle for spot trading with USDC.

## Overview

LydiaSpotToken is a Solidity smart contract that enables users to buy and sell tokens using USDC with real-time price feeds from Pyth Network. All transactions require admin signature verification for enhanced security.

## Key Features

- **Token Trading**: Buy tokens with USDC, sell tokens for USDC
- **Pyth Oracle Integration**: Real-time price feeds with 5% deviation protection
- **Admin Signature Verification**: All trades must be authorized by admin signature
- **Nonce System**: Replay attack prevention
- **Reentrancy Protection**: Secure against reentrancy attacks
- **Mint/Burn Mechanism**: Dynamic supply based on trading activity

## Architecture

### Core Functions

**buyTokens**: Purchase tokens by depositing USDC
- Validates admin signature
- Verifies Pyth price feed against provided token price
- Mints new tokens to buyer
- Transfers USDC from buyer to contract

**sellTokens**: Sell tokens to receive USDC
- Validates admin signature
- Verifies Pyth price feed against provided token price
- Burns tokens from seller
- Transfers USDC from contract to seller

### Security Mechanisms

- **Signature Verification**: EIP-191 compliant message signatures
- **Price Validation**: Maximum 5% deviation between oracle and provided price
- **Nonce Tracking**: Single-use nonces prevent transaction replay
- **Access Control**: Ownable pattern for privileged operations
- **Reentrancy Guard**: Protection on all state-changing functions

## Technical Specifications

- **Solidity Version**: 0.8.19
- **Token Standard**: ERC20
- **Oracle**: Pyth Network
- **Payment Token**: USDC (6 decimals)
- **Token Decimals**: 18
- **Price Decimals**: 8

## Dependencies

- OpenZeppelin Contracts v4.9.3
- Pyth SDK Solidity v2.2.0
- Hardhat Development Environment

## License

GPL-3.0
