#!/bin/bash

# ======================================
# 🛑 Stop Local Development Environment
# ======================================

echo "🛑 Stopping local development environment..."

# Leer PID del archivo
if [ -f .anvil.pid ]; then
    ANVIL_PID=$(cat .anvil.pid)
    
    if ps -p $ANVIL_PID > /dev/null 2>&1; then
        echo "Stopping Anvil (PID: $ANVIL_PID)..."
        kill $ANVIL_PID
        rm .anvil.pid
        echo "✅ Anvil stopped"
    else
        echo "⚠️  Anvil not running"
        rm .anvil.pid
    fi
else
    # Buscar y matar cualquier proceso anvil
    pkill -f anvil && echo "✅ Anvil processes killed" || echo "⚠️  No Anvil processes found"
fi

echo ""
echo "✨ Local environment stopped"
echo ""
echo "To start again: ./script/SetupLocal.sh"

