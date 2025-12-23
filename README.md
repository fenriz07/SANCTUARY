# 🏛️ SANCTUARY

> **Your USDC Sanctuary. Protected. Growing. Always.**

Sanctuary es un vault DeFi de stablecoins en Base Network que representa un refugio financiero seguro y confiable para usuarios que buscan generar yields estables sin volatilidad. Construido con el estándar ERC4626, Sanctuary automatiza la generación de rendimientos a través de estrategias auditadas y transparentes.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-orange.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-lightgrey.svg)](https://book.getfoundry.sh/)
[![Base Network](https://img.shields.io/badge/Network-Base-blue.svg)](https://base.org/)

---

## ⚠️ Disclaimer

**Este proyecto es educativo y está en fase de desarrollo activo.**

- ❌ No ha sido auditado profesionalmente
- ❌ No recomendado para fondos reales en mainnet
- ⚠️ Úsalo bajo tu propio riesgo
- 🧪 Actualmente en testnet para pruebas

**Siempre realiza auditorías exhaustivas antes de desplegar a producción con fondos reales.**

---

## ✨ Características

### 🛡️ Seguridad Primero
- **ERC4626 Standard**: Implementación completa del estándar de vaults tokenizados
- **OpenZeppelin v5.0+**: Contratos auditados y battle-tested
- **Reentrancy Protection**: Guards contra ataques de reentrada
- **Pausable**: Control de emergencia para pausar operaciones
- **Access Control**: Permisos granulares con Ownable

### 🎯 Simplicidad Radical
- **Deposit & Earn**: Deposita USDC, recibe shares, gana yields automáticamente
- **Una Estrategia, Bien Hecha**: Foco en Aave V3 para estabilidad
- **Gas Eficiente**: Optimizado para Base L2 (transacciones de centavos)

### 📊 Transparencia Total
- **Open Source**: Código completamente público y auditable
- **Fees Claros**: 10% performance fee, 1% management fee anual
- **Métricas en Tiempo Real**: TVL, APY, Share Price visibles

### ⚡ Base Network Benefits
- **Transacciones Baratas**: L2 de Ethereum (~$0.0001 por depósito)
- **Rápido**: Bloques cada ~2 segundos
- **Seguro**: Heredado de Ethereum mainnet
- **Ecosistema Coinbase**: Integración con el ecosistema Base

---

## 🏗️ Arquitectura

```
Usuario → deposit(USDC) → VaultToken (ERC4626)
                            ↓
                     Mint vault shares
                            ↓
                     Strategy.invest()
                            ↓
                     Aave V3.supply()
                            ↓
                     Genera yield automático
                            ↓
                     harvest() (periódico)
                            ↓
                     Cobra performance fee
                            ↓
                     Usuario puede withdraw() en cualquier momento
```

### Contratos Principales

- **VaultToken.sol**: Contrato principal ERC4626 que gestiona depósitos, retiros y shares
- **AaveStrategy.sol**: *(En desarrollo)* Estrategia de lending en Aave V3
- **Interfaces/**: Interfaces para estrategias y protocolos externos

---

## 🚀 Quick Start

### Prerequisitos

- [Foundry](https://book.getfoundry.sh/getting-started/installation) instalado
- [Git](https://git-scm.com/) instalado
- Conocimientos básicos de Solidity y DeFi

### Instalación

```bash
# Clonar el repositorio
git clone https://github.com/tu-usuario/sanctuary-vault.git
cd sanctuary-vault

# Instalar dependencias
forge install

# Compilar contratos
forge build

# Ejecutar tests
forge test

# Ver coverage
forge coverage

# Generar reporte de gas
forge test --gas-report
```

### Configuración

```bash
# Copiar archivo de ejemplo
cp .env.example .env

# Editar .env con tus variables (NUNCA subir este archivo a Git)
# - PRIVATE_KEY
# - BASE_SEPOLIA_RPC_URL
# - BASESCAN_API_KEY
```

---

## 🧪 Testing

El proyecto incluye una suite completa de tests:

```bash
# Tests básicos
forge test

# Tests con verbosidad (ver errores)
forge test -vv

# Tests con máxima verbosidad (ver traces)
forge test -vvvv

# Fuzzing exhaustivo (10,000 iteraciones)
forge test --fuzz-runs 10000

# Test específico
forge test --match-test testDeposit -vvv
```

### Cobertura Actual

- ✅ **18 tests pasando** (100%)
- ✅ Tests de depósito y retiro
- ✅ Tests de edge cases
- ✅ Tests de seguridad (pausable, access control)
- ✅ Tests de ERC4626 compliance
- ✅ Fuzzing tests (256 runs por defecto)

---

## 📖 Uso Básico

### Para Usuarios

```solidity
// 1. Aprobar el vault para usar tu USDC
IERC20(USDC).approve(vaultAddress, amount);

// 2. Depositar USDC y recibir shares
uint256 shares = vault.deposit(amount, msg.sender);

// 3. Tus shares ganan yield automáticamente
// El precio por share aumenta con el tiempo

// 4. Retirar cuando quieras
uint256 assets = vault.withdraw(shares, msg.sender, msg.sender);
```

### Para Desarrolladores

```bash
# Deploy local (Anvil)
anvil
forge script script/Deploy.s.sol --fork-url http://localhost:8545 --broadcast

# Deploy a Base Sepolia
forge script script/Deploy.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify

# Interactuar con el contrato
cast call <vault-address> "totalAssets()" --rpc-url $BASE_SEPOLIA_RPC_URL
```

---

## 💰 Modelo Económico

| Parámetro | Valor | Notas |
|-----------|-------|-------|
| **Performance Fee** | 10% | Solo sobre ganancias generadas |
| **Management Fee** | 1% anual | Sobre TVL total |
| **Withdrawal Fee** | 0% | Sin penalización por retiro |
| **Min Deposit** | 0.01 USDC | Configurable |
| **Max TVL** | 1,000,000 USDC | Límite inicial de seguridad |

---

## 🗺️ Roadmap

### ✅ Fase 1: MVP Smart Contracts (Actual)
- [x] Estructura del proyecto Foundry
- [x] VaultToken.sol con ERC4626
- [x] Suite completa de tests
- [x] Documentación técnica
- [ ] AaveStrategy.sol
- [ ] Deploy a Base Sepolia testnet

### 🔄 Fase 2: Frontend (Próximo)
- [ ] Setup Next.js + wagmi + RainbowKit
- [ ] Componentes Deposit/Withdraw
- [ ] Dashboard con métricas (TVL, APY, balance)
- [ ] Integración con contratos en testnet

### 🔮 Fase 3: Producción (Futuro)
- [ ] Auditoría de seguridad profesional
- [ ] Bug bounty program
- [ ] Deploy a Base mainnet
- [ ] Multi-estrategia y optimización

---

## 🔐 Seguridad

### Prácticas Implementadas

- ✅ **ReentrancyGuard**: Protección contra ataques de reentrada
- ✅ **Pausable**: Emergency stop mechanism
- ✅ **Ownable**: Control de acceso a funciones admin
- ✅ **Input Validation**: Validación exhaustiva de parámetros
- ✅ **Custom Errors**: Gas-efficient error handling
- ✅ **Limits**: maxTotalAssets, minDepositAmount

### Recomendaciones

Si planeas usar este código en producción:

1. **Auditoría Profesional**: Contrata una firma especializada
2. **Bug Bounty**: Implementa un programa de recompensas
3. **Testnet Primero**: Prueba exhaustivamente en testnet
4. **TVL Limitado**: Comienza con cap bajo
5. **Monitoring**: Implementa alertas y monitoreo 24/7
6. **Multisig**: Usa multisig wallet para funciones admin

---

## 📚 Documentación

- **[Guía de Inicio](./docs/GUIA_INICIO.md)**: Tutorial paso a paso para comenzar
- **[Arquitectura](./docs/ARQUITECTURA.md)**: Diseño del sistema y diagramas
- **[Especificación Técnica](./docs/ESPECIFICACION_TECNICA.md)**: Detalles de implementación
- **[Casos de Uso](./docs/CASOS_DE_USO.md)**: Ejemplos prácticos y flujos
- **[Identidad de Marca](./docs/IDENTIDAD_MARCA.md)**: Guía de marca y comunicación

---

## 🛠️ Stack Tecnológico

### Smart Contracts
- **Solidity**: ^0.8.20
- **Foundry**: Framework de desarrollo y testing
- **OpenZeppelin**: v5.0.1 (Contracts auditados)
- **ERC4626**: Tokenized Vault Standard

### Blockchain
- **Network**: Base (Ethereum Layer 2)
- **Mainnet**: Chain ID 8453
- **Testnet**: Base Sepolia (Chain ID 84532)

### DeFi Integrations
- **Aave V3**: Protocolo de lending principal
- **USDC**: Asset principal (0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913)

### Frontend (Próximamente)
- Next.js 14+, TypeScript, viem, wagmi, RainbowKit, TailwindCSS

---

## 🤝 Contribuir

¡Las contribuciones son bienvenidas! Este es un proyecto educativo y open source.

### Cómo Contribuir

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feat/amazing-feature`)
3. Commit tus cambios (`git commit -m 'feat: add amazing feature'`)
4. Push a la rama (`git push origin feat/amazing-feature`)
5. Abre un Pull Request

### Guía de Estilo

- **Commits**: Seguir [Conventional Commits](https://www.conventionalcommits.org/)
  - `feat:` nuevas features
  - `fix:` corrección de bugs
  - `docs:` cambios en documentación
  - `test:` añadir o modificar tests
  - `refactor:` refactorización de código

- **Código**: Seguir [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)

---



## 📄 Licencia

Este proyecto está bajo la licencia MIT - ver el archivo [LICENSE](./LICENSE) para más detalles.

```
MIT License - Uso educativo

Este software se proporciona con fines educativos únicamente.
Los smart contracts manejan fondos reales en blockchain y pueden 
contener bugs o vulnerabilidades.

Usa bajo tu propio riesgo. Los autores no son responsables de 
pérdidas financieras o daños resultantes del uso de este software.
```

---

## 🙏 Agradecimientos

- **OpenZeppelin**: Por los contratos seguros y auditados
- **Foundry**: Por el mejor toolkit de desarrollo para Ethereum
- **Base**: Por proporcionar un L2 rápido y accesible
- **Aave**: Por el protocolo de lending líder en DeFi
- **Comunidad DeFi**: Por la inspiración y mejores prácticas

### Referencias e Inspiración

- [ERC4626 Standard](https://eips.ethereum.org/EIPS/eip-4626)
- [YO Protocol](https://docs.yo.xyz)
- [Yearn Finance](https://docs.yearn.fi/)
- [Aave V3 Docs](https://docs.aave.com/developers/)

---

## 📊 Estado del Proyecto

**Última actualización**: Diciembre 2025  
**Estado**: 🟡 En Desarrollo Activo (MVP)  
**Fase**: Smart Contracts Core (60% completo)

**Siguiente hito**: Deploy a Base Sepolia testnet

---

<p align="center">
  <strong>🏛️ Find Peace in DeFi</strong><br>
  <em>Sanctuary - Where USDC Finds Safety and Growth</em>
</p>

<p align="center">
  Construido con ❤️ para la comunidad DeFi
</p>
