# Nexus Lumina

> Decentralized Medical Research Funding Platform

## Overview

Nexus Lumina is a blockchain-based platform that revolutionizes how medical research is funded, tracked, and incentivized. By leveraging smart contracts on the Stacks blockchain, Nexus Lumina creates a transparent ecosystem where researchers can secure funding based on impact scores, and funders can receive tokenized representation of their contributions.


## Features

- **Impact-Based Funding**: Research projects are evaluated based on their potential impact, with funding requirements proportional to impact scores
- **Tokenized Research Contributions**: Funders receive research tokens representing their stake in projects
- **Dynamic Collateralization**: Projects maintain funding ratios to ensure proper backing of issued tokens
- **Liquidation Protection**: Underfunded projects can be liquidated to protect the ecosystem's integrity
- **Safe Mathematical Operations**: Built-in protection against integer overflow and underflow
- **Transparent Governance**: Platform administrators can update impact scores based on research progress

## Technical Architecture

Nexus Lumina is built on the Stacks blockchain using the Clarity smart contract language. The system consists of:

1. **Token Management System**: Handles the creation, transfer, and burning of research tokens
2. **Funding Position Tracker**: Maintains records of funding amounts, tokens issued, and impact scores
3. **Impact Score Registry**: Stores and updates research impact evaluations
4. **Safe Math Library**: Prevents arithmetic overflows and underflows
5. **Liquidation Mechanism**: Ensures projects maintain adequate funding ratios

## Smart Contract Functions

### Read-Only Functions

- `get-account-token-balance`: Retrieves token balance for a specific account
- `get-total-research-tokens-supply`: Returns the total supply of research tokens
- `get-current-research-impact-score`: Gets the current research impact score
- `get-research-project-details`: Retrieves details about a specific research project
- `calculate-project-funding-ratio`: Calculates the current funding ratio for a project

### Public Functions

- `update-research-impact-score`: Updates the platform's research impact score (admin only)
- `mint-research-project-tokens`: Creates new research tokens backed by STX funding
- `burn-research-project-tokens`: Burns tokens and returns proportional funding
- `transfer-research-tokens`: Transfers tokens between accounts
- `add-funding-to-project`: Adds additional funding to an existing project
- `liquidate-research-project`: Liquidates underfunded projects

### Private Functions

- `execute-token-transfer`: Internal function to handle token transfers
- `safe-multiply-numbers`: Safe multiplication preventing overflows
- `safe-add-numbers`: Safe addition preventing overflows
- `safe-subtract-numbers`: Safe subtraction preventing underflows



### Prerequisites

- Stacks blockchain wallet (Hiro Wallet recommended)
- STX tokens for funding and gas fees
- Basic understanding of blockchain transactions

### Deploying the Contract

1. Clone this repository
2. Use Clarinet or the Stacks CLI to deploy the contract:

```bash
clarinet deploy --network mainnet