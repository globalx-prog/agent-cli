#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# 🎛️ Zentraler Sidecar-Manager (Alle 8 Sidecars einzeln oder kombiniert steuern)
# ==============================================================================
# Verwendung:
#   ./scripts/sidecar_manager.sh                    -> Interaktives Toggle-Menü
#   ./scripts/sidecar_manager.sh status             -> Zeigt Status aller 8 Sidecars
#   ./scripts/sidecar_manager.sh <1..8|name> on     -> Einzelnes Sidecar aktivieren
#   ./scripts/sidecar_manager.sh <1..8|name> off    -> Einzelnes Sidecar deaktivieren
#   ./scripts/sidecar_manager.sh <1..8|name> toggle -> Einzelnes Sidecar umschalten
#   ./scripts/sidecar_manager.sh all-on             -> Alle empfohlenen Sidecars starten
#   ./scripts/sidecar_manager.sh all-off            -> Alle Sidecars sofort beenden
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LLM_ROOT="$(cd "${BASE_DIR}/.." && pwd)"
OPENCODE_CFG="${BASE_DIR}/configs/opencode.json"
CODING_WT="${BASE_DIR}/projects/worktrees/coding"
TESTING_WT="${BASE_DIR}/projects/worktrees/testing"
PID_DIR="/tmp/opencode-sidecars"
mkdir -p "${PID_DIR}"

# Ermittle aktive Tmux-Session (falls vorhanden)
get_tmux_session() {
    if [ -n "${TMUX:-}" ]; then
        tmux display-message -p '#S' 2>/dev/null || echo ""
    elif tmux has-session -t "agent-workspace" 2>/dev/null; then
        echo "agent-workspace"
    elif tmux has-session -t "agent-remote" 2>/dev/null; then
        echo "agent-remote"
    else
        echo ""
    fi
}

# Prüft, ob ein Tmux-Pane mit bestimmtem Titel (@sidecar_id) existiert
find_tmux_pane() {
    local sc_id="$1"
    local sess
    sess="$(get_tmux_session)"
    [ -z "$sess" ] && return 1
    tmux list-panes -t "$sess" -F "#{pane_id} #{@sidecar_id}" 2>/dev/null | awk -v id="$sc_id" '$2 == id {print $1; exit}'
}

start_tmux_sidecar_pane() {
    local sc_id="$1"
    local title="$2"
    local cmd="$3"
    local sess
    sess="$(get_tmux_session)"

    if [ -z "$sess" ]; then
        echo "ℹ️ Keine aktive Tmux-Session gefunden – erstelle Tmux-Session 'agent-workspace'..."
        sess="agent-workspace"
        tmux new-session -d -s "$sess" -n "Studio" "cd '${LLM_ROOT}' && ${HOME}/.opencode/bin/opencode"
    fi

    local existing_pane
    existing_pane="$(find_tmux_pane "$sc_id" || true)"
    if [ -n "$existing_pane" ]; then
        echo "✅ Sidecar '${title}' läuft bereits in Tmux-Pane ${existing_pane}."
        return 0
    fi

    # Wenn bisher nur 1 Pane existiert -> horizontal rechts splitten (38% Breite), sonst vertikal rechts stapeln
    local pane_count
    pane_count="$(tmux list-panes -t "$sess" 2>/dev/null | wc -l)"
    local new_pane
    if [ "$pane_count" -le 1 ]; then
        new_pane="$(tmux split-window -d -P -F "#{pane_id}" -h -p 38 -t "$sess" "$cmd")"
    else
        local last_pane
        last_pane="$(tmux list-panes -t "$sess" -F "#{pane_id}" | tail -n 1)"
        new_pane="$(tmux split-window -d -P -F "#{pane_id}" -v -p 45 -t "$last_pane" "$cmd")"
    fi
    tmux set-option -p -t "$new_pane" @sidecar_id "$sc_id" >/dev/null 2>&1 || true
    echo "✅ Sidecar '${title}' aktiviert (Tmux-Pane ${new_pane} in Session '${sess}')."
}

stop_tmux_sidecar_pane() {
    local sc_id="$1"
    local title="$2"
    local existing_pane
    existing_pane="$(find_tmux_pane "$sc_id" || true)"
    if [ -n "$existing_pane" ]; then
        tmux kill-pane -t "$existing_pane" 2>/dev/null || true
        echo "🛑 Sidecar '${title}' deaktiviert (Pane ${existing_pane} geschlossen)."
    else
        echo "ℹ️ Sidecar '${title}' war nicht aktiv."
    fi
}

