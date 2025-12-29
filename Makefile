# ======================================
# 🚀 Vault DeFi - Makefile
# ======================================

# Variables de configuración
-include .env

.PHONY: help install test clean build

# ======================================
# 📋 HELP - Mostrar todos los comandos
# ======================================
help:
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║          🚀 Vault DeFi - Comandos Disponibles         ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📦 Setup:"
	@echo "  make install          - Instalar dependencias"
	@echo "  make build            - Compilar contratos"
	@echo "  make clean            - Limpiar archivos compilados"
	@echo ""
	@echo "🧪 Testing:"
	@echo "  make test             - Ejecutar todos los tests"
	@echo "  make test-v           - Tests con output verbose"
	@echo "  make test-gas         - Reporte de gas"
	@echo "  make coverage         - Análisis de cobertura"
	@echo ""
	@echo "🌐 Deploy Testnet (Base Sepolia):"
	@echo "  make deploy-testnet   - Deploy completo a testnet"
	@echo "  make verify-testnet   - Verificar contratos en testnet"
	@echo ""
	@echo "🚀 Deploy Mainnet (Base):"
	@echo "  make deploy-mainnet           - Deploy VaultToken a mainnet"
	@echo "  make deploy-strategy-mainnet  - Deploy AutoFinanceStrategy a mainnet"
	@echo "  make connect-strategy-mainnet - Conectar strategy al vault"
	@echo "  make verify-mainnet           - Verificar contratos en mainnet"
	@echo ""
	@echo "🔍 Inspección:"
	@echo "  make status-testnet   - Ver estado del vault en testnet"
	@echo "  make status-mainnet   - Ver estado del vault en mainnet"
	@echo "  make storage          - Inspeccionar storage del vault"
	@echo ""
	@echo "💰 Operaciones de Usuario (Testnet):"
	@echo "  make deposit-testnet  - Depositar USDC en el vault"
	@echo "  make withdraw-testnet - Retirar USDC del vault"
	@echo ""
	@echo "💎 Operaciones de Usuario (Mainnet):"
	@echo "  make approve-usdc-mainnet - Aprobar USDC para el vault"
	@echo "  make deposit-mainnet      - Depositar USDC en el vault"
	@echo "  make withdraw-mainnet     - Retirar USDC del vault"
	@echo ""
	@echo "🔧 Comandos Admin (Mainnet):"
	@echo "  make approve-autopool-shares STRATEGY=0x...     - Fix: Aprobar shares del autopool"
	@echo "  make emergency-withdraw-strategy STRATEGY=0x... - Recuperar fondos de estrategia"
	@echo ""
	@echo "🏠 Local Development:"
	@echo "  make setup-local      - Setup Anvil + Mock USDC"
	@echo "  make deploy-local     - Deploy a Anvil local"
	@echo "  make status-local     - Ver estado local"
	@echo "  make balance-local    - Ver balances locales"
	@echo "  make stop-local       - Detener Anvil"
	@echo ""
	@echo "🔧 Utilities:"
	@echo "  make wallet           - Crear nueva wallet"
	@echo "  make balance-testnet  - Ver balance en testnet"
	@echo "  make balance-mainnet  - Ver balance en mainnet"
	@echo "  make lint             - Análisis de código"
	@echo ""

# ======================================
# 📦 SETUP & BUILD
# ======================================

install:
	@echo "📦 Installing dependencies..."
	forge install
	@echo "✅ Dependencies installed!"

build:
	@echo "🔨 Building contracts..."
	forge build
	@echo "✅ Build complete!"

clean:
	@echo "🧹 Cleaning..."
	forge clean
	rm -rf cache out
	@echo "✅ Clean complete!"

# ======================================
# 🧪 TESTING
# ======================================

test:
	@echo "🧪 Running tests..."
	forge test

test-v:
	@echo "🧪 Running tests (verbose)..."
	forge test -vvv

test-gas:
	@echo "⛽ Running gas report..."
	forge test --gas-report

coverage:
	@echo "📊 Running coverage analysis..."
	forge coverage

test-fork-sepolia:
	@echo "🔀 Running fork tests on Base Sepolia..."
	forge test --fork-url $(BASE_SEPOLIA_RPC_URL)

test-fork-mainnet:
	@echo "🔀 Running fork tests on Base Mainnet..."
	forge test --fork-url $(BASE_RPC_URL)

# ======================================
# 🌐 DEPLOY TESTNET (Base Sepolia)
# ======================================

deploy-testnet:
	@echo "🌐 Deploying to Base Sepolia (Testnet)..."
	@echo "📍 Network: Base Sepolia (Chain ID: 84532)"
	@echo "👤 Deployer: $$(cast wallet address --private-key $(PRIVATE_KEY))"
	@echo ""
	@read -p "Continue with deployment? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		forge script script/DeployVaultProxy.s.sol \
			--rpc-url $(BASE_SEPOLIA_RPC_URL) \
			--broadcast \
			--verify \
			-vvvv; \
		echo ""; \
		echo "✅ Deployment complete!"; \
		echo "📝 Save the VAULT_PROXY address for future use"; \
	else \
		echo "❌ Deployment cancelled"; \
	fi

deploy-testnet-dry:
	@echo "🌐 Simulating deployment to Base Sepolia..."
	forge script script/DeployVaultProxy.s.sol \
		--rpc-url $(BASE_SEPOLIA_RPC_URL) \
		-vvvv

verify-testnet:
	@echo "🔍 Verifying contracts on Base Sepolia..."
	@if [ -z "$(VAULT_IMPLEMENTATION)" ]; then \
		echo "❌ Error: VAULT_IMPLEMENTATION not set"; \
		echo "Usage: make verify-testnet VAULT_IMPLEMENTATION=0x..."; \
		exit 1; \
	fi
	forge verify-contract \
		$(VAULT_IMPLEMENTATION) \
		src/VaultToken.sol:VaultToken \
		--chain-id 84532 \
		--watch
	@echo "✅ Verification complete!"

# ======================================
# 🚀 DEPLOY MAINNET (Base)
# ======================================

deploy-mainnet:
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║     ⚠️  MAINNET DEPLOYMENT - REAL FUNDS AT RISK  ⚠️     ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📍 Network: Base Mainnet (Chain ID: 8453)"
	@echo "👤 Deployer: $$(cast wallet address --private-key $(PRIVATE_KEY))"
	@echo "💰 Balance: $$(cast balance --ether $$(cast wallet address --private-key $(PRIVATE_KEY)) --rpc-url $(BASE_RPC_URL)) ETH"
	@echo ""
	@echo "⚠️  CHECKLIST:"
	@echo "  [ ] Tests passing (make test)"
	@echo "  [ ] Coverage > 80% (make coverage)"
	@echo "  [ ] Tested on testnet"
	@echo "  [ ] Code audited"
	@echo "  [ ] Gas costs reviewed"
	@echo "  [ ] Treasury address verified"
	@echo ""
	@read -p "Type 'DEPLOY' to confirm mainnet deployment: " confirm; \
	if [ "$$confirm" = "DEPLOY" ]; then \
		echo "🚀 Starting mainnet deployment..."; \
		forge script script/DeployVaultProxy.s.sol \
			--rpc-url $(BASE_RPC_URL) \
			--broadcast \
			--verify \
			-vvvv; \
		echo ""; \
		echo "✅ MAINNET DEPLOYMENT COMPLETE!"; \
		echo ""; \
		echo "📝 IMPORTANT - Save these addresses:"; \
		echo "   - VAULT_PROXY: (from output above)"; \
		echo "   - VAULT_IMPLEMENTATION: (from output above)"; \
	else \
		echo "❌ Mainnet deployment cancelled"; \
	fi

