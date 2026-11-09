#!/usr/bin/env bash
set -eo pipefail

export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${PATH}"

# ==============================================================================
# 📊 Status-Dashboard für Multi-Agent CLI Stack (AMD Radeon PRO W7800 48 GB)
# ==============================================================================

echo "======================================================================"
echo "🧠 Multi-Agent CLI Status: clemi-pc (AMD Radeon PRO W7800 48 GB)"
echo "======================================================================"

# 1. Hardware & Thermik via zentralem gpu-status.sh
echo -e "\n[1] AMD Radeon PRO W7800 Hardware, Lüfter & Power-Limit:"
if [ -x "/home/clemi/Projekte/LLM/scripts/gpu-status.sh" ]; then
    /home/clemi/Projekte/LLM/scripts/gpu-status.sh
elif command -v rocm-smi &>/dev/null; then
    rocm-smi --showmeminfo vram --showuse
else
    echo "⚠️ Keine GPU-Diagnosetools gefunden."
fi

# 2. Inferenz- & Such-Dienste
echo -e "\n[2] Lokale Dienste & Ports:"
echo -n "• Ollama (11434):                  "
if ss -lntp 2>/dev/null | grep -q ":11434"; then
    echo "✅ ONLINE"
else
    echo "❌ OFFLINE (sudo systemctl start ollama)"
fi

echo -n "• llama-speedup Speculative (5002):"
if ss -lntp 2>/dev/null | grep -q ":5002"; then
    RUNNING_SPEC=$(curl -s -m 2 http://127.0.0.1:5002/running 2>/dev/null | tr -d '\n' || echo "Bereit")
    echo " ✅ ONLINE (${RUNNING_SPEC:-Kein Modell geladen})"
else
    echo " ⚪ STANDBY (Docker llm-speedup nicht gestartet)"
fi

echo -n "• SearXNG Privatsuche (8081):      "
if ss -lntp 2>/dev/null | grep -q ":8081"; then
    echo "✅ ONLINE (Docker ai-network)"
else
    echo "❌ OFFLINE"
fi

echo -n "• Open WebUI (3000):               "
if ss -lntp 2>/dev/null | grep -q ":3000"; then
    echo "✅ ONLINE"
else
    echo "⚪ OFFLINE"
fi

# 3. Geladene Ollama-Modelle
echo -e "\n[3] Aktuell im VRAM geladene Ollama-Modelle:"
TS_IP="$(tailscale ip -4 2>/dev/null || echo '127.0.0.1')"
if command -v ollama &>/dev/null; then
    OLLAMA_OUT=$(OLLAMA_HOST="http://127.0.0.1:11434" timeout 2 ollama ps 2>/dev/null || OLLAMA_HOST="http://${TS_IP}:11434" timeout 2 ollama ps 2>/dev/null || echo "Keine Verbindung")
    echo "$OLLAMA_OUT"
fi

# 4. Installierte Agent-CLIs
echo -e "\n[4] Installierte Agent-Runtimes & MCP:"
echo -n "• OpenCode CLI: "
command -v opencode &>/dev/null && opencode --version 2>/dev/null || echo "Noch nicht installiert (./setup/01-install-cli-tools.sh)"
echo -n "• Goose CLI:    "
command -v goose &>/dev/null && goose --version 2>/dev/null || echo "Noch nicht installiert (./setup/01-install-cli-tools.sh)"
echo -n "• Node.js/NPX:  "
command -v node &>/dev/null && node --version 2>/dev/null || echo "Fehlt"

# 5. Tailscale & Worktrees
echo -e "\n[5] Tailscale & Git Worktrees:"
echo -n "• Tailscale IP: "
if command -v tailscale &>/dev/null; then
    tailscale ip -4 2>/dev/null || echo "Offline/Standby"
else
    echo "Nicht installiert"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_MAIN="${SCRIPT_DIR}/../projects/main"
if [ -d "${PROJECT_MAIN}/.git" ]; then
    echo "• Isolierte Agent-Worktrees (${PROJECT_MAIN}):"
    git -C "${PROJECT_MAIN}" worktree list
fi

echo "======================================================================"
