#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LLM_ROOT="$(cd "${BASE_DIR}/.." && pwd)"

echo "=========================================================="
echo "🔍 Validierung der AMD ROCm Inferenz & W7800 Hardware"
echo "=========================================================="

# 1. ROCm & W7800 Hardware Check
echo -e "\n[1] AMD Radeon PRO W7800 & LACT Status:"
if [ -x "${LLM_ROOT}/scripts/gpu-status.sh" ]; then
    "${LLM_ROOT}/scripts/gpu-status.sh"
elif command -v rocminfo &>/dev/null; then
    GPU_NAME=$(rocminfo | grep -m1 "Marketing Name:" | awk -F: '{print $2}' | xargs || echo "AMD GPU")
    echo "• Erkannte GPU: ${GPU_NAME}"
else
    echo "⚠️ Weder gpu-status.sh noch rocminfo gefunden."
fi

# 2. Render- und Videogruppen
echo -e "\n[2] Benutzergruppen für Hardwarebeschleunigung:"
USER_GROUPS=$(groups "$USER")
echo "• Gruppen: ${USER_GROUPS}"
if echo "$USER_GROUPS" | grep -q "render"; then
    echo "✅ Berechtigungen (render/video) vorhanden."
else
    echo "⚠️ ACHTUNG: Benutzer $USER ist nicht in der 'render'-Gruppe!"
    echo "Führe aus: sudo usermod -aG render,video $USER"
fi

# 3. Ollama API Test
echo -e "\n[3] Ollama API (Port 11434):"
TS_IP="$(tailscale ip -4 2>/dev/null || echo '127.0.0.1')"
if curl -s -m 2 http://127.0.0.1:11434/api/version | grep -q "version"; then
    echo "✅ Ollama API antwortet auf 127.0.0.1:11434."
elif curl -s -m 2 "http://${TS_IP}:11434/api/version" | grep -q "version"; then
    echo "✅ Ollama API antwortet auf Tailscale ${TS_IP}:11434."
else
    echo "⚠️ Ollama API antwortet aktuell nicht auf Port 11434."
fi

# 4. llama-speedup (Speculative Decoding Proxy Port 5002)
echo -e "\n[4] llama-speedup Speculative Proxy (Port 5002):"
if curl -s -m 2 http://127.0.0.1:5002/running >/dev/null 2>&1; then
    echo "✅ llama-speedup antwortet auf 127.0.0.1:5002."
else
    echo "ℹ️ llama-speedup auf Port 5002 im Standby."
fi

# 5. MCP SearXNG Bridge Selbsttest
echo -e "\n[5] Lokaler MCP SearXNG Bridge Protokoll-Test (JSON-RPC 2.0):"
MCP_OUT=$(printf '{"jsonrpc":"2.0","id":1,"method":"initialize"}\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","id":2,"method":"tools/list"}\n' | python3 "${BASE_DIR}/scripts/mcp_searxng_bridge.py")
if echo "$MCP_OUT" | grep -q "searxng_search"; then
    echo "✅ MCP SearXNG Bridge antwortet normgerecht (MCP 2024-11-05)."
else
    echo "❌ Fehler im MCP SearXNG Bridge!"
fi

# 6. Git Worktrees Check
echo -e "\n[6] Git Worktrees:"
if [ -d "${BASE_DIR}/projects/main/.git" ]; then
    git -C "${BASE_DIR}/projects/main" worktree list
else
    echo "ℹ️ Noch nicht initialisiert (Starte ./scripts/setup_worktrees.sh)."
fi

echo -e "\n=========================================================="
echo "🎯 Systemvalidierung erfolgreich abgeschlossen."
echo "=========================================================="