# 🔄 UPGRADE MAINNET
# ======================================

upgrade-mainnet:
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║       ⚠️  MAINNET UPGRADE - REAL FUNDS AT RISK  ⚠️      ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📍 Network: Base Mainnet (Chain ID: 8453)"
	@echo "👤 Deployer: $$(cast wallet address --private-key $(PRIVATE_KEY))"
	@echo "💰 Balance: $$(cast balance --ether $$(cast wallet address --private-key $(PRIVATE_KEY)) --rpc-url $(BASE_RPC_URL)) ETH"
	@echo ""
	@echo "🔧 This will upgrade the VaultToken implementation"
	@echo "   Proxy: 0x1dba528d6534477de47bcfebfb1f196d433dc7f9"
	@echo ""
	@echo "⚠️  CHECKLIST:"
	@echo "  [ ] Tests passing (make test)"
	@echo "  [ ] New implementation tested"
	@echo "  [ ] Storage layout compatible"
	@echo "  [ ] Emergency plan ready"
	@echo ""
	@read -p "Type 'UPGRADE' to confirm mainnet upgrade: " confirm; \
	if [ "$$confirm" = "UPGRADE" ]; then \
		echo "🔄 Starting mainnet upgrade..."; \
		forge script script/UpgradeVault.s.sol \
			--rpc-url $(BASE_RPC_URL) \
			--broadcast \
			--verify \
			-vvvv; \
		echo ""; \
		echo "✅ MAINNET UPGRADE COMPLETE!"; \
		echo ""; \
		echo "🔍 Test the upgrade:"; \
		echo "   make withdraw-mainnet AMOUNT=0.01 VAULT_PROXY=0x1dba528d6534477de47bcfebfb1f196d433dc7f9"; \
	else \
		echo "❌ Mainnet upgrade cancelled"; \
	fi

upgrade-mainnet-dry:
	@echo "🔄 Simulating mainnet upgrade..."
	forge script script/UpgradeVault.s.sol \
		--rpc-url $(BASE_RPC_URL) \
		-vvvv

deploy-mainnet-dry:
	@echo "🚀 Simulating mainnet deployment..."
	forge script script/DeployVaultProxy.s.sol \
		--rpc-url $(BASE_RPC_URL) \
		-vvvv

verify-mainnet:
	@echo "🔍 Verifying contracts on Base Mainnet..."
	@if [ -z "$(VAULT_IMPLEMENTATION)" ]; then \
		echo "❌ Error: VAULT_IMPLEMENTATION not set"; \
		echo "Usage: make verify-mainnet VAULT_IMPLEMENTATION=0x..."; \
		exit 1; \
	fi
	forge verify-contract \
		$(VAULT_IMPLEMENTATION) \
		src/VaultToken.sol:VaultToken \
		--chain-id 8453 \
		--watch
	@echo "✅ Verification complete!"

deploy-strategy-mainnet:
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║    🎯 DEPLOY AUTO FINANCE STRATEGY TO MAINNET  🎯     ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		echo "Usage: make deploy-strategy-mainnet VAULT_PROXY=0x..."; \
		exit 1; \
	fi
	@echo "📍 Network: Base Mainnet (Chain ID: 8453)"
	@echo "📍 Vault Proxy: $(VAULT_PROXY)"
	@echo "👤 Deployer: $$(cast wallet address --private-key $(PRIVATE_KEY))"
	@echo "💰 Balance: $$(cast balance --ether $$(cast wallet address --private-key $(PRIVATE_KEY)) --rpc-url $(BASE_RPC_URL)) ETH"
	@echo ""
	@echo "📦 Strategy: AutoFinanceStrategy"
	@echo "🎯 Target: Auto Finance baseUSD Autopool"
	@echo "💎 Asset: USDC (0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913)"
	@echo "📊 APY: ~8.82% (variable)"
	@echo ""
	@echo "⚠️  CHECKLIST:"
	@echo "  [ ] Vault deployed successfully"
	@echo "  [ ] Auto Finance pool verified (0x9c6864105AEC23388C89600046213a44C384c831)"
	@echo "  [ ] Strategy tested on fork"
	@echo "  [ ] Code audited"
	@echo ""
	@read -p "Type 'DEPLOY' to confirm strategy deployment: " confirm; \
	if [ "$$confirm" = "DEPLOY" ]; then \
		echo "🚀 Starting strategy deployment..."; \
		VAULT_PROXY=$(VAULT_PROXY) forge script script/DeployAutoFinanceStrategy.s.sol \
			--rpc-url $(BASE_RPC_URL) \
			--broadcast \
			--verify \
			-vvvv; \
		echo ""; \
		echo "✅ STRATEGY DEPLOYMENT COMPLETE!"; \
		echo ""; \
		echo "📝 NEXT STEPS:"; \
		echo "   1. Verify strategy address on BaseScan"; \
		echo "   2. If updateStrategy() failed, call manually from owner"; \
		echo "   3. Test with small deposit (0.01 USDC)"; \
		echo "   4. Monitor APY and strategy performance"; \
		echo "   5. Gradually increase maxTotalAssets"; \
	else \
		echo "❌ Strategy deployment cancelled"; \
	fi

deploy-strategy-mainnet-dry:
	@echo "🎯 Simulating strategy deployment to mainnet..."
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		echo "Usage: make deploy-strategy-mainnet-dry VAULT_PROXY=0x..."; \
		exit 1; \
	fi
	VAULT_PROXY=$(VAULT_PROXY) forge script script/DeployAutoFinanceStrategy.s.sol \
		--rpc-url $(BASE_RPC_URL) \
		-vvvv

connect-strategy-mainnet:
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║      🔗 CONNECT STRATEGY TO VAULT (MAINNET)  🔗       ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		echo "Usage: make connect-strategy-mainnet VAULT_PROXY=0x... STRATEGY=0x..."; \
		exit 1; \
	fi
	@if [ -z "$(STRATEGY)" ]; then \
		echo "❌ Error: STRATEGY not set"; \
		echo "Usage: make connect-strategy-mainnet VAULT_PROXY=0x... STRATEGY=0x..."; \
		exit 1; \
	fi
	@echo "📍 Vault Proxy: $(VAULT_PROXY)"
	@echo "🎯 Strategy: $(STRATEGY)"
	@echo "👤 Sender: $$(cast wallet address --private-key $(PRIVATE_KEY))"
	@echo ""
	@echo "⚠️  This will:"
	@echo "  - Call vault.updateStrategy($(STRATEGY))"
	@echo "  - Requires: You are the owner of the vault"
	@echo ""
	@read -p "Type 'CONNECT' to confirm: " confirm; \
	if [ "$$confirm" = "CONNECT" ]; then \
		echo "🔗 Connecting strategy to vault..."; \
		cast send $(VAULT_PROXY) \
			"updateStrategy(address)" \
			$(STRATEGY) \
			--rpc-url $(BASE_RPC_URL) \
			--private-key $(PRIVATE_KEY); \
		echo ""; \
		echo "✅ Strategy connected!"; \
		echo ""; \
		echo "🔍 Verify with: make status-mainnet VAULT_PROXY=$(VAULT_PROXY)"; \
	else \
		echo "❌ Connection cancelled"; \
	fi

