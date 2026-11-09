#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# 🏆 Multi-Model-Großprojekt-Workflow (Maximale Ergebnisqualität durch Spezialisten)
# ==============================================================================
# Hintergrund:
#   Für schnelle Alltagsaufgaben nutzt man 1 Modell für alle Rollen (0s Wechselzeit).
#   Für GROSSE PROJEKTE erzielt man jedoch ein deutlich besseres Ergebnis, wenn
#   jede Phase von dem dafür besten Spezial-Modell (und einer zweiten Modellfamilie
#   für das Vier-Augen-Review) bearbeitet wird:
#
#   1. @planner  -> Deep Reasoning / Architektur (deepseek-r1-70b-speed oder qwen3.8-35b-distill 64k)
#   2. Build     -> Großer 64k-Dateikontext & Überblick (qwen3-coder-speed, 64k Ctx, 80.6 t/s)
#   3. @coder    -> Verlustfreie Q8-Code-Generierung (qwen3-coder-quality, Q8_0, 62.7 t/s)
#   4. @tester   -> Präzises Playwright- & Pytest-Tool-Calling (qwen3-coder-quality, Q8_0)
#   5. @reviewer -> Unabhängige 2. Modellfamilie für Vier-Augen-Audit (llama3.3-70b-abliterated-speed)
# ==============================================================================

export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${PATH}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LLM_ROOT="$(cd "${BASE_DIR}/.." && pwd)"
OPENCODE_CFG="${BASE_DIR}/configs/opencode.json"
AGENTS_DIR="${BASE_DIR}/configs/agents"

set_agent_model() {
    local agent_file="$1"
    local model_id="$2"
    python3 -c "
import re
path = '${agent_file}'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Entferne vorhandene model:-Zeile im YAML-Frontmatter
content = re.sub(r'^model:.*\n', '', content, flags=re.MULTILINE)

if '${model_id}':
    # Füge model: direkt nach mode: all ein
    content = re.sub(r'^(mode:\s*all\s*\n)', r'\1model: ${model_id}\n', content, count=1, flags=re.MULTILINE)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
"
}

enable_multimodel_agents() {
    local planner_model="${1:-ollama/deepseek-r1-70b-speed}"
    echo "======================================================================"
    echo "🏆 Aktiviere Multi-Model-Spezialisten-Belegung (Vier-Augen-Workflow)"
    echo "======================================================================"
    "${SCRIPT_DIR}/free_agent_vram.sh" --only-speedup

    # Hauptagent auf 64k Großkontext-Coder setzen, small_model ebenfalls darauf lassen
    python3 -c "
import json
path = '${OPENCODE_CFG}'
with open(path, 'r', encoding='utf-8') as f:
    cfg = json.load(f)
cfg['model'] = 'ollama/qwen3-coder-speed'
cfg['small_model'] = 'ollama/qwen3-coder-speed'
with open(path, 'w', encoding='utf-8') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write('\n')
"
    set_agent_model "${AGENTS_DIR}/planner.md"  "${planner_model}"
    set_agent_model "${AGENTS_DIR}/coder.md"    "ollama/qwen3-coder-quality"
    set_agent_model "${AGENTS_DIR}/tester.md"   "ollama/qwen3-coder-quality"
    set_agent_model "${AGENTS_DIR}/reviewer.md" "ollama/llama3.3-70b-abliterated-speed"

    echo "  🧠 @planner  (Architektur)       -> ${planner_model}"
    echo "  📂 Build     (64k Großkontext)   -> ollama/qwen3-coder-speed (64k Ctx, 80.6 t/s)"
    echo "  💻 @coder    (Q8 Präzisionscode) -> ollama/qwen3-coder-quality (Q8_0, 62.7 t/s)"
    echo "  🧪 @tester   (Playwright/Pytest) -> ollama/qwen3-coder-quality (Q8_0, 62.7 t/s)"
    echo "  🔍 @reviewer (Vier-Augen-70B)    -> ollama/llama3.3-70b-abliterated-speed (Llama 70B)"
    echo "======================================================================"
    echo "ℹ️ Hinweis: Beim Wechsel zwischen @planner -> @coder -> @reviewer lädt"
    echo "   Ollama das jeweilige Spezialmodell frisch in die 48 GB VRAM (~10-15s)."
}

reset_to_single_model() {
    set_agent_model "${AGENTS_DIR}/planner.md"  ""
    set_agent_model "${AGENTS_DIR}/coder.md"    ""
    set_agent_model "${AGENTS_DIR}/tester.md"   ""
    set_agent_model "${AGENTS_DIR}/reviewer.md" ""
}

