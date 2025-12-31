// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MyVaultERC4626} from "./MyVaultERC4626.sol";
import {IERC20} from "./interfaces/IERC20.sol";

contract VaultWithStrategy is MyVaultERC4626 {
    address public strategy;
    address public governance;

    uint256 public constant MAX_BPS = 10000;
    uint256 public strategyDebtRatio;

    event StrategyUpdated(
        address indexed oldStrategy,
        address indexed newStrategy
    );
    event DebtRatioUpdated(uint256 oldRatio, uint256 newRation);
    event Harvested(uint256 profit, uint256 loss);

    error OnlyGovernance();
    error InvalidDebtRatio();
    error StrategyFailed();

    modifier onlyGovernance() {
        if (msg.sender != governance) revert OnlyGovernance();
        _;
    }

    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol
    ) MyVaultERC4626(_asset, _name, _symbol) {
        governance = msg.sender;
        strategyDebtRatio = 9000;
    }

    function setStrategy(address _strategy) external onlyGovernance {
        address oldStrategy = strategy;

        if (oldStrategy != address(0)) {
            _withdrawFromStrategy(type(uint256).max);
        }

        strategy = _strategy;

        emit StrategyUpdated(oldStrategy, _strategy);
    }

    function setDebtRatio(uint256 _debtRatio) external onlyGovernance {
        if (_debtRatio > MAX_BPS) revert InvalidDebtRatio();

        uint256 oldRatio = strategyDebtRatio;
        strategyDebtRatio = _debtRatio;

        emit DebtRatioUpdated(oldRatio, _debtRatio);

        _rebalance();
    }

    function harvest() external returns (uint256 profit, uint256 loss) {
        if (strategy == address(0)) return (0, 0);

        uint256 beforeBalance = asset.balanceOf(address(this));

        (bool success, ) = strategy.call(abi.encodeWithSignature("harvest()"));

        if (!success) revert StrategyFailed();

        uint256 afterBalance = asset.balanceOf(address(this));

        if (afterBalance > beforeBalance) {
            profit = afterBalance - beforeBalance;
        } else {
            loss = beforeBalance - afterBalance;
        }

        emit Harvested(profit, loss);

        return (profit, loss);
    }

    function totalAssets() public view override returns (uint256) {
        uint256 valutBalance = asset.balanceOf(address(this));
        uint256 strategyBalance = _getStrategyBalance();

        return valutBalance + strategyBalance;
    }

    function _deployToStrategy(uint256 amount) internal {
        if (strategy == address(0) || amount == 0) return;

        asset.transfer(strategy, amount);

        (bool success, ) = strategy.call(
            abi.encodeWithSignature("deposit(uint256)", amount)
        );

        if (!success) revert StrategyFailed();
    }

    function _withdrawFromStrategy(uint256 amount) internal returns (uint256) {
        if (strategy == address(0)) return 0;

        uint256 beforeBalance = asset.balanceOf(address(this));

        (bool success, ) = strategy.call(
            abi.encodeWithSignature("withdraw(uint256)", amount)
        );

        if (!success) revert StrategyFailed();

        uint256 afterBalance = asset.balanceOf(address(this));

        return afterBalance - beforeBalance;
    }

    function _getStrategyBalance() internal view returns (uint256) {
        if (strategy == address(0)) return 0;

        (bool success, bytes memory data) = strategy.staticcall(
            abi.encodeWithSignature("balanceOf()")
        );

        if (!success) revert StrategyFailed();

        return abi.decode(data, (uint256));
    }

    function _rebalance() internal {
        uint256 totalAssets_ = totalAssets();
        uint256 targetDeployed = (totalAssets_ * strategyDebtRatio) / MAX_BPS;
        uint256 currentDeployed = _getStrategyBalance();

        if (targetDeployed > currentDeployed) {
            // Deploy more
            uint256 toDeploye = targetDeployed - currentDeployed;
            uint256 available = asset.balanceOf(address(this));

            if (available >= toDeploye) {
                _deployToStrategy(toDeploye);
            }
        } else if (targetDeployed < currentDeployed) {
            // Withdraw excess
            uint256 toWithdraw = currentDeployed - targetDeployed;
            _withdrawFromStrategy(toWithdraw);
        }
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public override returns (uint256 shares) {
        shares = super.deposit(assets, receiver);

        _rebalance();

        return shares;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256 shares) {
        uint256 vaultBalance = asset.balanceOf(address(this));

        if (vaultBalance < assets) {
            uint256 needed = assets - vaultBalance;
            _withdrawFromStrategy(needed);
        }

        return super.withdraw(assets, receiver, owner);
    }

    function transferGovernance(address newGovernance) external onlyGovernance {
        governance = newGovernance;
    }

    function emergencyWithdraw() external onlyGovernance {
        _withdrawFromStrategy(type(uint256).max);
    }
}
