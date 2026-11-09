#!/usr/bin/env bash
set -eo pipefail

echo "=========================================================="
echo "🎭 MCP-Tools & Playwright Browser Installation"
echo "=========================================================="

# 1. Node.js Check (mindestens Node 20)
if ! command -v node &>/dev/null; then
    echo "• Node.js nicht gefunden. Installiere Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    NODE_VER=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    echo "• Node.js Version: $(node -v) (Erforderlich: >= 20)"
    if [ "$NODE_VER" -lt 20 ]; then
        echo "⚠️ Node.js ist älter als Version 20. Bitte aktualisieren."
    fi
fi

# 2. Playwright MCP & Chromium Browser
echo "• Installiere Playwright Chromium Browser..."
npx -y playwright install chromium
npx -y playwright install-deps chromium

# 3. Standard MCP-Server cachen
echo "• Lade MCP-Filesystem & Git Server vor..."
npm install -g @modelcontextprotocol/server-filesystem mcp-server-git @playwright/mcp 2>/dev/null || true

echo -e "\n✅ MCP-Werkzeuge & Playwright erfolgreich eingerichtet!"

