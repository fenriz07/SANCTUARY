#!/bin/bash

# ======================================
# 🚀 Setup Local Development Environment
# ======================================

set -e

echo "╔════════════════════════════════════════════════════════╗"
echo "║     🛠️  Vault DeFi - Local Development Setup         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ======================================
# 1. Verificar Foundry
# ======================================
echo "📦 Step 1: Checking Foundry installation..."
if ! command -v forge &> /dev/null; then
    echo -e "${RED}❌ Foundry not found!${NC}"
    echo "Install with: curl -L https://foundry.paradigm.xyz | bash"
    exit 1
fi
echo -e "${GREEN}✅ Foundry installed${NC}"
echo ""

# ======================================
# 2. Compilar contratos
# ======================================
echo "🔨 Step 2: Building contracts..."
forge build
echo -e "${GREEN}✅ Contracts built${NC}"
echo ""

# ======================================
# 3. Iniciar Anvil en background
# ======================================
echo "⚡ Step 3: Starting local node (Anvil)..."

# Matar proceso anterior si existe
pkill -f anvil || true

# Iniciar anvil en background con fork de Base Mainnet
anvil --fork-url https://mainnet.base.org \
      --fork-block-number 10000000 \
      --chain-id 31337 \
      --port 8545 \
      > anvil.log 2>&1 &

ANVIL_PID=$!
echo "Anvil PID: $ANVIL_PID"
echo $ANVIL_PID > .anvil.pid

# Esperar a que anvil inicie
sleep 3

echo -e "${GREEN}✅ Anvil running on http://localhost:8545${NC}"
echo ""

# ======================================
# 4. Usar cuenta pre-fondeada de Anvil
# ======================================
echo "🔑 Step 4: Setting up wallet..."

# Anvil wallet #0 (pre-fondeada con 10,000 ETH)
ANVIL_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
ANVIL_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

# Crear .env.local si no existe
if [ ! -f .env.local ]; then
    cat > .env.local << EOF
# Local Development Environment
PRIVATE_KEY=$ANVIL_PRIVATE_KEY
ADDRESS=$ANVIL_ADDRESS

# Local RPC
ANVIL_RPC_URL=http://localhost:8545

# Contracts (will be filled after deploy)
USDC_ADDRESS=
VAULT_PROXY=
VAULT_IMPLEMENTATION=
EOF
    echo -e "${GREEN}✅ Created .env.local${NC}"
else
    echo -e "${YELLOW}⚠️  .env.local already exists${NC}"
fi

echo "Address: $ANVIL_ADDRESS"
echo "Balance: 10,000 ETH"
echo ""

# ======================================
# 5. Deploy Mock USDC
# ======================================
echo "💵 Step 5: Deploying Mock USDC..."

forge script script/DeployMockUSDC.s.sol:DeployMockUSDC \
    --rpc-url http://localhost:8545 \
    --private-key $ANVIL_PRIVATE_KEY \
    --broadcast \
    -vv

# Extraer dirección del USDC (del output de forge)
USDC_ADDRESS=$(forge script script/DeployMockUSDC.s.sol:DeployMockUSDC \
    --rpc-url http://localhost:8545 \
    --private-key $ANVIL_PRIVATE_KEY \
    2>/dev/null | grep "Mock USDC Address:" | awk '{print $5}')

if [ -z "$USDC_ADDRESS" ]; then
    echo -e "${RED}❌ Failed to extract USDC address${NC}"
    USDC_ADDRESS="<check logs>"
fi

echo -e "${GREEN}✅ Mock USDC deployed at: $USDC_ADDRESS${NC}"
echo ""

# Actualizar .env.local
sed -i "s|USDC_ADDRESS=.*|USDC_ADDRESS=$USDC_ADDRESS|" .env.local

# ======================================
# 6. Verificar balances
# ======================================
echo "💰 Step 6: Checking balances..."

ETH_BALANCE=$(cast balance $ANVIL_ADDRESS --rpc-url http://localhost:8545 --ether)
echo "ETH Balance: $ETH_BALANCE ETH"

if [ "$USDC_ADDRESS" != "<check logs>" ]; then
    USDC_BALANCE=$(cast call $USDC_ADDRESS "balanceOf(address)" $ANVIL_ADDRESS --rpc-url http://localhost:8545)
    USDC_READABLE=$(cast to-dec $USDC_BALANCE)
    echo "USDC Balance: $((USDC_READABLE / 1000000)) USDC"
fi
echo ""

# ======================================
# 7. Instrucciones
# ======================================
echo "╔════════════════════════════════════════════════════════╗"
echo "║              ✅ Setup Complete!                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "🎯 Your local development environment is ready!"
echo ""
echo "📍 RPC URL: http://localhost:8545"
echo "📍 Chain ID: 31337 (Anvil)"
echo "🔑 Address: $ANVIL_ADDRESS"
echo "💰 ETH Balance: 10,000 ETH"
echo "💵 USDC Address: $USDC_ADDRESS"
echo ""
echo "🔧 Next commands:"
echo ""
echo "  # Deploy vault to local node"
echo "  forge script script/DeployVaultProxy.s.sol \\"
echo "    --rpc-url http://localhost:8545 \\"
echo "    --private-key \$PRIVATE_KEY \\"
echo "    --broadcast"
echo ""
echo "  # Run tests against local fork"
echo "  forge test --fork-url http://localhost:8545 -vvv"
echo ""
echo "  # Check balances"
echo "  cast balance $ANVIL_ADDRESS --rpc-url http://localhost:8545 --ether"
echo ""
echo "  # Stop Anvil"
echo "  ./script/StopLocal.sh"
echo ""
echo "📝 Configuration saved in: .env.local"
echo "📋 Anvil log: anvil.log"
echo "🛑 To stop: kill $ANVIL_PID or ./script/StopLocal.sh"
echo ""