# ==============================================================================
# Status-Prüfungen für Sidecar 1 bis 8
# ==============================================================================
is_sc_active() {
    local target="$1"
    case "$target" in
        1|gpu)                [ -n "$(find_tmux_pane "SC1_GPU" || true)" ] ;;
        2|git)                [ -n "$(find_tmux_pane "SC2_GIT" || true)" ] ;;
        3|test|pytest)        [ -n "$(find_tmux_pane "SC3_TEST" || true)" ] ;;
        4|speed|logs)         [ -n "$(find_tmux_pane "SC4_SPEED" || true)" ] ;;
        5|browser|playwright) ! grep -q '"--headless"' "${OPENCODE_CFG}" 2>/dev/null ;;
        6|plan)               [ -n "$(find_tmux_pane "SC6_PLAN" || true)" ] ;;
        7|docs|mermaid)       [ -f "${PID_DIR}/sc7_docs.pid" ] && kill -0 "$(cat "${PID_DIR}/sc7_docs.pid" 2>/dev/null)" 2>/dev/null ;;
        8|app|preview)        [ -f "${PID_DIR}/sc8_app.pid" ] && kill -0 "$(cat "${PID_DIR}/sc8_app.pid" 2>/dev/null)" 2>/dev/null ;;
        *) return 1 ;;
    esac
}

# ==============================================================================
# Aktivieren / Deaktivieren der 8 Sidecars
# ==============================================================================
enable_sidecar() {
    local target="$1"
    case "$target" in
        1|gpu)
            start_tmux_sidecar_pane "SC1_GPU" "1: W7800 GPU & VRAM Monitor" \
                "watch -n 2 '${LLM_ROOT}/scripts/gpu-status.sh'"
            ;;
        2|git)
            start_tmux_sidecar_pane "SC2_GIT" "2: Live Git-Diff & Worktree-Radar" \
                "watch -n 2 --color 'echo \"=== 📂 WORKTREE: CODING ===\" && git -C \"${CODING_WT}\" status -sb 2>/dev/null && git -C \"${CODING_WT}\" diff --stat --color=always 2>/dev/null; echo \"\n=== 📂 HAUPT-REPO ===\" && git -C \"${BASE_DIR}\" status -sb 2>/dev/null'"
            ;;
        3|test|pytest)
            start_tmux_sidecar_pane "SC3_TEST" "3: Kontinuierlicher TDD-Pytest-Runner" \
                "watch -n 3 --color 'echo \"=== 🧪 TDD PYTEST SIDECAR ===\"; pytest --color=yes \"${TESTING_WT}\" \"${CODING_WT}\" 2>/dev/null || echo \"ℹ️ Noch keine test_*.py Dateien in testing/ oder coding/ gefunden.\"'"
            ;;
        4|speed|logs)
            start_tmux_sidecar_pane "SC4_SPEED" "4: Live Token-Speed & Inferenz-Telemetrie" \
                "watch -n 2 'echo \"=== ⚡ OLLAMA VRAM STATUS ===\"; ollama ps 2>/dev/null; echo \"\n=== 🚀 LLAMA-SPEEDUP LOGS (Port 5002) ===\"; docker logs --tail 12 llama-speedup 2>&1 || true'"
            ;;
        5|browser|playwright)
            python3 -c "
import json
p = '${OPENCODE_CFG}'
with open(p, 'r', encoding='utf-8') as f:
    cfg = json.load(f)
