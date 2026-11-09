#!/usr/bin/env bash
set -eo pipefail

export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${PATH}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LLM_ROOT="$(cd "${BASE_DIR}/.." && pwd)"
OPENCODE_CFG="${BASE_DIR}/configs/opencode.json"
SESSION_NAME="agent-workspace"

# Setzt model UND small_model in opencode.json einheitlich auf genau 1 Modell
# und entfernt etwaige Multi-Model-Overrides aus agents/*.md
# -> Garantiert 0x Modell-Entladen während der gesamten Session!
set_single_model_mode() {
    local target_model="$1"
    "${SCRIPT_DIR}/multimodel_project_workflow.sh" reset >/dev/null 2>&1 || true
    python3 -c "
import json
path = '${OPENCODE_CFG}'
with open(path, 'r', encoding='utf-8') as f:
    cfg = json.load(f)
cfg['model'] = '${target_model}'
cfg['small_model'] = '${target_model}'
with open(path, 'w', encoding='utf-8') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write('\n')
"
    echo "✅ Modus-Modell fest zugewiesen (Hauptagent + small_model + alle @Subagents): ${target_model}"
}

echo "======================================================================"
echo "🚀 Multi-Agent CLI Launcher — Single-Model-per-Mode (0s Wechselzeit)"
echo "======================================================================"

# Pre-flight Check 1: Ollama
TS_IP="$(tailscale ip -4 2>/dev/null || echo '127.0.0.1')"
if curl -s -m 2 http://127.0.0.1:11434/api/version >/dev/null 2>&1 || curl -s -m 2 "http://${TS_IP}:11434/api/version" >/dev/null 2>&1; then
    echo "✅ [Port 11434] Ollama ist bereit."
else
    echo "⚠️ [Port 11434] Ollama antwortet nicht (Start via: sudo systemctl start ollama)"
fi

# Pre-flight Check 2: llama-speedup (Speculative Decoding)
if curl -s -m 2 http://127.0.0.1:5002/running >/dev/null 2>&1; then
    echo "✅ [Port 5002]  llama-speedup (Speculative Decoding Proxy) ist aktiv."
else
    echo "ℹ️ [Port 5002]  llama-speedup im Standby (Start bei Bedarf in llm-optimierungen/llm-speedup/)."
fi

# Pre-flight Check 3: SearXNG
if curl -s -m 2 http://127.0.0.1:8081 >/dev/null 2>&1; then
    echo "✅ [Port 8081]  Lokale SearXNG Privatsuche ist aktiv."
else
    echo "ℹ️ [Port 8081]  SearXNG nicht erreichbar (Websuche eingeschränkt)."
fi

# Pre-flight Check 4: Configs automatisch verlinken & Qwen3 Tool-Template patchen
if [ ! -L "${HOME}/.config/opencode/opencode.json" ] && [ ! -f "${HOME}/.config/opencode/opencode.json" ]; then
    "${BASE_DIR}/setup/03-link-agent-configs.sh"
fi

if [ ! -f "/tmp/.qwen3_tool_template_patched_v5" ]; then
    "${SCRIPT_DIR}/fix_ollama_tool_templates.sh" || true
fi

CURRENT_MODEL=$(python3 -c "import json; print(json.load(open('${OPENCODE_CFG}'))['model'])" 2>/dev/null || echo "ollama/qwen3-coder-quality")
echo -e "📌 Aktuell gesetztes Haupt-Modell: \033[1;36m${CURRENT_MODEL}\033[0m"

