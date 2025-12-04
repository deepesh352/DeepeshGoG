// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title Bondify Smart Assets
 * @notice A decentralized bond management contract that allows issuers to tokenize bonds,
 *         investors to purchase them, and issuers to repay investors with interest.
 */
contract BondifySmartAssets {
    
    struct Bond {
        uint256 id;
        address issuer;
        uint256 principal;
        uint256 interestRate; // Percentage (e.g., 5 means 5%)
        uint256 maturityDate; // Unix timestamp
        uint256 totalInvested;
        bool isActive;
    }

    struct Investment {
        uint256 bondId;
        uint256 amount;
        bool isRedeemed;
    }

    uint256 public bondCounter;
    mapping(uint256 => Bond) public bonds;
    mapping(address => Investment[]) public investments;
    address public owner;

    event BondCreated(uint256 indexed bondId, address indexed issuer, uint256 principal, uint256 interestRate, uint256 maturityDate);
    event BondPurchased(uint256 indexed bondId, address indexed investor, uint256 amount);
    event BondRedeemed(uint256 indexed bondId, address indexed investor, uint256 payout);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner allowed");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /** @notice Issuer creates a bond */
    function createBond(
        uint256 principal,
        uint256 interestRate,
        uint256 maturityDate
    ) external returns (uint256) {
        require(maturityDate > block.timestamp, "Invalid maturity date");

        bondCounter++;
        bonds[bondCounter] = Bond(
            bondCounter,
            msg.sender,
            principal,
            interestRate,
            maturityDate,
            0,
            true
        );

        emit BondCreated(bondCounter, msg.sender, principal, interestRate, maturityDate);
        return bondCounter;
    }

    /** @notice Investor buys a portion of a bond */
    function purchaseBond(uint256 bondId) external payable {
        Bond storage bond = bonds[bondId];
        require(bond.isActive, "Bond inactive");
        require(msg.value > 0, "Investment required");

        bond.totalInvested += msg.value;
        investments[msg.sender].push(Investment(bondId, msg.value, false));

        emit BondPurchased(bondId, msg.sender, msg.value);
    }

    /** @notice Issuer repays investor after maturity with interest */
    function redeemBond(uint256 investmentIndex) external {
        require(investments[msg.sender].length > investmentIndex, "Invalid investment");
        Investment storage inv = investments[msg.sender][investmentIndex];
        Bond storage bond = bonds[inv.bondId];

        require(bond.isActive, "Bond inactive");
        require(!inv.isRedeemed, "Already redeemed");
        require(block.timestamp >= bond.maturityDate, "Not matured");

        uint256 payout = inv.amount + (inv.amount * bond.interestRate / 100);
        inv.isRedeemed = true;
        payable(msg.sender).transfer(payout);

        emit BondRedeemed(inv.bondId, msg.sender, payout);
    }

    /** @notice Deactivate bond manually if needed (admin only) */
    function deactivateBond(uint256 bondId) external onlyOwner {
        bonds[bondId].isActive = false;
    }

    /** @notice Returns investor's investments */
    function getInvestments(address investor) external view returns (Investment[] memory) {
        return investments[investor];
    }
}
