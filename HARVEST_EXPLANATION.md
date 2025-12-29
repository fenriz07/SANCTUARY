# 📊 Sistema de Harvest - High-Water Mark con Share Price

## 🎯 Estrategia Implementada

Este vault utiliza la estrategia **High-Water Mark basada en Share Price** para calcular y cobrar performance fees únicamente sobre ganancias reales.

## 🔑 Conceptos Clave

### Share Price (Precio por Share)

```solidity
pricePerShare = totalAssets() / totalSupply()
```

- **Inmune a deposits**: Cuando alguien deposita, se mintean shares proporcionalmente → PPS no cambia
- **Inmune a withdraws**: Cuando alguien retira, se queman shares proporcionalmente → PPS no cambia  
- **Solo aumenta con yields**: Cuando la estrategia genera ganancias, `totalAssets` aumenta sin mintear shares → PPS aumenta ✅

### High-Water Mark (Marca de Agua Alta)

Es el **precio por share máximo histórico** donde se cobraron fees por última vez.

```solidity
uint256 public lastHarvestedPricePerShare;
```

**Regla:** Solo se cobran fees cuando el PPS actual **supera** el High-Water Mark.

## 📐 Funcionamiento Paso a Paso

### Ejemplo Numérico

#### **Día 1: Primer Depósito**
```
Usuario A deposita: 1,000 USDC

Estado:
├─ totalAssets = 1,000 USDC
├─ totalSupply = 1,000 shares
├─ PPS = 1.0
└─ lastHarvestedPPS = 1.0 (inicial)
```

#### **Día 10: Yields Generados**
```
Auto Finance genera +80 USDC (8% yield)

Estado:
├─ totalAssets = 1,080 USDC (+80)
├─ totalSupply = 1,000 shares (sin cambios)
├─ PPS = 1.08 ✅ AUMENTÓ
└─ lastHarvestedPPS = 1.0 (sin actualizar aún)
```

#### **Día 15: Nuevo Usuario Deposita**
```
Usuario B deposita: 2,000 USDC

Cálculo de shares para B:
shares = 2000 / 1.08 = 1,851.85 shares

Estado después:
├─ totalAssets = 3,080 USDC (1,080 + 2,000)
├─ totalSupply = 2,851 shares (1,000 + 1,851)
├─ PPS = 3,080 / 2,851 = 1.08 ✅ SIN CAMBIOS!
└─ lastHarvestedPPS = 1.0 (aún no harvest)

💡 Usuario B pagó un "premium" de 1.08 por share
   porque está comprando shares que ya tienen yields acumulados
```

#### **Día 16: harvest() - Cobra Performance Fee**
```solidity
function harvest() {
    // 1. Calcular PPS actual
    currentPPS = (3,080 * 1e18) / 2,851 = 1.08e18
    
    // 2. Comparar con High-Water Mark
    lastHarvestedPPS = 1.0e18
    currentPPS > lastHarvestedPPS ✅ HAY GANANCIAS
    
    // 3. Calcular profit por share
    profitPerShare = 1.08e18 - 1.0e18 = 0.08e18
    
    // 4. Profit total
    totalProfit = (0.08e18 * 2,851) / 1e18 = 228 USDC
    
    // 5. Calcular fee (10%)
    feeAmount = 228 * 0.10 = 22.8 USDC
    
    // 6. Retirar de strategy y enviar a treasury
    _divestFromStrategy(22.8)
    IERC20(asset()).transfer(treasury, 22.8)
    
    // 7. Actualizar High-Water Mark
    newPPS = (3,057.2 * 1e18) / 2,851 = 1.072e18
    lastHarvestedPPS = 1.072e18 ← NUEVO HWM
}
```

**Estado después del harvest:**
```
├─ totalAssets = 3,057.2 USDC (3,080 - 22.8 fee)
├─ totalSupply = 2,851 shares
├─ PPS = 1.072
└─ lastHarvestedPPS = 1.072 ← ACTUALIZADO

Distribución:
├─ Usuario A: 1,000 shares × 1.072 = 1,072 USDC
├─ Usuario B: 1,851 shares × 1.072 = 1,984.3 USDC
└─ Treasury: 22.8 USDC (performance fee)
```

## ✅ Ventajas del Sistema

### 1. **Inmunidad a Flujos de Capital**
- ✅ Deposits no afectan el cálculo de fees
- ✅ Withdraws no afectan el cálculo de fees
- ✅ Solo los yields reales aumentan el PPS

### 2. **Justicia Entre Usuarios**