echo -e "\nWähle deinen Modus (Maximierter 100%-VRAM Default-Kontext pro Modus):"
echo "  --- SINGLE-MODEL OLLAMA MODI (Port 11434, 0x Entladen) ---"
echo "  1) 💻 Coding Quality 64k    -> ollama/qwen3-coder-quality (Q8_0 | 62.7 t/s | ~35.5 GB VRAM | 64k Max-Ctx!)"
echo "  2) ⚡ Coding Speed 128k     -> ollama/qwen3-coder-speed   (Q4_K | 80.6 t/s | ~24.5 GB VRAM | 128k Ultra-Ctx!)"
echo "  3) 🧠 Allround Distill 96k  -> ollama/qwen3.8-35b-distill (Q6_K | 66.6 t/s | ~33.0 GB VRAM | 96k Max-Ctx!)"
echo ""
echo "  --- SINGLE-MODEL SPECULATIVE 70B/72B MODI (Port 5002, 0x Entladen) ---"
echo "  4) 👑 72B Flaggschiff 32k   -> llama-speedup/qwen2.5-72b-speculative            (33.6 t/s | 42.0 GB VRAM | 32k Max-Ctx)"
echo "  5) 🔓 70B Unzensiert 32k    -> llama-speedup/llama3.3-70b-abliterated-speculative (30.0 t/s | 40.3 GB VRAM | 32k Max-Ctx)"
echo ""
echo "  --- MULTI-MODEL GROSSPROJEKT-WORKFLOW (Maximale Qualität durch Spezialisten) ---"
echo "  6) 🏆 Multi-Model-Profi     -> @planner=70B(32k) | Build=Speed(128k!) | @coder=Q8(64k) | @reviewer=70B Llama"
echo ""
echo "  --- STUDIO, SIDECARS & HARDWARE ---"
echo "  7) 🖥️ Tmux Split-Studio     -> Aktuellen Modus (${CURRENT_MODEL}) + Sidecar 1 (GPU) & 2 (Git) starten"
echo "  s) 🎛️ Sidecar-Manager (1-8) -> Alle 8 Sidecars (GPU, Git, Pytest, Logs, Browser, Plan, Mermaid, App) ein/aus"
echo "  8) 🪿 Goose CLI             -> Orchestrator Session starten"
echo "  9) 🔥 GPU-Boost / ❄️ Daily  -> Umschalten zwischen 230W Performance & 200W Silent"
echo "  0) 🧹 VRAM-Flush            -> Alle Modelle (Ollama + Port 5002 + ComfyUI) entladen"
read -rp "Auswahl [0-9/s]: " choice

case "$choice" in
    1)
        "${SCRIPT_DIR}/free_agent_vram.sh" --only-speedup
        set_single_model_mode "ollama/qwen3-coder-quality"
        cd "${LLM_ROOT}" && opencode
        ;;
    2)
        "${SCRIPT_DIR}/free_agent_vram.sh" --only-speedup
        set_single_model_mode "ollama/qwen3-coder-speed"
        cd "${LLM_ROOT}" && opencode
        ;;
    3)
        "${SCRIPT_DIR}/free_agent_vram.sh" --only-speedup
        set_single_model_mode "ollama/qwen3.8-35b-distill"
        cd "${LLM_ROOT}" && opencode
        ;;
    4)
        "${SCRIPT_DIR}/free_agent_vram.sh" --only-ollama
        set_single_model_mode "llama-speedup/qwen2.5-72b-speculative"
        cd "${LLM_ROOT}" && opencode
        ;;
    5)
        "${SCRIPT_DIR}/free_agent_vram.sh" --only-ollama
        set_single_model_mode "llama-speedup/llama3.3-70b-abliterated-speculative"
        cd "${LLM_ROOT}" && opencode
        ;;
    6)
        "${SCRIPT_DIR}/multimodel_project_workflow.sh"
        ;;
    7)
        echo -e "\n▶ Starte Tmux Sidecar-Studio '${SESSION_NAME}' mit ${CURRENT_MODEL}..."
        tmux kill-session -t "${SESSION_NAME}" 2>/dev/null || true
        tmux new-session -d -s "${SESSION_NAME}" -n "Studio" "cd '${LLM_ROOT}' && opencode"
        "${SCRIPT_DIR}/sidecar_manager.sh" 1 on
        "${SCRIPT_DIR}/sidecar_manager.sh" 2 on
        tmux select-pane -t "${SESSION_NAME}:Studio.0"
        tmux attach-session -t "${SESSION_NAME}"
        ;;
    s|S)
        "${SCRIPT_DIR}/sidecar_manager.sh" menu
        ;;
    8)
        cd "${LLM_ROOT}" && goose session
        ;;
    9)
        echo "1) 🔥 230W Performance + 65% Lüfter (-24°C Hotspot)"
        echo "2) ❄️ 200W Silent/Daily"
        read -rp "GPU-Modus [1-2]: " gchoice
        if [ "$gchoice" = "1" ]; then
            "${LLM_ROOT}/scripts/set-gpu-mode-performance.sh"
        else
            "${LLM_ROOT}/scripts/set-gpu-mode-daily.sh"
        fi
        ;;
    0)
        "${SCRIPT_DIR}/free_agent_vram.sh" --all
        ;;
    *)
        echo "Abgebrochen."
        exit 0
        ;;
esac