run_guided_4phase_pipeline() {
    echo "======================================================================"
    echo "🚀 Geführter 4-Phasen-Staffellauf für Großprojekte (Multi-Backend)"
    echo "======================================================================"
    echo "Dieser Workflow kombiniert Port 5002 (72B Speculative) und Port 11434"
    echo "(64k Qwen3 Coder Speed + Q8 Quality) ohne VRAM-Kollisionen:"
    echo ""
    echo "  [Phase 1] 👑 Architektur & PLAN.md mit Qwen 2.5 72B Speculative (33.6 t/s)"
    echo "  [Phase 2] ⚡ 64k Kontext-Analyse & Modul-Bau mit Qwen 3 Coder Speed (64k Ctx)"
    echo "  [Phase 3] 💻 Feinschliff & Playwright/Pytest mit Qwen 3 Coder Quality (Q8_0)"
    echo "  [Phase 4] 🔓 Unabhängiges 70B Vier-Augen-Review mit Llama 3.3 70B Speculative"
    echo "======================================================================"
    read -rp "Mit Phase 1 (72B Architektur-Planung) starten? [J/n]: " confirm
    if [[ "${confirm:-J}" =~ ^[Nn]$ ]]; then
        exit 0
    fi

    echo -e "\n▶ [Phase 1/4] Lade 72B Speculative Flaggschiff (Port 5002)..."
    reset_to_single_model
    "${SCRIPT_DIR}/free_agent_vram.sh" --only-ollama
    python3 -c "
import json
p='${OPENCODE_CFG}'; c=json.load(open(p))
c['model']='llama-speedup/qwen2.5-72b-speculative'
c['small_model']='llama-speedup/qwen2.5-72b-speculative'
json.dump(c,open(p,'w'),indent=2,ensure_ascii=False)
"
    echo "💡 Tipp für Phase 1: Lass den Agenten eine 'PLAN.md' mit Checkboxen erstellen, danach OpenCode mit '/exit' schließen, um automatisch in Phase 2 zu wechseln!"
    read -rp "Drücke [Enter], um OpenCode für Phase 1 zu öffnen..."
    (cd "${LLM_ROOT}" && opencode)

    echo -e "\n▶ [Phase 2/4] Wechsel auf 64k Großkontext-Coder (ollama/qwen3-coder-speed)..."
    "${SCRIPT_DIR}/free_agent_vram.sh" --only-speedup
    python3 -c "
import json
p='${OPENCODE_CFG}'; c=json.load(open(p))
c['model']='ollama/qwen3-coder-speed'
c['small_model']='ollama/qwen3-coder-speed'
json.dump(c,open(p,'w'),indent=2,ensure_ascii=False)
"
    echo "💡 Tipp für Phase 2: Nutze den großen 64k-Kontext, um mehrere Projektskripte einzulesen und das Grundgerüst aus PLAN.md zu bauen. Schließe danach mit '/exit'."
    read -rp "Drücke [Enter], um OpenCode für Phase 2 (64k Speed) zu öffnen..."
    (cd "${LLM_ROOT}" && opencode)

    echo -e "\n▶ [Phase 3/4] Wechsel auf Q8 Präzisions-Coder & Tester (ollama/qwen3-coder-quality)..."
    python3 -c "
import json
p='${OPENCODE_CFG}'; c=json.load(open(p))
c['model']='ollama/qwen3-coder-quality'
c['small_model']='ollama/qwen3-coder-quality'
json.dump(c,open(p,'w'),indent=2,ensure_ascii=False)
"
    echo "💡 Tipp für Phase 3: Nutze '@coder' und '@tester' (oder '/webtest') für Q8-Feinschliff und Tests. Schließe danach mit '/exit'."
    read -rp "Drücke [Enter], um OpenCode für Phase 3 (Q8 Quality & Tests) zu öffnen..."
    (cd "${LLM_ROOT}" && opencode)

    echo -e "\n▶ [Phase 4/4] Wechsel auf 70B Vier-Augen-Auditor (llama3.3-70b-abliterated-speculative)..."
    "${SCRIPT_DIR}/free_agent_vram.sh" --only-ollama
    python3 -c "
import json
p='${OPENCODE_CFG}'; c=json.load(open(p))
c['model']='llama-speedup/llama3.3-70b-abliterated-speculative'
c['small_model']='llama-speedup/llama3.3-70b-abliterated-speculative'
json.dump(c,open(p,'w'),indent=2,ensure_ascii=False)
"
    echo "💡 Tipp für Phase 4: Führe '/review' auf die geänderten Dateien aus – jetzt prüft ein 70B-Llama-Modell deinen Qwen-Code im echten Vier-Augen-Prinzip!"
    read -rp "Drücke [Enter], um OpenCode für Phase 4 (70B Audit) zu öffnen..."
    (cd "${LLM_ROOT}" && opencode)
}

ACTION="${1:-menu}"
case "$ACTION" in
    enable)
        enable_multimodel_agents "${2:-ollama/deepseek-r1-70b-speed}"
        ;;
    enable-next80b)
        enable_multimodel_agents "ollama/next80b-32k"
        ;;
    reset)
        reset_to_single_model
        echo "✅ Alle @Subagents erben wieder das Einheits-Modell aus opencode.json (0s Wechselzeit)."
        ;;
    pipeline)
        run_guided_4phase_pipeline
        ;;
    *)
        echo "======================================================================"
        echo "🏆 Multi-Model-Workflow für Großprojekte (W7800 48 GB)"
        echo "======================================================================"
        echo "  1) Multi-Model-Agenten aktivieren (DeepSeek-R1-70B Planer + 64k Speed + Q8 Coder + 70B Llama Reviewer)"
        echo "  2) Multi-Model-Agenten mit Qwen3-Next-80B als Planer aktivieren"
        echo "  3) Geführter 4-Phasen-Staffellauf (72B Speculative -> 64k Speed -> Q8 Quality -> 70B Audit)"
        echo "  4) Zurücksetzen auf 1-Modell-pro-Modus (0s Wechselzeit)"
        echo "  5) Abbrechen"
        read -rp "Auswahl [1-5]: " mchoice
        case "$mchoice" in
            1) enable_multimodel_agents "ollama/deepseek-r1-70b-speed" && cd "${LLM_ROOT}" && opencode ;;
            2) enable_multimodel_agents "ollama/next80b-32k" && cd "${LLM_ROOT}" && opencode ;;
            3) run_guided_4phase_pipeline ;;
            4) reset_to_single_model ;;
            *) exit 0 ;;
        esac
        ;;
esac

