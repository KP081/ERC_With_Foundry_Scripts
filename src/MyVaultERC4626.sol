// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "./interfaces/IERC20.sol";

contract MyVaultERC4626 {
    IERC20 public immutable asset; // Underlying token (e.g., USDC)

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply; // Total vault shares
    mapping(address => uint256) public balanceOf; // Share balances
    mapping(address => mapping(address => uint256)) public allowance;

    event Deposit(
        address indexed caller,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroShares();
    error ZeroAssets();
    error InvalidReceiver();

    constructor(IERC20 _asset, string memory _name, string memory _symbol) {
        asset = _asset;
        name = _name;
        symbol = _symbol;
    }

    // ==================== ERC-4626: Deposit/Withdraw ====================

    function deposit(
        uint256 assets,
        address receiver
    ) public virtual returns (uint256 shares) {
        if (assets == 0) revert ZeroAssets();

        // Calculate shares to mint
        shares = previewDeposit(assets);
        if (shares == 0) revert ZeroShares();

        // Transfer assets from user
        asset.transferFrom(msg.sender, address(this), assets);

        // Mint shares
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(
        uint256 shares,
        address receiver
    ) public returns (uint256 assets) {
        if (shares == 0) revert ZeroShares();

        // Calculate assets needed
        assets = previewMint(shares);
        if (assets == 0) revert ZeroAssets();

        // Transfer assets from user
        asset.transferFrom(msg.sender, address(this), assets);

        // Mint shares
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual returns (uint256 shares) {
        if (assets == 0) revert ZeroAssets();

        // Calculate shares to burn
        shares = previewWithdraw(assets);
        if (shares == 0) revert ZeroShares();

        // Check allowance if not owner
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed < shares) revert InsufficientAllowance();
            if (allowed != type(uint256).max) {
                allowance[owner][msg.sender] = allowed - shares;
            }
        }

        // Burn shares
        _burn(owner, shares);

        // Transfer assets
        asset.transfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public returns (uint256 assets) {
        if (shares == 0) revert ZeroShares();

        // Calculate assets to withdraw
        assets = previewRedeem(shares);
        if (assets == 0) revert ZeroAssets();

        // Check allowance if not owner
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed < shares) revert InsufficientAllowance();
            if (allowed != type(uint256).max) {
                allowance[owner][msg.sender] = allowed - shares;
            }
        }

        // Burn shares
        _burn(owner, shares);

        // Transfer assets
        asset.transfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    // ==================== ERC-4626: Accounting ====================

    function totalAssets() public view virtual returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        return
            supply == 0 ? shares : _divRoundUp(shares * totalAssets(), supply);
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        return
            supply == 0 ? assets : _divRoundUp(assets * supply, totalAssets());
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    // ==================== ERC-4626: Limits ====================

    function maxDeposit(address) public pure returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public pure returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        return convertToAssets(balanceOf[owner]);
    }

    function maxRedeem(address owner) public view returns (uint256) {
        return balanceOf[owner];
    }

    // ==================== ERC-20 Functions ====================

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert InvalidReceiver();

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();

        balanceOf[from] -= amount;
        totalSupply -= amount;

        emit Transfer(from, address(0), amount);
    }

    function _divRoundUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x + y - 1) / y;
    }
}
