#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# 🔄 Autostart-Manager & Status-Check für Remote-Zugriff (Handy & Laptop)
# ==============================================================================
# Prüft, welche Dienste beim Systemstart von clemi-pc automatisch starten,
# und richtet auf Wunsch einen systemd-User-Service für 'opencode web'
# (http://<TAILSCALE_IP>:4096) ein, damit die Smartphone-Web-Oberfläche
# nach jedem PC-Neustart sofort erreichbar ist.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLM_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SERVICE_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${SERVICE_DIR}/opencode-web.service"
TAILSCALE_IP="${TAILSCALE_HOST_IP:-$(tailscale ip -4 2>/dev/null || echo '127.0.0.1')}"
WEB_PORT="4096"

show_status() {
    echo "======================================================================"
    echo "🔍 AUTOSTART- & DIENSTE-STATUS AUF CLEMI-PC"
    echo "======================================================================"
    printf "  %-28s | %-18s | %s\n" "Dienst / Komponente" "Boot-Autostart" "Aktueller Status"
    echo "----------------------------------------------------------------------"

    # 1. Tailscale VPN
    TS_EN=$(systemctl is-enabled tailscaled 2>/dev/null || echo "disabled")
    TS_ACT=$(systemctl is-active tailscaled 2>/dev/null || echo "inactive")
    printf "  %-28s | %-18s | %s\n" "Tailscale VPN (${TAILSCALE_IP})" "${TS_EN}" "${TS_ACT}"

    # 2. SSH Server (Port 22 für Laptop & Termius)
    SSH_EN=$(systemctl is-enabled ssh 2>/dev/null || systemctl is-enabled ssh.socket 2>/dev/null || echo "disabled")
    SSH_ACT=$(systemctl is-active ssh 2>/dev/null || systemctl is-active ssh.socket 2>/dev/null || echo "inactive")
    printf "  %-28s | %-18s | %s\n" "SSH Server (Port 22)" "${SSH_EN}" "${SSH_ACT}"

    # 2. Ollama (Port 11434)
    OL_EN=$(systemctl is-enabled ollama 2>/dev/null || echo "disabled")
    OL_ACT=$(systemctl is-active ollama 2>/dev/null || echo "inactive")
    printf "  %-28s | %-18s | %s\n" "Ollama Server (Port 11434)" "${OL_EN}" "${OL_ACT}"

    # 3. Docker Engine (für SearXNG, llama-speedup, Open WebUI)
    DK_EN=$(systemctl is-enabled docker 2>/dev/null || echo "disabled")
    DK_ACT=$(systemctl is-active docker 2>/dev/null || echo "inactive")
    printf "  %-28s | %-18s | %s\n" "Docker Daemon (Container)" "${DK_EN}" "${DK_ACT}"

    # 4. SearXNG (Port 8081)
    if curl -s -m 2 http://127.0.0.1:8081 >/dev/null 2>&1; then
        SX_ACT="active (Port 8081)"
    else
        SX_ACT="inactive"
    fi
    printf "  %-28s | %-18s | %s\n" "SearXNG Suche (Docker)" "unless-stopped" "${SX_ACT}"

    # 5. llama-speedup (Port 5002)
    if curl -s -m 2 http://127.0.0.1:5002/running >/dev/null 2>&1; then
        SP_ACT="active (Port 5002)"
    else
        SP_ACT="inactive"
    fi
    printf "  %-28s | %-18s | %s\n" "llama-speedup (Docker)" "unless-stopped" "${SP_ACT}"

    # 6. OpenCode Web-UI (Port 4096 fürs Handy)
    if [ -f "${SERVICE_FILE}" ]; then
        OW_EN=$(systemctl --user is-enabled opencode-web.service 2>/dev/null || echo "disabled")
        OW_ACT=$(systemctl --user is-active opencode-web.service 2>/dev/null || echo "inactive")
    else
        OW_EN="nicht installiert"
        if pgrep -f "opencode web" >/dev/null 2>&1; then
            OW_ACT="manuell aktiv"
        else
            OW_ACT="inaktiv"
        fi
    fi
    printf "  %-28s | %-18s | %s\n" "OpenCode Handy-Web (Port 4096)" "${OW_EN}" "${OW_ACT}"
    echo "======================================================================"
}

install_autostart() {
    mkdir -p "${SERVICE_DIR}"
    cat << EOF > "${SERVICE_FILE}"
[Unit]
Description=OpenCode Remote Web-UI (Tailscale ${TAILSCALE_IP}:${WEB_PORT})
After=network-online.target

[Service]
Type=simple
WorkingDirectory=${LLM_ROOT}
Environment="PATH=${HOME}/.opencode/bin:${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=${HOME}/.opencode/bin/opencode web --hostname ${TAILSCALE_IP} --port ${WEB_PORT}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now opencode-web.service
    echo "✅ Autostart für OpenCode Handy-Webserver eingerichtet und gestartet!"
    echo "📱 Ab sofort erreichbar unter: http://${TAILSCALE_IP}:${WEB_PORT}"
    echo "💡 Tipp: Damit User-Services auch nach einem Reboot OHNE lokales Einloggen"
    echo "   sofort starten, einmalig ausführen: sudo loginctl enable-linger ${USER}"
}

remove_autostart() {
    systemctl --user disable --now opencode-web.service 2>/dev/null || true
    rm -f "${SERVICE_FILE}"
    systemctl --user daemon-reload 2>/dev/null || true
    echo "🛑 Autostart für OpenCode Handy-Webserver deaktiviert und entfernt."
}

case "${1:-status}" in
    status)
        show_status
        ;;
    enable|install)
        install_autostart
        show_status
        ;;
    disable|remove)
        remove_autostart
        show_status
        ;;
    *)
        echo "Verwendung: $0 {status|enable|disable}"
        exit 1
        ;;
esac

