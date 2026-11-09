# 🛡️ Netzwerk-Architektur: Tailscale, Cloudflare Zero Trust & Datenschutz
## Klare Trennung von Remote-CLI, Web-Ingress und strikter Zero-Data-Egress-Richtlinie

> **Host:** `clemi-pc` (Ubuntu Linux)  
> **Tailscale IP:** `100.x.y.z` (Privates WireGuard Mesh)  
> **Cloudflare Host:** `openwebui.deine-domain.de` (Zero Trust Tunnel)  
> **Lokales Docker-Netz:** `ai-network` (SearXNG Port 8081, Open WebUI Port 3000)

---

## 🏛️ 1. Die Rollenteilung: Warum Tailscale für CLI und Cloudflare für WebUI?

Eine zentrale Architekturentscheidung für maximale Sicherheit und Zuverlässigkeit:

```text
               ┌────────────────────────────────────────────────────────┐
               │                  CLIENT-ZUGRIFFSEBENE                  │
               └───────────────────────────┬────────────────────────────┘
                                           │
                    ┌──────────────────────┴──────────────────────┐
                    ▼                                             ▼
       ┌────────────────────────┐                    ┌────────────────────────┐
       │     Tailscale VPN      │                    │ Cloudflare Zero Trust  │
       │   (100.x.y.z)     │                    │  (deine-domain.de)      │
       └────────────┬───────────┘                    └────────────┬───────────┘
                    │                                             │
      E2E WireGuard │ Kein Payload-Limit            HTTPS Ingress │ 100s Timeout
      Direktes P2P  │ Perfekt für Terminal/SSH      Zero Trust ID │ WebUI-Only
                    │                                             │
                    ▼                                             ▼
       ┌────────────────────────┐                    ┌────────────────────────┐
       │   Agent-CLI & Daemon   │                    │  Open WebUI (Docker)   │
       │   (OpenCode / Goose)   │                    │  (Port 3000 / 8080)    │
       └────────────┬───────────┘                    └────────────┬───────────┘
                    │                                             │
                    └──────────────────────┬──────────────────────┘
                                           ▼
                    ┌─────────────────────────────────────────────┐
                    │     Host-Systemd & Inferenz (W7800 VRAM)     │
                    │   • Ollama (11434)  • llama.cpp (8080)      │
                    │   • SearXNG (8081)  • Playwright MCP        │
                    └─────────────────────────────────────────────┘
```

### Warum Cloudflare Tunnel NICHT für Agent-CLIs genutzt werden sollte:
1. **HTTP Proxy Timeout (100 Sekunden):**  
   Cloudflare Tunnels brechen Verbindungen nach 100 Sekunden ohne Antwort ab. Wenn ein 70B-Modell (DeepSeek R1) komplexe CoT-Reasoning-Gedankengänge über 2 Minuten generiert, reißt der Cloudflare-Tunnel ab (504 Gateway Timeout).
2. **Body Size Limits:**  
   Cloudflare begrenzt Uploads (Free: 100 MB). Große Datei-Diffs oder AST-Mappings im Agentenverkehr können blockiert werden.
3. **Datenschutz:**  
   Cloudflare terminiert TLS an der Edge. Für maximale Privatsphäre sollten vertraulicher Quellcode und Agenten-Prompts niemals über Cloudflare-Server fließen.

### Warum Tailscale der perfekte Kanal für die Agent-CLI ist:
1. **Ende-zu-Ende verschlüsseltes WireGuard:**  
   Direkte Punkt-zu-Punkt-Verbindung zwischen deinem mobilen Gerät (z. B. Laptop/iPad) und `clemi-pc`. Kein Dritter hat Einsicht in den Datenstrom.
2. **Native Terminal-Sitzungen (Tailscale SSH):**  
   Ermöglicht das nahtlose Starten und Wiederaufnehmen von persistenten Tmux-Sitzungen (`opencode`, `goose`) von überall auf der Welt mit null Latenz.
3. **Keine offenen WAN-Ports:**  
   Deine Fritz!Box / dein Router benötigt keinerlei Portweiterleitungen nach außen.

---

## 🔒 2. Zero-Data-Egress: Technische Absicherung

Um zu garantieren, dass kein lokaler Code ungewollt ins Internet gelangt, greifen folgende Maßnahmen:

### A. Ollama Binding
In `/etc/systemd/system/ollama.service.d/override.conf`:
- Lauscht auf `100.x.y.z:11434` (Tailscale) und `127.0.0.1:11434` (Host Loopback).
- Keinerlei Bindung an öffentliche Interfaces.

### B. UFW Firewall Regeln
Sicherstellen, dass die Inferenz-Ports nur aus dem Tailnet erreichbar sind:
```bash
# Zugriff auf Ollama nur von Tailscale-Clients erlauben:
sudo ufw allow in on tailscale0 to any port 11434 proto tcp
sudo ufw allow in on tailscale0 to any port 8080 proto tcp

# Öffentlichen LAN-Zugriff auf Inferenz blockieren:
sudo ufw deny in on eth0 to any port 11434 proto tcp
sudo ufw deny in on eth0 to any port 8080 proto tcp
```

### C. OpenCode & Goose Permissions
In `configs/opencode.json` sind alle unkontrollierten Web-Zugriffe standardmäßig gesperrt:
```json
"permission": {
  "edit": "ask",
  "bash": "ask",
  "external_directory": "ask",
  "webfetch": "deny",
  "websearch": "deny"
}
```

### D. Private Websuche via lokalem SearXNG MCP
Wenn der Agent externe Dokumentation oder Fehler recherchieren muss, wird nicht die Google- oder Bing-API aufgerufen.  
Stattdessen leitet der Skript-Bridge `mcp_searxng_bridge.py` die Anfrage an deine lokale Docker-Instanz:
- URL: `http://127.0.0.1:8081`
- Anonymisierte Abfrage über mehrere Suchmaschinen
- Keine User-Tokens, keine IP-Zuordnung, keine Profilierung.

---

## 📲 3. Remote-CLI Schnellanleitung (Arbeiten von unterwegs)

Wenn du unterwegs auf deinem Laptop oder Tablet arbeitest:

1. **Tailscale aktivieren** auf dem Client-Gerät.
2. **SSH-Verbindung zur Agent-Workstation aufbauen:**
   ```bash
   ssh clemi@100.x.y.z -t "cd /home/clemi/Projekte/LLM && ./agent-cli-setup/scripts/start_agent_session.sh"
   ```
3. **Ergebnis:** Du befindest dich in der vollwertigen, GPU-beschleunigten OpenCode/Goose-Umgebung mit vollem Zugriff auf die 48 GB VRAM deiner AMD Radeon PRO W7800 – komplett abhörsicher und stabil!