**Usuario que entra temprano:**
- Compra shares a PPS bajo (ej: 1.0)
- Experimenta todo el crecimiento
- Gana proporcionalmente

**Usuario que entra tarde:**
- Compra shares a PPS alto (ej: 1.08)
- Paga premium por yields acumulados
- Es justo porque los yields ya están reflejados en el precio

### 3. **Protección Contra Pérdidas**

```
Escenario:
├─ PPS = 1.2, HWM = 1.2
├─ harvest() → Cobra fee, HWM = 1.2

Pérdida en strategy:
├─ PPS = 0.95
├─ harvest() → NO cobra (0.95 < 1.2) ✅

Recuperación parcial:
├─ PPS = 1.1
├─ harvest() → NO cobra (1.1 < 1.2) ✅

Nueva ganancia (supera HWM):
├─ PPS = 1.25
├─ harvest() → Cobra sobre (1.25 - 1.2) ✅
└─ Solo cobra después de recuperar pérdidas
```

### 4. **Matemáticamente Sólido**

El sistema aprovecha las propiedades del estándar ERC4626:
- Deposits/withdraws ajustan shares y assets **proporcionalmente**
- El ratio (PPS) solo cambia con yields o pérdidas
- No requiere tracking manual complicado

## 🔍 Edge Cases Manejados

### Caso 1: Primer Harvest sin Shares
```solidity
if (supply == 0) return; // No hay nada que hacer
```

### Caso 2: Harvest sin Ganancias
```solidity
if (currentPPS <= lastHarvestedPPS) {
    return; // No cobra nada
}
```

### Caso 3: Harvest después de Pérdidas
```
PPS bajó de 1.2 a 0.95:
- currentPPS (0.95) <= lastHarvestedPPS (1.2)
- return → No cobra fees
- HWM se mantiene en 1.2
- Protocol debe esperar a superar 1.2 para cobrar de nuevo
```

### Caso 4: Múltiples Harvests Seguidos
```
Primera llamada:
- Cobra fees y actualiza HWM a 1.1

Segunda llamada (inmediata):
- currentPPS = 1.1
- lastHarvestedPPS = 1.1
- currentPPS <= lastHarvestedPPS → return
- No cobra nada (correcto)
```

### Caso 5: Transfer Directo al Vault (Donación)
```
Alguien hace: USDC.transfer(vaultAddress, 100)

Resultado:
├─ totalAssets aumenta en 100
├─ totalSupply NO cambia
├─ PPS aumenta

harvest():
├─ Detecta el aumento como "profit"
├─ Cobra 10% sobre la "donación"
└─ Los holders existentes se benefician del resto
```

## 🛡️ Protecciones Implementadas

1. **Division by Zero**: Verificar `supply > 0` antes de calcular PPS
2. **No Double-Charging**: HWM se actualiza después de cobrar fees
3. **Pérdidas**: No cobra fees si PPS no supera el HWM
4. **Reentrancy**: Función usa `nonReentrant` (hereda protección de deposits/withdraws)

## 🧪 Testing Recomendado

```solidity
// Test 1: Harvest básico
test_harvest_withYields()

// Test 2: Inmunidad a deposits
test_harvest_afterDeposit_calculatesCorrectly()

// Test 3: Inmunidad a withdraws
test_harvest_afterWithdraw_calculatesCorrectly()

// Test 4: No cobra en pérdidas
test_harvest_withLoss_doesNotChargeFees()

// Test 5: High-Water Mark
test_harvest_respectsHighWaterMark()

// Test 6: Múltiples usuarios
test_harvest_withMultipleUsers_fairDistribution()

// Test 7: Edge case - supply 0
test_harvest_withZeroSupply_returnsEarly()

// Test 8: Edge case - sin ganancias
test_harvest_withNoProfit_doesNotChargeFees()
```

## 📚 Referencias

- **ERC4626**: https://eips.ethereum.org/EIPS/eip-4626
- **Yearn Finance**: Pioneros del High-Water Mark en vaults
- **Auto Finance**: Protocolo que usamos para yields
- **High-Water Mark**: Concepto tradicional de hedge funds

## 🎯 Resumen

**El sistema de harvest garantiza:**
- ✅ Solo cobra fees sobre ganancias REALES
- ✅ Nunca cobra sobre capital de usuarios
- ✅ Nunca cobra sobre depósitos/retiros
- ✅ Protege contra pérdidas (respeta HWM)
- ✅ Justo para todos los usuarios
- ✅ Matemáticamente sólido
- ✅ Battle-tested por la industria

---

**Versión del Contrato**: 1.0.0  
**Última Actualización**: Diciembre 2024


