// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockAutoPool
 * @notice Mock de Auto Finance baseUSD para testing en testnet
 * @dev Implementa ERC4626 con yields simulados
 * 
 * SOLO PARA TESTNET - NO USAR EN MAINNET
 */
contract MockAutoPool is ERC4626, Ownable {
    
    uint256 public apy = 882; // 8.82% APY simulado
    uint256 public lastUpdate;
    
    constructor(
        address _asset,
        string memory _name,
        string memory _symbol
    ) 
        ERC4626(IERC20(_asset))
        ERC20(_name, _symbol) 
        Ownable(msg.sender)
    {
        lastUpdate = block.timestamp;
    }
    
    /**
     * @notice Override deposit para simular yields
     */
    function deposit(uint256 assets, address receiver) 
        public 
        override 
        returns (uint256) 
    {
        _accrueYields();
        return super.deposit(assets, receiver);
    }
    
    /**
     * @notice Override withdraw para simular yields
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        returns (uint256)
    {
        _accrueYields();
        return super.withdraw(assets, receiver, owner);
    }
    
    /**
     * @notice Override redeem para simular yields
     */
    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        returns (uint256)
    {
        _accrueYields();
        return super.redeem(shares, receiver, owner);
    }
    
    /**
     * @notice Simula acumulación de yields
     */
    function _accrueYields() internal {
        uint256 timeElapsed = block.timestamp - lastUpdate;
        if (timeElapsed > 0 && totalAssets() > 0) {
            // Calcular yields: APY * tiempo transcurrido
            uint256 currentAssets = totalAssets();
            uint256 yield = (currentAssets * apy * timeElapsed) / (10000 * 365 days);
            
            if (yield > 0) {
                // Mintear shares al contrato para simular yields
                _mint(address(this), convertToShares(yield));
            }
            
            lastUpdate = block.timestamp;
        }
    }
    
    /**
     * @notice Función para simular APY (solo owner)
     */
    function updateAPY(uint256 _apy) external onlyOwner {
        require(_apy <= 5000, "APY too high"); // Max 50%
        apy = _apy;
    }
    
    /**
     * @notice Mock de getPoolAPY para compatibilidad
     */
    function getPoolAPY() external view returns (uint256) {
        return apy;
    }
    
    /**
     * @notice Mock de totalIdle
     */
    function totalIdle() external view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }
    
    /**
     * @notice Mock de lastRebalanceTimestamp
     */
    function lastRebalanceTimestamp() external view returns (uint256) {
        return lastUpdate;
    }
}