# ======================================
# 🔍 INSPECTION & STATUS
# ======================================

# Alias para status-testnet
info: status-testnet

status-testnet:
	@echo "🔍 Vault Status on Base Sepolia"
	@echo "════════════════════════════════"
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		echo "Usage: make status-testnet VAULT_PROXY=0x..."; \
		exit 1; \
	fi
	@echo "📍 Proxy: $(VAULT_PROXY)"
	@VERSION=$$(cast call $(VAULT_PROXY) "version()" --rpc-url $(BASE_SEPOLIA_RPC_URL) | xargs cast --to-ascii); \
	echo "📊 Version: $$VERSION"
	@OWNER=$$(cast call $(VAULT_PROXY) "owner()" --rpc-url $(BASE_SEPOLIA_RPC_URL)); \
	echo "👤 Owner: $$OWNER"
	@TVL=$$(cast call $(VAULT_PROXY) "totalAssets()" --rpc-url $(BASE_SEPOLIA_RPC_URL) | xargs cast --to-dec); \
	TVL_USDC=$$(echo "scale=2; $$TVL / 1000000" | bc); \
	echo "💰 TVL: $$TVL_USDC USDC ($$TVL raw)"
	@PERF_FEE=$$(cast call $(VAULT_PROXY) "performanceFee()" --rpc-url $(BASE_SEPOLIA_RPC_URL) | xargs cast --to-dec); \
	PERF_PCT=$$(echo "scale=2; $$PERF_FEE / 100" | bc); \
	echo "📈 Performance Fee: $$PERF_PCT% ($$PERF_FEE bps)"
	@MGMT_FEE=$$(cast call $(VAULT_PROXY) "managementFee()" --rpc-url $(BASE_SEPOLIA_RPC_URL) | xargs cast --to-dec); \
	MGMT_PCT=$$(echo "scale=2; $$MGMT_FEE / 100" | bc); \
	echo "📈 Management Fee: $$MGMT_PCT% ($$MGMT_FEE bps)"
	@PAUSED=$$(cast call $(VAULT_PROXY) "paused()" --rpc-url $(BASE_SEPOLIA_RPC_URL)); \
	if [ "$$PAUSED" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then \
		echo "⏸️  Paused: No"; \
	else \
		echo "⏸️  Paused: Yes"; \
	fi
	@echo ""
	@echo "📊 Share Value:"
	@TOTAL_SUPPLY=$$(cast call $(VAULT_PROXY) "totalSupply()" --rpc-url $(BASE_SEPOLIA_RPC_URL) | xargs cast --to-dec); \
	TOTAL_ASSETS=$$(cast call $(VAULT_PROXY) "totalAssets()" --rpc-url $(BASE_SEPOLIA_RPC_URL) | xargs cast --to-dec); \
	if [ $$TOTAL_SUPPLY -gt 0 ]; then \
		SHARE_PRICE=$$(echo "scale=6; $$TOTAL_ASSETS / $$TOTAL_SUPPLY" | bc); \
		if [ "$$(echo "$$SHARE_PRICE" | cut -c1)" = "." ]; then \
			SHARE_PRICE="0$$SHARE_PRICE"; \
		fi; \
		echo "💎 Price per Share: $$SHARE_PRICE USDC"; \
		TOTAL_SUPPLY_HUMAN=$$(echo "scale=6; $$TOTAL_SUPPLY / 1000000" | bc); \
		if [ "$$(echo "$$TOTAL_SUPPLY_HUMAN" | cut -c1)" = "." ]; then \
			TOTAL_SUPPLY_HUMAN="0$$TOTAL_SUPPLY_HUMAN"; \
		fi; \
		echo "📈 Total Supply: $$TOTAL_SUPPLY_HUMAN shares ($$TOTAL_SUPPLY raw)"; \
	else \
		echo "💎 Price per Share: 1.000000 USDC (initial)"; \
		echo "📈 Total Supply: 0 shares (empty vault)"; \
	fi

status-mainnet:
	@echo "🔍 Vault Status on Base Mainnet"
	@echo "════════════════════════════════"
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		echo "Usage: make status-mainnet VAULT_PROXY=0x..."; \
		exit 1; \
	fi
	@echo "📍 Proxy: $(VAULT_PROXY)"
	@VERSION=$$(cast call $(VAULT_PROXY) "version()" --rpc-url $(BASE_RPC_URL) 2>/dev/null | xargs cast --to-ascii 2>/dev/null || echo "N/A"); \
	echo "📊 Version: $$VERSION"
	@OWNER=$$(cast call $(VAULT_PROXY) "owner()" --rpc-url $(BASE_RPC_URL) 2>/dev/null || echo "N/A"); \
	echo "👤 Owner: $$OWNER"
	@STRATEGY=$$(cast call $(VAULT_PROXY) "strategy()" --rpc-url $(BASE_RPC_URL) 2>/dev/null || echo "N/A"); \
	echo "🎯 Strategy: $$STRATEGY"
	@TVL=$$(cast call $(VAULT_PROXY) "totalAssets()" --rpc-url $(BASE_RPC_URL) 2>/dev/null | xargs cast --to-dec 2>/dev/null || echo "0"); \
	if [ "$$TVL" != "0" ] && [ "$$TVL" != "" ]; then \
		TVL_USDC=$$(echo "scale=6; $$TVL / 1000000" | bc 2>/dev/null || echo "0"); \
		echo "💰 TVL: $$TVL_USDC USDC ($$TVL raw)"; \
	else \
		echo "💰 TVL: 0 USDC (0 raw)"; \
	fi
	@PERF_FEE=$$(cast call $(VAULT_PROXY) "performanceFee()" --rpc-url $(BASE_RPC_URL) 2>/dev/null | xargs cast --to-dec 2>/dev/null || echo "0"); \
	PERF_PCT=$$(echo "scale=2; $$PERF_FEE / 100" | bc 2>/dev/null || echo "0"); \
	echo "📈 Performance Fee: $$PERF_PCT% ($$PERF_FEE bps)"
	@MGMT_FEE=$$(cast call $(VAULT_PROXY) "managementFee()" --rpc-url $(BASE_RPC_URL) 2>/dev/null | xargs cast --to-dec 2>/dev/null || echo "0"); \
	MGMT_PCT=$$(echo "scale=2; $$MGMT_FEE / 100" | bc 2>/dev/null || echo "0"); \
	echo "📈 Management Fee: $$MGMT_PCT% ($$MGMT_FEE bps)"
	@PAUSED=$$(cast call $(VAULT_PROXY) "paused()" --rpc-url $(BASE_RPC_URL) 2>/dev/null || echo "0x0000000000000000000000000000000000000000000000000000000000000000"); \
	if [ "$$PAUSED" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then \
		echo "⏸️  Paused: No"; \
	else \
		echo "⏸️  Paused: Yes"; \
	fi
	@echo ""
	@echo "📊 Share Value:"
	@TOTAL_SUPPLY=$$(cast call $(VAULT_PROXY) "totalSupply()" --rpc-url $(BASE_RPC_URL) 2>/dev/null | xargs cast --to-dec 2>/dev/null || echo "0"); \
	TOTAL_ASSETS=$$(cast call $(VAULT_PROXY) "totalAssets()" --rpc-url $(BASE_RPC_URL) 2>/dev/null | xargs cast --to-dec 2>/dev/null || echo "0"); \
	if [ "$$TOTAL_SUPPLY" != "0" ] && [ "$$TOTAL_SUPPLY" != "" ] && [ "$$TOTAL_ASSETS" != "0" ]; then \
		SHARE_PRICE=$$(echo "scale=6; $$TOTAL_ASSETS / $$TOTAL_SUPPLY" | bc 2>/dev/null || echo "1.000000"); \
		if [ "$$(echo "$$SHARE_PRICE" | cut -c1)" = "." ]; then \
			SHARE_PRICE="0$$SHARE_PRICE"; \
		fi; \
		echo "💎 Price per Share: $$SHARE_PRICE USDC"; \
		TOTAL_SUPPLY_HUMAN=$$(echo "scale=6; $$TOTAL_SUPPLY / 1000000" | bc 2>/dev/null || echo "0"); \
		if [ "$$(echo "$$TOTAL_SUPPLY_HUMAN" | cut -c1)" = "." ]; then \
			TOTAL_SUPPLY_HUMAN="0$$TOTAL_SUPPLY_HUMAN"; \
		fi; \
		echo "📈 Total Supply: $$TOTAL_SUPPLY_HUMAN shares ($$TOTAL_SUPPLY raw)"; \
	else \
		echo "💎 Price per Share: 1.000000 USDC (initial)"; \
		echo "📈 Total Supply: 0 shares (empty vault)"; \
	fi

storage:
	@echo "💾 Inspecting Storage Layout"
	@echo "════════════════════════════════"
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		echo "Usage: make storage VAULT_PROXY=0x..."; \
		exit 1; \
	fi
	@echo "Slot 0-9:"
	@for i in 0 1 2 3 4 5 6 7 8 9; do \
		value=$$(cast storage $(VAULT_PROXY) $$i --rpc-url $(BASE_SEPOLIA_RPC_URL)); \
		echo "Slot $$i: $$value"; \
	done

storage-layout:
	@echo "📋 Storage Layout (VaultToken)"
	forge inspect VaultToken storage-layout --pretty

# ======================================
# 🔧 UTILITIES
# ======================================

wallet:
	@echo "🔐 Creating new wallet..."
	@cast wallet new
	@echo ""
	@echo "⚠️  SAVE THESE CREDENTIALS SECURELY!"
	@echo "Add PRIVATE_KEY to your .env file"

balance-testnet:
	@echo "💰 Balance on Base Sepolia"
	@echo "════════════════════════════════"
	@if [ -z "$(ADDRESS)" ]; then \
		ADDRESS=$$(cast wallet address --private-key $(PRIVATE_KEY)); \
	else \
		ADDRESS=$(ADDRESS); \
	fi; \
	echo "Address: $$ADDRESS"; \
	echo "ETH: $$(cast balance --ether $$ADDRESS --rpc-url $(BASE_SEPOLIA_RPC_URL))"; \
	echo ""; \
	echo "Need testnet ETH? Visit:"; \
	echo "https://cloud.google.com/application/web3/faucet/ethereum/sepolia"

balance-mainnet:
	@echo "💰 Balance on Base Mainnet"
	@echo "════════════════════════════════"
	@if [ -z "$(ADDRESS)" ]; then \
		ADDRESS=$$(cast wallet address --private-key $(PRIVATE_KEY)); \
	else \
		ADDRESS=$(ADDRESS); \
	fi; \
	echo "Address: $$ADDRESS"; \
	echo "ETH: $$(cast balance --ether $$ADDRESS --rpc-url $(BASE_RPC_URL))"

lint:
	@echo "🔍 Running linter..."
	forge fmt --check
	@echo "✅ Lint check complete!"

format:
	@echo "✨ Formatting code..."
	forge fmt
	@echo "✅ Format complete!"

gas-snapshot:
	@echo "📸 Creating gas snapshot..."
	forge snapshot
	@echo "✅ Gas snapshot saved to .gas-snapshot"

# ======================================
# 💰 USER OPERATIONS (Testnet)
# ======================================

USDC_SEPOLIA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e

deposit-testnet:
	@echo "💰 Depositando en Vault (Base Sepolia)"
	@echo "════════════════════════════════════════"
	@if [ -z "$(AMOUNT)" ]; then \
		echo "❌ Error: AMOUNT not set"; \
		echo "Usage: make deposit-testnet AMOUNT=10.5 VAULT_PROXY=0x..."; \
		echo ""; \
		echo "Examples:"; \
		echo "  make deposit-testnet AMOUNT=1 VAULT_PROXY=0x...    # Deposit 1 USDC"; \
		echo "  make deposit-testnet AMOUNT=10.50 VAULT_PROXY=0x... # Deposit 10.50 USDC"; \
		exit 1; \
	fi
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		exit 1; \
	fi
	@if [ -z "$(USER_PRIVATE_KEY)" ]; then \
		echo "❌ Error: USER_PRIVATE_KEY not set in .env"; \
		exit 1; \
	fi
	@# Calcular amount en formato USDC (6 decimales)
	@AMOUNT_RAW=$$(echo "$(AMOUNT) * 1000000" | bc | cut -d'.' -f1); \
	USER_ADDRESS=$$(cast wallet address --private-key $(USER_PRIVATE_KEY)); \
	echo "📊 Amount: $(AMOUNT) USDC ($$AMOUNT_RAW raw)"; \
	echo "👤 Depositor: $$USER_ADDRESS"; \
	echo "📍 Vault: $(VAULT_PROXY)"; \
	echo "💵 USDC: $(USDC_SEPOLIA)"; \
	echo ""; \
	echo "Checking balances..."; \
	USDC_BALANCE=$$(cast call $(USDC_SEPOLIA) "balanceOf(address)" $$USER_ADDRESS --rpc-url $(BASE_SEPOLIA_RPC_URL) | xargs cast --to-dec); \
	USDC_BAL_HUMAN=$$(echo "scale=2; $$USDC_BALANCE / 1000000" | bc); \
	echo "💵 Your USDC balance: $$USDC_BAL_HUMAN USDC"; \
	if [ $$USDC_BALANCE -lt $$AMOUNT_RAW ]; then \
		echo "❌ Insufficient USDC balance!"; \
		echo "Need USDC? Visit: https://faucet.circle.com/"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "1️⃣ Aprobando USDC..."; \
	APPROVAL_TX=$$(cast send $(USDC_SEPOLIA) "approve(address,uint256)" $(VAULT_PROXY) $$AMOUNT_RAW \
		--private-key $(USER_PRIVATE_KEY) \
		--rpc-url $(BASE_SEPOLIA_RPC_URL) \
		2>&1); \
	if echo "$$APPROVAL_TX" | grep -q "transactionHash"; then \
		echo "   ✅ Approval tx sent"; \
		echo "   ⏳ Waiting for confirmation..."; \
		sleep 8; \
		ALLOWANCE=$$(cast call $(USDC_SEPOLIA) "allowance(address,address)" $$USER_ADDRESS $(VAULT_PROXY) --rpc-url $(BASE_SEPOLIA_RPC_URL) | xargs cast --to-dec); \
		ALLOWANCE_HUMAN=$$(echo "scale=2; $$ALLOWANCE / 1000000" | bc); \
		echo "   ✓ Current allowance: $$ALLOWANCE_HUMAN USDC"; \
		if [ $$ALLOWANCE -lt $$AMOUNT_RAW ]; then \
			echo "   ❌ Approval failed - insufficient allowance!"; \
			exit 1; \
		fi; \
	else \
		echo "   ❌ Approval transaction failed"; \
		echo "$$APPROVAL_TX"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "2️⃣ Depositando en vault..."; \
	DEPOSIT_OUTPUT=$$(cast send $(VAULT_PROXY) "deposit(uint256,address)" $$AMOUNT_RAW $$USER_ADDRESS \
		--private-key $(USER_PRIVATE_KEY) \
		--rpc-url $(BASE_SEPOLIA_RPC_URL) \
		2>&1); \
	if echo "$$DEPOSIT_OUTPUT" | grep -q "transactionHash"; then \
		echo "   ✅ Deposit successful!"; \
		TX_HASH=$$(echo "$$DEPOSIT_OUTPUT" | grep "transactionHash" | grep -o '0x[a-fA-F0-9]\{64\}' | head -1); \
		if [ -n "$$TX_HASH" ]; then \
			echo ""; \
			echo "📊 Transaction: https://sepolia.basescan.org/tx/$$TX_HASH"; \
		fi; \
		echo ""; \
		echo "Checking your vault shares..."; \
		sleep 3; \
		SHARES=$$(cast call $(VAULT_PROXY) "balanceOf(address)" $$USER_ADDRESS --rpc-url $(BASE_SEPOLIA_RPC_URL) | xargs cast --to-dec); \
		SHARES_HUMAN=$$(echo "scale=6; $$SHARES / 1000000" | bc); \
		echo "🎫 Your vault shares: $$SHARES_HUMAN"; \
	else \
		echo "   ❌ Deposit failed"; \
		echo "Error details:"; \
		echo "$$DEPOSIT_OUTPUT" | head -10; \
		exit 1; \
	fi

withdraw-testnet:
	@echo "💸 Retirando del Vault (Base Sepolia)"
	@echo "════════════════════════════════════════"
	@if [ -z "$(AMOUNT)" ]; then \
		echo "❌ Error: AMOUNT not set"; \
		echo "Usage: make withdraw-testnet AMOUNT=10.5 VAULT_PROXY=0x..."; \
		echo ""; \
		echo "Examples:"; \
		echo "  make withdraw-testnet AMOUNT=1 VAULT_PROXY=0x...    # Withdraw 1 USDC"; \
		echo "  make withdraw-testnet AMOUNT=all VAULT_PROXY=0x...  # Withdraw all"; \
		exit 1; \
	fi
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		exit 1; \
	fi
	@if [ -z "$(USER_PRIVATE_KEY)" ]; then \
		echo "❌ Error: USER_PRIVATE_KEY not set in .env"; \
		exit 1; \
	fi
	@USER_ADDRESS=$$(cast wallet address --private-key $(USER_PRIVATE_KEY)); \
	echo "👤 Withdrawer: $$USER_ADDRESS"; \
	echo "📍 Vault: $(VAULT_PROXY)"; \
	echo ""; \
	SHARES=$$(cast call $(VAULT_PROXY) "balanceOf(address)" $$USER_ADDRESS --rpc-url $(BASE_SEPOLIA_RPC_URL) | xargs cast --to-dec); \
	SHARES_HUMAN=$$(echo "scale=6; $$SHARES / 1000000" | bc); \
	echo "🎫 Your vault shares: $$SHARES_HUMAN"; \
	if [ $$SHARES -eq 0 ]; then \
		echo "❌ No shares to withdraw!"; \
		exit 1; \
	fi; \
	if [ "$(AMOUNT)" = "all" ]; then \
		echo "📊 Withdrawing all shares"; \
		echo ""; \
		echo "🔄 Processing redeem..."; \
		TX_HASH=$$(cast send $(VAULT_PROXY) "redeem(uint256,address,address)" $$SHARES $$USER_ADDRESS $$USER_ADDRESS \
			--private-key $(USER_PRIVATE_KEY) \
			--rpc-url $(BASE_SEPOLIA_RPC_URL) \
			--gas-price 2gwei \
			--json | grep -o '"transactionHash":"0x[^"]*"' | cut -d'"' -f4); \
	else \
		AMOUNT_RAW=$$(echo "$(AMOUNT) * 1000000" | bc | cut -d'.' -f1); \
		echo "📊 Amount: $(AMOUNT) USDC ($$AMOUNT_RAW raw)"; \
		echo ""; \
		echo "🔄 Processing withdrawal..."; \
		TX_HASH=$$(cast send $(VAULT_PROXY) "withdraw(uint256,address,address)" $$AMOUNT_RAW $$USER_ADDRESS $$USER_ADDRESS \
			--private-key $(USER_PRIVATE_KEY) \
			--rpc-url $(BASE_SEPOLIA_RPC_URL) \
			--gas-price 2gwei \
			--json | grep -o '"transactionHash":"0x[^"]*"' | cut -d'"' -f4); \
	fi; \
	if [ -n "$$TX_HASH" ]; then \
		echo "   ✅ Withdrawal successful!"; \
		echo ""; \
		echo "📊 Transaction: https://sepolia.basescan.org/tx/$$TX_HASH"; \
	else \
		echo "   ❌ Withdrawal failed"; \
		exit 1; \
	fi

# ======================================
# 💰 USER OPERATIONS (Mainnet)
# ======================================

USDC_MAINNET = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913

approve-usdc-mainnet:
	@echo "✅ Aprobar USDC para Vault (Base Mainnet)"
	@echo "════════════════════════════════════════════"
	@if [ -z "$(AMOUNT)" ]; then \
		echo "❌ Error: AMOUNT not set"; \
		echo "Usage: make approve-usdc-mainnet AMOUNT=10.5 VAULT_PROXY=0x..."; \
		echo ""; \
		echo "Examples:"; \
		echo "  make approve-usdc-mainnet AMOUNT=1 VAULT_PROXY=0x...      # Approve 1 USDC"; \
		echo "  make approve-usdc-mainnet AMOUNT=100 VAULT_PROXY=0x...    # Approve 100 USDC"; \
		echo "  make approve-usdc-mainnet AMOUNT=unlimited VAULT_PROXY=0x... # Approve unlimited"; \
		exit 1; \
	fi
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		exit 1; \
	fi
	@if [ -z "$(USER_PRIVATE_KEY)" ]; then \
		echo "❌ Error: USER_PRIVATE_KEY not set in .env"; \
		exit 1; \
	fi
	@USER_ADDRESS=$$(cast wallet address --private-key $(USER_PRIVATE_KEY)); \
	echo "👤 User: $$USER_ADDRESS"; \
	echo "📍 Vault: $(VAULT_PROXY)"; \
	echo "💵 USDC: $(USDC_MAINNET)"; \
	echo ""; \
	if [ "$(AMOUNT)" = "unlimited" ]; then \
		AMOUNT_RAW="115792089237316195423570985008687907853269984665640564039457584007913129639935"; \
		echo "📊 Approving: Unlimited USDC"; \
	else \
		AMOUNT_RAW=$$(echo "$(AMOUNT) * 1000000" | bc | cut -d'.' -f1); \
		echo "📊 Approving: $(AMOUNT) USDC ($$AMOUNT_RAW raw)"; \
	fi; \
	echo ""; \
	echo "🔄 Sending approval transaction..."; \
	cast send $(USDC_MAINNET) \
		"approve(address,uint256)" \
		$(VAULT_PROXY) \
		$$AMOUNT_RAW \
		--private-key $(USER_PRIVATE_KEY) \
		--rpc-url $(BASE_RPC_URL); \
	echo ""; \
	echo "✅ USDC approval successful!"; \
	echo ""; \
	ALLOWANCE=$$(cast call $(USDC_MAINNET) "allowance(address,address)" $$USER_ADDRESS $(VAULT_PROXY) --rpc-url $(BASE_RPC_URL) 2>/dev/null | xargs cast --to-dec 2>/dev/null || echo "0"); \
	if [ "$$ALLOWANCE" = "115792089237316195423570985008687907853269984665640564039457584007913129639935" ] || [ $$(echo "$$ALLOWANCE > 1000000000000000000000" | bc) -eq 1 ]; then \
		echo "✅ Current allowance: Unlimited"; \
	else \
		ALLOWANCE_HUMAN=$$(echo "scale=2; $$ALLOWANCE / 1000000" | bc 2>/dev/null || echo "0"); \
		echo "✅ Current allowance: $$ALLOWANCE_HUMAN USDC"; \
	fi

deposit-mainnet:
	@echo "💰 Depositar en Vault (Base Mainnet)"
	@echo "════════════════════════════════════════"
	@if [ -z "$(AMOUNT)" ]; then \
		echo "❌ Error: AMOUNT not set"; \
		echo "Usage: make deposit-mainnet AMOUNT=10.5 VAULT_PROXY=0x..."; \
		echo ""; \
		echo "Examples:"; \
		echo "  make deposit-mainnet AMOUNT=1 VAULT_PROXY=0x...    # Deposit 1 USDC"; \
		echo "  make deposit-mainnet AMOUNT=10.50 VAULT_PROXY=0x... # Deposit 10.50 USDC"; \
		exit 1; \
	fi
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		exit 1; \
	fi
	@if [ -z "$(USER_PRIVATE_KEY)" ]; then \
		echo "❌ Error: USER_PRIVATE_KEY not set in .env"; \
		exit 1; \
	fi
	@AMOUNT_RAW=$$(echo "$(AMOUNT) * 1000000" | bc | cut -d'.' -f1); \
	USER_ADDRESS=$$(cast wallet address --private-key $(USER_PRIVATE_KEY)); \
	echo "📊 Amount: $(AMOUNT) USDC ($$AMOUNT_RAW raw)"; \
	echo "👤 Depositor: $$USER_ADDRESS"; \
	echo "📍 Vault: $(VAULT_PROXY)"; \
	echo "💵 USDC: $(USDC_MAINNET)"; \
	echo ""; \
	echo "Checking balances..."; \
	USDC_BALANCE=$$(cast call $(USDC_MAINNET) "balanceOf(address)" $$USER_ADDRESS --rpc-url $(BASE_RPC_URL) | xargs cast --to-dec); \
	USDC_BALANCE_HUMAN=$$(echo "scale=2; $$USDC_BALANCE / 1000000" | bc); \
	echo "💵 USDC Balance: $$USDC_BALANCE_HUMAN USDC"; \
	if [ $$USDC_BALANCE -lt $$AMOUNT_RAW ]; then \
		echo "❌ Insufficient USDC balance!"; \
		exit 1; \
	fi; \
	ALLOWANCE=$$(cast call $(USDC_MAINNET) "allowance(address,address)" $$USER_ADDRESS $(VAULT_PROXY) --rpc-url $(BASE_RPC_URL) | xargs cast --to-dec); \
	ALLOWANCE_HUMAN=$$(echo "scale=2; $$ALLOWANCE / 1000000" | bc); \
	echo "✅ USDC Allowance: $$ALLOWANCE_HUMAN USDC"; \
	if [ $$ALLOWANCE -lt $$AMOUNT_RAW ]; then \
		echo ""; \
		echo "⚠️  Insufficient allowance! Please approve first:"; \
		echo "   make approve-usdc-mainnet AMOUNT=$(AMOUNT) VAULT_PROXY=$(VAULT_PROXY)"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "🔄 Depositing..."; \
	DEPOSIT_OUTPUT=$$(cast send $(VAULT_PROXY) \
		"deposit(uint256,address)" \
		$$AMOUNT_RAW \
		$$USER_ADDRESS \
		--private-key $(USER_PRIVATE_KEY) \
		--rpc-url $(BASE_RPC_URL) \
		2>&1); \
	if echo "$$DEPOSIT_OUTPUT" | grep -q "transactionHash"; then \
		TX_HASH=$$(echo "$$DEPOSIT_OUTPUT" | grep -o 'transactionHash.*0x[a-fA-F0-9]\{64\}' | grep -o '0x[a-fA-F0-9]\{64\}' | head -1); \
		echo "   ✅ Deposit successful!"; \
		echo ""; \
		echo "📊 Transaction: https://basescan.org/tx/$$TX_HASH"; \
		echo ""; \
		echo "Checking your vault shares..."; \
		SHARES=$$(cast call $(VAULT_PROXY) "balanceOf(address)" $$USER_ADDRESS --rpc-url $(BASE_RPC_URL) | xargs cast --to-dec); \
		SHARES_HUMAN=$$(echo "scale=6; $$SHARES / 1000000" | bc); \
		echo "🎫 Your vault shares: $$SHARES_HUMAN"; \
		echo ""; \
		echo "🔍 Check vault status: make status-mainnet VAULT_PROXY=$(VAULT_PROXY)"; \
	else \
		echo "   ❌ Deposit failed"; \
		echo "Error details:"; \
		echo "$$DEPOSIT_OUTPUT" | head -10; \
		exit 1; \
	fi

withdraw-mainnet:
	@echo "💸 Retirar del Vault (Base Mainnet)"
	@echo "════════════════════════════════════════"
	@if [ -z "$(AMOUNT)" ]; then \
		echo "❌ Error: AMOUNT not set"; \
		echo "Usage: make withdraw-mainnet AMOUNT=10.5 VAULT_PROXY=0x..."; \
		echo ""; \
		echo "Examples:"; \
		echo "  make withdraw-mainnet AMOUNT=1 VAULT_PROXY=0x...    # Withdraw 1 USDC"; \
		echo "  make withdraw-mainnet AMOUNT=all VAULT_PROXY=0x...  # Withdraw all"; \
		exit 1; \
	fi
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		exit 1; \
	fi
	@if [ -z "$(USER_PRIVATE_KEY)" ]; then \
		echo "❌ Error: USER_PRIVATE_KEY not set in .env"; \
		exit 1; \
	fi
	@USER_ADDRESS=$$(cast wallet address --private-key $(USER_PRIVATE_KEY)); \
	echo "👤 Withdrawer: $$USER_ADDRESS"; \
	echo "📍 Vault: $(VAULT_PROXY)"; \
	echo "💵 USDC: $(USDC_MAINNET)"; \
	echo ""; \
	SHARES=$$(cast call $(VAULT_PROXY) "balanceOf(address)" $$USER_ADDRESS --rpc-url $(BASE_RPC_URL) 2>/dev/null | xargs cast --to-dec 2>/dev/null || echo "0"); \
	SHARES_HUMAN=$$(echo "scale=6; $$SHARES / 1000000" | bc 2>/dev/null || echo "0"); \
	echo "🎫 Your vault shares: $$SHARES_HUMAN"; \
	if [ "$$SHARES" = "0" ] || [ -z "$$SHARES" ]; then \
		echo "❌ No shares to withdraw!"; \
		exit 1; \
	fi; \
	if [ "$(AMOUNT)" = "all" ]; then \
		echo "📊 Withdrawing all shares"; \
		echo ""; \
		echo "🔄 Processing redeem..."; \
		WITHDRAW_OUTPUT=$$(cast send $(VAULT_PROXY) \
			"redeem(uint256,address,address)" \
			$$SHARES \
			$$USER_ADDRESS \
			$$USER_ADDRESS \
			--private-key $(USER_PRIVATE_KEY) \
			--rpc-url $(BASE_RPC_URL) \
			2>&1); \
	else \
		AMOUNT_RAW=$$(echo "$(AMOUNT) * 1000000" | bc | cut -d'.' -f1); \
		echo "📊 Amount: $(AMOUNT) USDC ($$AMOUNT_RAW raw)"; \
		echo ""; \
		echo "🔄 Processing withdrawal..."; \
		WITHDRAW_OUTPUT=$$(cast send $(VAULT_PROXY) \
			"withdraw(uint256,address,address)" \
			$$AMOUNT_RAW \
			$$USER_ADDRESS \
			$$USER_ADDRESS \
			--private-key $(USER_PRIVATE_KEY) \
			--rpc-url $(BASE_RPC_URL) \
			2>&1); \
	fi; \
	if echo "$$WITHDRAW_OUTPUT" | grep -q "transactionHash"; then \
		TX_HASH=$$(echo "$$WITHDRAW_OUTPUT" | grep -o 'transactionHash.*0x[a-fA-F0-9]\{64\}' | grep -o '0x[a-fA-F0-9]\{64\}' | head -1); \
		echo "   ✅ Withdrawal successful!"; \
		echo ""; \
		echo "📊 Transaction: https://basescan.org/tx/$$TX_HASH"; \
		echo ""; \
		echo "Checking your balances..."; \
		USDC_BALANCE=$$(cast call $(USDC_MAINNET) "balanceOf(address)" $$USER_ADDRESS --rpc-url $(BASE_RPC_URL) 2>/dev/null | xargs cast --to-dec 2>/dev/null || echo "0"); \
		USDC_BALANCE_HUMAN=$$(echo "scale=2; $$USDC_BALANCE / 1000000" | bc 2>/dev/null || echo "0"); \
		echo "💵 USDC Balance: $$USDC_BALANCE_HUMAN USDC"; \
		REMAINING_SHARES=$$(cast call $(VAULT_PROXY) "balanceOf(address)" $$USER_ADDRESS --rpc-url $(BASE_RPC_URL) 2>/dev/null | xargs cast --to-dec 2>/dev/null || echo "0"); \
		REMAINING_SHARES_HUMAN=$$(echo "scale=6; $$REMAINING_SHARES / 1000000" | bc 2>/dev/null || echo "0"); \
		echo "🎫 Remaining vault shares: $$REMAINING_SHARES_HUMAN"; \
		echo ""; \
		echo "🔍 Check vault status: make status-mainnet VAULT_PROXY=$(VAULT_PROXY)"; \
	else \
		echo "   ❌ Withdrawal failed"; \
		echo "Error details:"; \
		echo "$$WITHDRAW_OUTPUT" | head -10; \
		exit 1; \
	fi

approve-autopool-shares:
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║   🔓 APROBAR SHARES DEL AUTOPOOL (FIX WITHDRAW)  🔓   ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@if [ -z "$(STRATEGY)" ]; then \
		echo "❌ Error: STRATEGY not set"; \
		echo "Usage: make approve-autopool-shares STRATEGY=0x..."; \
		exit 1; \
	fi
	@echo "🎯 Strategy: $(STRATEGY)"
	@echo "🏦 AutoPool: 0x9c6864105AEC23388C89600046213a44C384c831"
	@echo "👤 Executor: $$(cast wallet address --private-key $(PRIVATE_KEY))"
	@echo ""
	@echo "⚠️  Esto aprobará al AutoPool para quemar las shares de la estrategia"
	@echo "    Necesario para que withdraw() funcione correctamente"
	@echo ""
	@read -p "Type 'APPROVE' to confirm: " confirm; \
	if [ "$$confirm" = "APPROVE" ]; then \
		echo "🔓 Aprobando shares..."; \
		cast send 0x9c6864105AEC23388C89600046213a44C384c831 \
			"approve(address,uint256)" \
			0x9c6864105AEC23388C89600046213a44C384c831 \
			115792089237316195423570985008687907853269984665640564039457584007913129639935 \
			--rpc-url $(BASE_RPC_URL) \
			--private-key $(PRIVATE_KEY); \
		echo ""; \
		echo "✅ Approval exitoso!"; \
		echo ""; \
		echo "🔍 Verificar allowance:"; \
		ALLOWANCE=$$(cast call 0x9c6864105AEC23388C89600046213a44C384c831 \
			"allowance(address,address)" \
			$(STRATEGY) \
			0x9c6864105AEC23388C89600046213a44C384c831 \
			--rpc-url $(BASE_RPC_URL) | xargs cast --to-dec); \
		if [ "$$ALLOWANCE" = "115792089237316195423570985008687907853269984665640564039457584007913129639935" ]; then \
			echo "✅ Allowance: Unlimited (correcto)"; \
		else \
			echo "✅ Allowance: $$ALLOWANCE"; \
		fi; \
		echo ""; \
		echo "🎉 Ahora puedes hacer withdraw:"; \
		echo "   make withdraw-mainnet AMOUNT=0.05 VAULT_PROXY=0x9678a01Eb9c7545ED422399d34900a5019ae71bE"; \
	else \
		echo "❌ Approval cancelado"; \
	fi

emergency-withdraw-strategy:
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║   🚨 EMERGENCY WITHDRAW FROM STRATEGY  🚨             ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@if [ -z "$(STRATEGY)" ]; then \
		echo "❌ Error: STRATEGY not set"; \
		echo "Usage: make emergency-withdraw-strategy STRATEGY=0x..."; \
		exit 1; \
	fi
	@echo "🎯 Strategy: $(STRATEGY)"
	@echo "👤 Executor: $$(cast wallet address --private-key $(PRIVATE_KEY))"
	@echo ""
	@echo "🔍 Verificando fondos en estrategia..."
	@TOTAL_ASSETS=$$(cast call $(STRATEGY) "totalAssets()" --rpc-url $(BASE_RPC_URL) 2>/dev/null | xargs cast --to-dec 2>/dev/null || echo "0"); \
	TOTAL_SHARES=$$(cast call $(STRATEGY) "totalShares()" --rpc-url $(BASE_RPC_URL) 2>/dev/null | xargs cast --to-dec 2>/dev/null || echo "0"); \
	echo "💰 Total Assets: $$TOTAL_ASSETS ($$(($$TOTAL_ASSETS / 1000000)) USDC)"; \
	echo "📊 Total Shares: $$TOTAL_SHARES"; \
	echo ""; \
	if [ "$$TOTAL_ASSETS" = "0" ]; then \
		echo "✅ No hay fondos en la estrategia"; \
		exit 0; \
	fi; \
	echo "⚠️  Esto retirará TODOS los fondos de la estrategia al vault"; \
	echo ""; \
	read -p "Type 'WITHDRAW' to confirm: " confirm; \
	if [ "$$confirm" = "WITHDRAW" ]; then \
		echo "🚨 Ejecutando emergencyWithdraw()..."; \
		cast send $(STRATEGY) \
			"emergencyWithdraw()" \
			--rpc-url $(BASE_RPC_URL) \
			--private-key $(PRIVATE_KEY); \
		echo ""; \
		echo "✅ Fondos recuperados!"; \
		echo ""; \
		echo "🔍 Verificando que la estrategia quedó vacía:"; \
		NEW_ASSETS=$$(cast call $(STRATEGY) "totalAssets()" --rpc-url $(BASE_RPC_URL) 2>/dev/null | xargs cast --to-dec 2>/dev/null || echo "0"); \
		NEW_SHARES=$$(cast call $(STRATEGY) "totalShares()" --rpc-url $(BASE_RPC_URL) 2>/dev/null | xargs cast --to-dec 2>/dev/null || echo "0"); \
		echo "💰 Total Assets ahora: $$NEW_ASSETS"; \
		echo "📊 Total Shares ahora: $$NEW_SHARES"; \
		if [ "$$NEW_ASSETS" = "0" ] && [ "$$NEW_SHARES" = "0" ]; then \
			echo "✅ Estrategia vacía correctamente"; \
		else \
			echo "⚠️  Aún quedan fondos en la estrategia"; \
		fi; \
		echo ""; \
		echo "🎉 Siguiente paso: Deploy nueva estrategia"; \
		echo "   make deploy-strategy-mainnet"; \
	else \
		echo "❌ Withdraw cancelado"; \
	fi

# ======================================
# 🔐 ADMIN FUNCTIONS (Testnet)
# ======================================

pause-testnet:
	@echo "⏸️  Pausing vault on testnet..."
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		exit 1; \
	fi
	cast send $(VAULT_PROXY) "pause()" \
		--private-key $(PRIVATE_KEY) \
		--rpc-url $(BASE_SEPOLIA_RPC_URL)
	@echo "✅ Vault paused!"

unpause-testnet:
	@echo "▶️  Unpausing vault on testnet..."
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		exit 1; \
	fi
	cast send $(VAULT_PROXY) "unpause()" \
		--private-key $(PRIVATE_KEY) \
		--rpc-url $(BASE_SEPOLIA_RPC_URL)
	@echo "✅ Vault unpaused!"

update-fees-testnet:
	@echo "💸 Updating fees on testnet..."
	@if [ -z "$(VAULT_PROXY)" ] || [ -z "$(PERF_FEE)" ] || [ -z "$(MGMT_FEE)" ]; then \
		echo "❌ Error: Missing parameters"; \
		echo "Usage: make update-fees-testnet VAULT_PROXY=0x... PERF_FEE=1000 MGMT_FEE=100"; \
		exit 1; \
	fi
	@echo "Performance Fee: $(PERF_FEE) bps"
	@echo "Management Fee: $(MGMT_FEE) bps"
	cast send $(VAULT_PROXY) "updateFees(uint256,uint256)" $(PERF_FEE) $(MGMT_FEE) \
		--private-key $(PRIVATE_KEY) \
		--rpc-url $(BASE_SEPOLIA_RPC_URL)
	@echo "✅ Fees updated!"

# ======================================
# 🏠 LOCAL DEVELOPMENT (Anvil)
# ======================================

setup-local:
	@echo "🚀 Setting up local development environment..."
	./script/SetupLocal.sh

stop-local:
	@echo "🛑 Stopping local environment..."
	./script/StopLocal.sh

deploy-local:
	@echo "📦 Deploying to local Anvil..."
	@if [ ! -f .env.local ]; then \
		echo "❌ Run 'make setup-local' first"; \
		exit 1; \
	fi
	@source .env.local && \
	forge script script/DeployVaultProxy.s.sol \
		--rpc-url http://localhost:8545 \
		--private-key $$PRIVATE_KEY \
		--broadcast \
		-vvv

status-local:
	@echo "🔍 Local Vault Status"
	@echo "════════════════════════════════"
	@if [ ! -f .env.local ]; then \
		echo "❌ Run 'make setup-local' first"; \
		exit 1; \
	fi
	@source .env.local && \
	if [ -z "$$VAULT_PROXY" ]; then \
		echo "❌ VAULT_PROXY not set in .env.local"; \
		echo "Deploy first with: make deploy-local"; \
		exit 1; \
	fi && \
	echo "📍 Proxy: $$VAULT_PROXY" && \
	echo "📊 Version: $$(cast call $$VAULT_PROXY "version()" --rpc-url http://localhost:8545)" && \
	echo "👤 Owner: $$(cast call $$VAULT_PROXY "owner()" --rpc-url http://localhost:8545)" && \
	echo "💰 TVL: $$(cast call $$VAULT_PROXY "totalAssets()" --rpc-url http://localhost:8545)"

balance-local:
	@echo "💰 Local Balances"
	@echo "════════════════════════════════"
	@if [ ! -f .env.local ]; then \
		echo "❌ Run 'make setup-local' first"; \
		exit 1; \
	fi
	@source .env.local && \
	echo "Address: $$ADDRESS" && \
	echo "ETH: $$(cast balance --ether $$ADDRESS --rpc-url http://localhost:8545)" && \
	if [ -n "$$USDC_ADDRESS" ]; then \
		USDC_BAL=$$(cast call $$USDC_ADDRESS "balanceOf(address)" $$ADDRESS --rpc-url http://localhost:8545); \
		echo "USDC: $$(cast to-dec $$USDC_BAL) (raw) = $$(($(cast to-dec $$USDC_BAL) / 1000000)) USDC"; \
	fi

# ======================================
# 🧹 MAINTENANCE
# ======================================

update-deps:
	@echo "📦 Updating dependencies..."
	forge update
	@echo "✅ Dependencies updated!"

check-deps:
	@echo "🔍 Checking dependency versions..."
	@echo "OpenZeppelin Contracts:"
	@cd lib/openzeppelin-contracts && git describe --tags
	@echo "OpenZeppelin Contracts Upgradeable:"
	@cd lib/openzeppelin-contracts-upgradeable && git describe --tags
	@echo "Forge Std:"
	@cd lib/forge-std && git describe --tags

# ======================================
# 📚 DOCUMENTATION
# ======================================

docs:
	@echo "📚 Opening documentation..."
	@echo ""
	@echo "Available docs:"
	@ls -1 docs/
	@echo ""
	@echo "Use: cat docs/<filename>"

# ======================================
# 🔒 SECURITY
# ======================================

slither:
	@echo "🔍 Running Slither security analysis..."
	slither . --config-file slither.config.json
	@echo "✅ Slither analysis complete!"

security-check:
	@echo "🔒 Running security checks..."
	@echo ""
	@echo "1. Checking for common vulnerabilities..."
	forge test --match-test test_Security
	@echo ""
	@echo "2. Checking storage layout..."
	forge inspect VaultToken storage-layout
	@echo ""
	@echo "3. Gas optimization check..."
	forge test --gas-report | grep -A 5 "expensive"
	@echo ""
	@echo "✅ Security check complete!"

