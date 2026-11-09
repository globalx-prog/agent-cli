#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# 📱💻 Remote-Zugriff für Laptop & Smartphone (via Tailscale 100.x.y.z)
# ==============================================================================
# Modi:
#   ./scripts/remote_agent.sh tmux   -> Startet/verbindet persistente Tmux-Session (ideal für SSH / Termius)
#   ./scripts/remote_agent.sh web    -> Startet OpenCode Web-UI auf Tailscale-IP :4096 (ideal fürs Handy)
# ==============================================================================

export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${PATH}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LLM_ROOT="$(cd "${BASE_DIR}/.." && pwd)"
TAILSCALE_IP="${TAILSCALE_HOST_IP:-$(tailscale ip -4 2>/dev/null || echo '127.0.0.1')}"
WEB_PORT="4096"
SESSION_NAME="agent-remote"

MODE="${1:-menu}"

start_tmux_remote() {
    echo "🔗 Verbinde mit persistenter Remote-Tmux-Session '${SESSION_NAME}'..."
    "${SCRIPT_DIR}/free_agent_vram.sh" --only-speedup >/dev/null 2>&1 || true
    cd "${LLM_ROOT}"
    tmux new-session -A -s "${SESSION_NAME}" "opencode"
}

start_web_remote() {
    echo "======================================================================"
    echo "🌐 Starte OpenCode Mobile/Remote Web-UI (Tailscale-Only)"
    echo "======================================================================"
    echo "📱 Öffne auf deinem Handy oder Laptop (mit aktivem Tailscale):"
    echo "   👉 http://${TAILSCALE_IP}:${WEB_PORT}"
    echo "======================================================================"
    "${SCRIPT_DIR}/free_agent_vram.sh" --only-speedup >/dev/null 2>&1 || true
    cd "${LLM_ROOT}"
    opencode web --hostname "${TAILSCALE_IP}" --port "${WEB_PORT}"
}

case "$MODE" in
    tmux)
        start_tmux_remote
        ;;
    web)
        start_web_remote
        ;;
    *)
        echo "======================================================================"
        echo "📱💻 Remote-Agent Launcher (Laptop & Smartphone über Tailscale)"
        echo "======================================================================"
        echo "1) Tmux Persistent CLI (Ideal für Laptop-SSH & Handy-App 'Termius')"
        echo "2) OpenCode Web-UI     (Ideal für Handy-Browser unter http://${TAILSCALE_IP}:${WEB_PORT})"
        echo "3) Abbrechen"
        read -rp "Auswahl [1-3]: " rchoice
        case "$rchoice" in
            1) start_tmux_remote ;;
            2) start_web_remote ;;
            *) exit 0 ;;
        esac
        ;;
esac