cmd = cfg['mcp']['playwright']['command']
cfg['mcp']['playwright']['command'] = [x for x in cmd if x != '--headless']
with open(p, 'w', encoding='utf-8') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write('\n')
"
            echo "✅ Sidecar 5 (Playwright Sichtbares Browser-Sidecar) AKTIVIERT ('--headless' entfernt)."
            echo "   Beim nächsten '/webtest' öffnet sich Chromium live auf deinem Desktop!"
            ;;
        6|plan)
            start_tmux_sidecar_pane "SC6_PLAN" "6: Live PLAN.md Checklisten-Monitor" \
                "watch -n 2 'echo \"=== 📋 LIVE PLAN.MD TRACKER ===\"; cat \"${CODING_WT}/PLAN.md\" 2>/dev/null || cat \"${BASE_DIR}/PLAN.md\" 2>/dev/null || echo \"Noch keine PLAN.md vorhanden. Starte mit /plan ...\"'"
            ;;
        7|docs|mermaid)
            local ts_ip
            ts_ip="$(tailscale ip -4 2>/dev/null || echo '100.x.y.z')"
            if is_sc_active 7; then
                echo "✅ Sidecar 7 (Live Mermaid & Docs Viewer) läuft bereits auf http://127.0.0.1:4097"
            else
                nohup python3 "${SCRIPT_DIR}/live_mermaid_sidecar.py" >/dev/null 2>&1 &
                echo $! > "${PID_DIR}/sc7_docs.pid"
                echo "✅ Sidecar 7 (Live Mermaid & PLAN.md Web-Viewer) AKTIVIERT:"
                echo "   👉 Lokal:     http://127.0.0.1:4097"
                echo "   👉 Tailscale: http://${ts_ip}:4097"
            fi
            ;;
        8|app|preview)
            local ts_ip
            ts_ip="$(tailscale ip -4 2>/dev/null || echo '100.x.y.z')"
            if is_sc_active 8; then
                echo "✅ Sidecar 8 (Live App-Preview Server) läuft bereits auf http://127.0.0.1:8090"
            else
                mkdir -p "${CODING_WT}"
                nohup python3 -m http.server 8090 --directory "${CODING_WT}" >/dev/null 2>&1 &
                echo $! > "${PID_DIR}/sc8_app.pid"
                echo "✅ Sidecar 8 (Live Worktree Web-Preview Server) AKTIVIERT:"
                echo "   👉 Lokal:     http://127.0.0.1:8090 (Verzeichnis: worktrees/coding/)"
                echo "   👉 Tailscale: http://${ts_ip}:8090"
            fi
            ;;
        *)
            echo "❌ Unbekanntes Sidecar: '$target' (Erlaubt: 1..8 oder gpu|git|test|speed|browser|plan|docs|app)"
            exit 1
            ;;
    esac
}

disable_sidecar() {
    local target="$1"
    case "$target" in
        1|gpu)
            stop_tmux_sidecar_pane "SC1_GPU" "1: W7800 GPU & VRAM Monitor"
            ;;
        2|git)
            stop_tmux_sidecar_pane "SC2_GIT" "2: Live Git-Diff & Worktree-Radar"
            ;;
        3|test|pytest)
            stop_tmux_sidecar_pane "SC3_TEST" "3: Kontinuierlicher TDD-Pytest-Runner"
            ;;
        4|speed|logs)
            stop_tmux_sidecar_pane "SC4_SPEED" "4: Live Token-Speed & Inferenz-Telemetrie"
            ;;
        5|browser|playwright)
            python3 -c "
import json
p = '${OPENCODE_CFG}'
with open(p, 'r', encoding='utf-8') as f:
    cfg = json.load(f)
cmd = cfg['mcp']['playwright']['command']
if '--headless' not in cmd:
    idx = cmd.index('--no-sandbox') if '--no-sandbox' in cmd else len(cmd)
    cmd.insert(idx, '--headless')
with open(p, 'w', encoding='utf-8') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write('\n')
"
            echo "🛑 Sidecar 5 (Playwright Sichtbares Browser-Sidecar) DEAKTIVIERT (läuft wieder '--headless' im Hintergrund)."
            ;;
        6|plan)
            stop_tmux_sidecar_pane "SC6_PLAN" "6: Live PLAN.md Checklisten-Monitor"
            ;;
        7|docs|mermaid)
            if [ -f "${PID_DIR}/sc7_docs.pid" ]; then
                kill "$(cat "${PID_DIR}/sc7_docs.pid")" 2>/dev/null || true
                rm -f "${PID_DIR}/sc7_docs.pid"
            fi
            pkill -f "live_mermaid_sidecar.py" 2>/dev/null || true
            echo "🛑 Sidecar 7 (Live Mermaid & Docs Viewer Port 4097) DEAKTIVIERT."
            ;;
        8|app|preview)
            if [ -f "${PID_DIR}/sc8_app.pid" ]; then
                kill "$(cat "${PID_DIR}/sc8_app.pid")" 2>/dev/null || true
                rm -f "${PID_DIR}/sc8_app.pid"
            fi
            echo "🛑 Sidecar 8 (Live App-Preview Server Port 8090) DEAKTIVIERT."
            ;;
        *)
            echo "❌ Unbekanntes Sidecar: '$target'"
            exit 1
            ;;
    esac
}

