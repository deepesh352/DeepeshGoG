// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title Bondify Smart Assets
 * @notice On-chain tokenized bond issuance system.
 *         Supports multiple bond series with unique yields, maturities, and supplies.
 * @dev Template. Add audits, oracles, governance, etc.
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address user) external view returns (uint256);
    function transfer(address to, uint256 val) external returns (bool);
    function transferFrom(address from, address to, uint256 val) external returns (bool);
}

contract BondifySmartAssets {
    // --------------------------------------------------------
    // BOND TOKEN (ERC20 minimal)
    // --------------------------------------------------------
    struct BondToken {
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        mapping(address => uint256) balance;
    }

    // --------------------------------------------------------
    // BOND SERIES
    // --------------------------------------------------------
    struct BondSeries {
        uint256 id;
        uint256 interestBps;        // interest rate in basis points (e.g., 500 = 5%)
        uint256 maturity;           // unix timestamp
        uint256 totalIssued;        // total principal issued
        BondToken token;            // tokenized representation
        bool exists;
    }

    // --------------------------------------------------------
    // STATE
    // --------------------------------------------------------
    address public owner;
    IERC20 public collateral;  // e.g., USDC / DAI

    uint256 public nextSeriesId;
    mapping(uint256 => BondSeries) public series;

    // --------------------------------------------------------
    // EVENTS
    // --------------------------------------------------------
    event BondSeriesCreated(
        uint256 indexed id,
        uint256 interestBps,
        uint256 maturity,
        string name,
        string symbol
    );

    event BondPurchased(
        uint256 indexed id,
        address indexed buyer,
        uint256 principal,
        uint256 tokensMinted
    );

    event BondRedeemed(
        uint256 indexed id,
        address indexed redeemer,
        uint256 principal,
        uint256 interest,
        uint256 payout
    );

    // --------------------------------------------------------
    // MODIFIERS
    // --------------------------------------------------------
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validSeries(uint256 id) {
        require(series[id].exists, "Invalid series");
        _;
    }

    // --------------------------------------------------------
    // CONSTRUCTOR
    // --------------------------------------------------------
    constructor(address _collateral) {
        owner = msg.sender;
        collateral = IERC20(_collateral);
    }

    // --------------------------------------------------------
    // CREATE A NEW BOND SERIES
    // --------------------------------------------------------
    function createBondSeries(
        uint256 interestBps,
        uint256 maturityDays,
        string memory name,
        string memory symbol
    ) external onlyOwner returns (uint256) {
        require(interestBps > 0, "Interest required");
        require(maturityDays > 0, "Invalid maturity");

        nextSeriesId++;

        BondSeries storage s = series[nextSeriesId];
        s.id = nextSeriesId;
        s.interestBps = interestBps;
        s.maturity = block.timestamp + (maturityDays * 1 days);
        s.exists = true;

        s.token.name = name;
        s.token.symbol = symbol;
        s.token.decimals = 18;

        emit BondSeriesCreated(nextSeriesId, interestBps, s.maturity, name, symbol);

        return nextSeriesId;
    }

    // --------------------------------------------------------
    // INTERNAL TOKEN LOGIC
    // --------------------------------------------------------
    function _mint(BondToken storage t, address to, uint256 amount) internal {
        t.totalSupply += amount;
        t.balance[to] += amount;
    }

    function _burn(BondToken storage t, address from, uint256 amount) internal {
        require(t.balance[from] >= amount, "Not enough tokens");
        t.balance[from] -= amount;
        t.totalSupply -= amount;
    }

    // --------------------------------------------------------
    // BUY BONDS (MINT TOKENIZED BOND ASSETS)
    // --------------------------------------------------------
    function buyBonds(uint256 id, uint256 principal)
        external
        validSeries(id)
    {
        require(principal > 0, "Zero principal");

        BondSeries storage s = series[id];

        // Move principal to contract
        collateral.transferFrom(msg.sender, address(this), principal);

        // Mint bond tokens equal to principal
        _mint(s.token, msg.sender, principal);
        s.totalIssued += principal;

        emit BondPurchased(id, msg.sender, principal, principal);
    }

    // --------------------------------------------------------
    // REDEEM BONDS AFTER MATURITY
    // --------------------------------------------------------
    function redeemBonds(uint256 id, uint256 amount)
        external
        validSeries(id)
    {
        BondSeries storage s = series[id];
        require(block.timestamp >= s.maturity, "Not matured");

        _burn(s.token, msg.sender, amount);

        // Calculate interest
        uint256 interest = (amount * s.interestBps) / 10_000;
        uint256 payout = amount + interest;

        collateral.transfer(msg.sender, payout);

        emit BondRedeemed(id, msg.sender, amount, interest, payout);
    }

    // --------------------------------------------------------
    // VIEW FUNCTIONS
    // --------------------------------------------------------
    function bondBalance(uint256 id, address user)
        external
        view
        returns (uint256)
    {
        return series[id].token.balance[user];
    }

    function totalIssued(uint256 id)
        external
        view
        returns (uint256)
    {
        return series[id].totalIssued;
    }

    // --------------------------------------------------------
    // ADMIN
    // --------------------------------------------------------
    function updateOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
