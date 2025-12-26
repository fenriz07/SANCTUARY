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
	@echo "  make deploy-mainnet   - Deploy completo a mainnet"
	@echo "  make verify-mainnet   - Verificar contratos en mainnet"
	@echo ""
	@echo "🔄 Upgrades:"
	@echo "  make upgrade-testnet  - Upgrade a V2 en testnet"
	@echo "  make upgrade-mainnet  - Upgrade a V2 en mainnet"
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

# ======================================
# 🔄 UPGRADES
# ======================================

upgrade-testnet:
	@echo "🔄 Upgrading Vault on Base Sepolia..."
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		echo "Usage: make upgrade-testnet VAULT_PROXY=0x..."; \
		exit 1; \
	fi
	@echo "📍 Proxy Address: $(VAULT_PROXY)"
	@echo "🔑 Current Owner: $$(cast call $(VAULT_PROXY) "owner()" --rpc-url $(BASE_SEPOLIA_RPC_URL))"
	@echo ""
	@read -p "Continue with upgrade? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		sed -i 's/address constant PROXY_ADDRESS = address(0);/address constant PROXY_ADDRESS = $(VAULT_PROXY);/' script/UpgradeVaultProxy.s.sol; \
		forge script script/UpgradeVaultProxy.s.sol \
			--rpc-url $(BASE_SEPOLIA_RPC_URL) \
			--broadcast \
			--verify \
			-vvvv; \
		echo "✅ Upgrade complete!"; \
	else \
		echo "❌ Upgrade cancelled"; \
	fi

upgrade-mainnet:
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║         ⚠️  MAINNET UPGRADE - USE CAUTION  ⚠️          ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		echo "Usage: make upgrade-mainnet VAULT_PROXY=0x..."; \
		exit 1; \
	fi
	@echo "📍 Proxy Address: $(VAULT_PROXY)"
	@echo "🔑 Current Owner: $$(cast call $(VAULT_PROXY) "owner()" --rpc-url $(BASE_RPC_URL))"
	@echo "💰 TVL: $$(cast call $(VAULT_PROXY) "totalAssets()" --rpc-url $(BASE_RPC_URL))"
	@echo ""
	@echo "⚠️  UPGRADE CHECKLIST:"
	@echo "  [ ] Storage layout validated"
	@echo "  [ ] Upgrade tested on testnet"
	@echo "  [ ] Code audited"
	@echo "  [ ] Multisig ready (if applicable)"
	@echo ""
	@read -p "Type 'UPGRADE' to confirm mainnet upgrade: " confirm; \
	if [ "$$confirm" = "UPGRADE" ]; then \
		echo "🚀 Starting mainnet upgrade..."; \
		sed -i 's/address constant PROXY_ADDRESS = address(0);/address constant PROXY_ADDRESS = $(VAULT_PROXY);/' script/UpgradeVaultProxy.s.sol; \
		forge script script/UpgradeVaultProxy.s.sol \
			--rpc-url $(BASE_RPC_URL) \
			--broadcast \
			--verify \
			-vvvv; \
		echo "✅ MAINNET UPGRADE COMPLETE!"; \
	else \
		echo "❌ Mainnet upgrade cancelled"; \
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

status-mainnet:
	@echo "🔍 Vault Status on Base Mainnet"
	@echo "════════════════════════════════"
	@if [ -z "$(VAULT_PROXY)" ]; then \
		echo "❌ Error: VAULT_PROXY not set"; \
		echo "Usage: make status-mainnet VAULT_PROXY=0x..."; \
		exit 1; \
	fi
	@echo "📍 Proxy: $(VAULT_PROXY)"
	@VERSION=$$(cast call $(VAULT_PROXY) "version()" --rpc-url $(BASE_RPC_URL) | xargs cast --to-ascii); \
	echo "📊 Version: $$VERSION"
	@OWNER=$$(cast call $(VAULT_PROXY) "owner()" --rpc-url $(BASE_RPC_URL)); \
	echo "👤 Owner: $$OWNER"
	@TVL=$$(cast call $(VAULT_PROXY) "totalAssets()" --rpc-url $(BASE_RPC_URL) | xargs cast --to-dec); \
	TVL_USDC=$$(echo "scale=2; $$TVL / 1000000" | bc); \
	echo "💰 TVL: $$TVL_USDC USDC ($$TVL raw)"
	@PERF_FEE=$$(cast call $(VAULT_PROXY) "performanceFee()" --rpc-url $(BASE_RPC_URL) | xargs cast --to-dec); \
	PERF_PCT=$$(echo "scale=2; $$PERF_FEE / 100" | bc); \
	echo "📈 Performance Fee: $$PERF_PCT% ($$PERF_FEE bps)"
	@MGMT_FEE=$$(cast call $(VAULT_PROXY) "managementFee()" --rpc-url $(BASE_RPC_URL) | xargs cast --to-dec); \
	MGMT_PCT=$$(echo "scale=2; $$MGMT_FEE / 100" | bc); \
	echo "📈 Management Fee: $$MGMT_PCT% ($$MGMT_FEE bps)"
	@PAUSED=$$(cast call $(VAULT_PROXY) "paused()" --rpc-url $(BASE_RPC_URL)); \
	if [ "$$PAUSED" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then \
		echo "⏸️  Paused: No"; \
	else \
		echo "⏸️  Paused: Yes"; \
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