toggle_sidecar() {
    local num="$1"
    if is_sc_active "$num"; then
        disable_sidecar "$num"
    else
        enable_sidecar "$num"
    fi
}

show_status() {
    local sess
    sess="$(get_tmux_session)"
    echo "======================================================================"
    echo "🎛️ SIDECAR-MANAGER — STATUS ALLER 8 SIDECARS (Tmux: ${sess:-keine aktiv})"
    echo "======================================================================"
    local names=(
        ""
        "1) 🌡️  gpu     — W7800 GPU-, VRAM- & Thermik-Monitor (Tmux-Pane)"
        "2) 🌳 git     — Live-Git-Diff & Worktree-Radar      (Tmux-Pane)"
        "3) 🧪 test    — Kontinuierlicher TDD-Pytest-Runner  (Tmux-Pane)"
        "4) 🚀 speed   — Token-Speed & Speculative-Logs      (Tmux-Pane)"
        "5) 🌐 browser — Playwright Sichtbares Browserfenster (Headed Mode)"
        "6) 📋 plan    — Live PLAN.md Checklisten-Tracker    (Tmux-Pane)"
        "7) 📊 docs    — Live Mermaid & Markdown Web-Viewer  (Port 4097)"
        "8) 🔬 app     — Live Worktree Web-Preview Server    (Port 8090)"
    )
    for i in {1..8}; do
        if is_sc_active "$i"; then
            printf "  [🟢 AKTIV  ] %s\n" "${names[$i]}"
        else
            printf "  [⚪ INAKTIV] %s\n" "${names[$i]}"
        fi
    done
    echo "======================================================================"
    echo "💡 Befehle: ./scripts/sidecar_manager.sh <1..8|name> {on|off|toggle}"
}

ARG1="${1:-menu}"
ARG2="${2:-toggle}"

case "$ARG1" in
    status)
        show_status
        ;;
    all-on)
        enable_sidecar 1
        enable_sidecar 2
        enable_sidecar 7
        enable_sidecar 8
        show_status
        ;;
    all-off)
        for i in {1..8}; do disable_sidecar "$i" >/dev/null 2>&1 || true; done
        echo "🛑 Alle 8 Sidecars wurden deaktiviert."
        show_status
        ;;
    1|2|3|4|5|6|7|8|gpu|git|test|pytest|speed|logs|browser|playwright|plan|docs|mermaid|app|preview)
        case "$ARG2" in
            on|enable|start)   enable_sidecar "$ARG1" ;;
            off|disable|stop)  disable_sidecar "$ARG1" ;;
            toggle)            toggle_sidecar "$ARG1" ;;
            *)                 enable_sidecar "$ARG1" ;;
        esac
        ;;
    menu|*)
        while true; do
            echo ""
            show_status
            echo "  a) 🚀 Empfohlenes Sidecar-Set aktivieren (1: GPU + 2: Git + 7: Mermaid-Web + 8: App-Preview)"
            echo "  x) 🛑 Alle Sidecars sofort deaktivieren (all-off)"
            echo "  t) 🖥️ In aktive Tmux-Session ('$(get_tmux_session)') wechseln (attach)"
            echo "  q) Beenden"
            read -rp "Sidecar [1-8] zum Umschalten (on/off) oder [a/x/t/q]: " schoice
            case "$schoice" in
                [1-8]) toggle_sidecar "$schoice" ;;
                a|A)   enable_sidecar 1; enable_sidecar 2; enable_sidecar 7; enable_sidecar 8 ;;
                x|X)   for i in {1..8}; do disable_sidecar "$i" >/dev/null 2>&1 || true; done ;;
                t|T)
                    sess="$(get_tmux_session)"
                    if [ -n "$sess" ]; then
                        tmux attach-session -t "$sess"
                        break
                    else
                        echo "ℹ️ Noch keine Tmux-Session aktiv (aktiviere zuerst Sidecar 1, 2, 3, 4 oder 6)."
                    fi
                    ;;
                q|Q|"") break ;;
                *) echo "Ungültige Eingabe." ;;
            esac
        done
        ;;
esac
