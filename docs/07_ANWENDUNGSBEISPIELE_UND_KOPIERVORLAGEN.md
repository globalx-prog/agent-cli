# 📚 Anwendungsbeispiele & Copy-Paste-Vorlagen (Praxis-Katalog)
## Alle Befehle, Prompts, Slash-Commands & Workflows zum direkten Kopieren

> **System:** `clemi-pc` | AMD Radeon PRO W7800 (48 GB VRAM) | OpenCode & Goose CLI  
> **Zweck:** Direkt einsetzbare Kopiervorlagen für Alltag, Großprojekte, MCP-Suche, Playwright-Tests, Security-Audits und Remote-Zugriff.

---

## ⚡ 1. Die 4 eigenen Kurzbefehle (Slash-Commands in OpenCode)

Diese Kurzbefehle sind fest in [`configs/opencode.json`](file:///home/clemi/Projekte/LLM/agent-cli-setup/configs/opencode.json) hinterlegt. Tippe sie einfach direkt in das Eingabefeld von OpenCode:

### Beispiel 1A: Anonyme Websuche über lokales SearXNG (`Port 8081`)
```text
/suche ROCm 6.4 AMD Radeon PRO W7800 release notes
```
```text
/suche Python FastAPI async SQLAlchemy connection pool best practices
```
* **Was passiert:** Ruft sofort [`mcp_searxng_bridge.py`](file:///home/clemi/Projekte/LLM/agent-cli-setup/scripts/mcp_searxng_bridge.py) auf, durchsucht deine lokale Docker-SearXNG-Instanz und liefert eine Zusammenfassung mit Links – ohne Google-Tracking.

---

### Beispiel 1B: Read-Only Architektur- & Aufgabenplanung (`/plan`)
```text
/plan agent-cli-setup/scripts/ für ein neues Monitoring-Skript healthcheck.py im Coding-Worktree
```
* **Was passiert:** Schaltet automatisch in den `planner`-Agent (`write: false`, `edit: false`, `bash: false`), liest die Skripte ein und gibt einen fertigen 3-Punkte-Implementierungsplan aus, ohne Dateien zu verändern.

---

### Beispiel 1C: Lokale Webseiten & WebUIs mit Playwright testen (`/webtest`)
```text
/webtest http://127.0.0.1:8081
```
```text
/webtest http://127.0.0.1:3000
```
* **Was passiert:** Schaltet in den `tester`-Agent, startet das lokale Chromium (`/home/clemi/.cache/ms-playwright/...`) headless im Hintergrund, öffnet die URL, prüft den DOM-Baum/Seitentitel und gibt einen Testbericht aus.

---

### Beispiel 1D: Unabhängiges Code- & Sicherheits-Review (`/review`)
```text
/review agent-cli-setup/projects/worktrees/coding/vram_check.py
```
* **Was passiert:** Schaltet in den `reviewer`-Agent (Read-Only), liest die Datei ein und prüft sie auf fehlendes Error-Handling (`FileNotFoundError`, `PermissionError`), Sicherheitslücken und Clean Code.

---

## 👥 2. Spezialisierte Agenten gezielt steuern (`Tab` oder `@agent`)

Du kannst entweder unten links mit der **`Tab`-Taste** dauerhaft den aktiven Agenten wechseln oder im Chat `@agent` voranstellen:

### Beispiel 2A: `@coder` — Code im isolierten Worktree erstellen & testen
```text
@coder Erstelle im Worktree agent-cli-setup/projects/worktrees/coding/ eine Datei namens vram_check.py, die per Python die GPU-Auslastung aus /sys/class/drm/card0/device/gpu_busy_percent und die Temperatur aus /sys/class/drm/card0/device/hwmon/hwmon6/temp2_input ausliest, sauber mit try/except abfängt und formatiert ausgibt. Führe das Skript danach einmal mit python3 aus.
```
* **Ergebnis:** OpenCode zeigt dir das Datei-Diff zur Bestätigung (`edit: ask`) und fragt vor dem Start von `python3` um Freigabe (`bash: ask`).

---

### Beispiel 2B: `@tester` — Unit-Tests schreiben & Playwright-Screenshot speichern
```text
@tester Schreibe im Worktree agent-cli-setup/projects/worktrees/testing/ einen pytest-Unit-Test test_vram_check.py für die Datei ../coding/vram_check.py und führe pytest aus. Öffne zusätzlich mit Playwright http://127.0.0.1:8081 und speichere einen Screenshot unter agent-cli-setup/projects/worktrees/testing/searxng_ui.png.
```

---

### Beispiel 2C: `@reviewer` — Git-Diff vor dem Merge auditieren
```text
@reviewer Analysiere alle Änderungen im Verzeichnis agent-cli-setup/projects/worktrees/coding/ und erstelle eine kurze Checkliste, ob der Code sicher in den main-Branch gemerged werden kann.
```

---

## 🔄 3. End-to-End Beispiel: Ein komplettes Projekt/Feature in 5 Schritten umsetzen

So sieht der perfekte Ablauf für ein mehrteiliges Feature (trotz 32k Kontextlimit) aus:

### Schritt 1: Projekt-Landkarte initialisieren (einmalig pro Projekt)
```text
/init
```
*(Erzeugt `AGENTS.md` als dauerhaftes Architektur-Gedächtnis auf der SSD).*

### Schritt 2: Plan in `PLAN.md` auf die SSD schreiben lassen
```text
Erstelle eine Datei PLAN.md im Coding-Worktree mit einer 4-Schritte-Checkliste (- [ ] Schritt 1...), um ein CLI-Dashboard für unsere lokalen Docker-Container (open-webui, searxng, cloudflared, llama-speedup) in Python zu bauen.
```

### Schritt 3: Schrittweise abarbeiten & Kontext mit `/compact` sauber halten
```text
Lies PLAN.md im Coding-Worktree, setze jetzt NUR Schritt 1 und 2 um, teste sie kurz und hake sie in PLAN.md als [x] ab.
```
Danach im Eingabefeld tippen:
```text
/compact
```
*(Dampft den bisherigen Chat auf ~500 Tokens zusammen – der 32k-Kontext ist wieder komplett frei!)*

### Schritt 4: Restliche Schritte umsetzen & Review durchführen
```text
Lies PLAN.md, setze Schritt 3 und 4 um und lass @reviewer das fertige Skript prüfen.
```

### Schritt 5: Bei einem Fehler sofort zurückrollen (`/undo`)
Falls dir eine Code-Änderung nicht gefällt, tippe einfach:
```text
/undo
```

---

## 🔓 4. Unzensierte Security- & Pentesting-Analysen (`/models`)

Wenn du eigene Server, Docker-Container, Firewall-Regeln oder Skripte auf Schwachstellen prüfen willst, ohne dass ein Cloud-Filter blockiert:

1. Tippe in OpenCode **`/models`** und wähle:
   * **`Qwen 3 Obliterated 27B`** (in Ollama) oder
   * **`Llama 3.3 70B Abliterated Speculative (30.0 t/s)`** (im Speculative-Modus Port 5002).
2. Beispiel-Prompt:
   ```text
   Prüfe unsere Docker-Compose-Dateien in ollama-zugriff/ und llm-optimierungen/llm-speedup/ aus Sicht eines Angreifers (Red-Team-Audit): Welche Container-Ausbruchsrisiken, offenen Sockets oder Privilegien-Schwachstellen existieren und wie härten wir sie ab?
   ```

---

## 🖥️ 5. Terminal-Direktbefehle (Außerhalb von OpenCode)

Diese Befehle führst du direkt in deiner normalen Linux-Bash aus (`/home/clemi/Projekte/LLM/agent-cli-setup`):

### A. Blitzschnelle SearXNG-Suche direkt im Terminal (ohne LLM)
```bash
./scripts/suche.sh "ROCm 6.4 Flash Attention RDNA3"
```

### B. System-, Thermik-, Lüfter- & Port-Status prüfen
```bash
./scripts/status.sh
```

### C. VRAM gezielt freiräumen (beim Wechsel zwischen Ollama & Port 5002)
```bash
# Nur Port 5002 (llama-speedup) entladen, damit Ollama freien VRAM hat:
./scripts/free_agent_vram.sh --only-speedup

# Nur Ollama entladen, damit Port 5002 (72B Speculative) 48 GB VRAM frei hat:
./scripts/free_agent_vram.sh --only-ollama

# Komplett-Reset (Ollama + Port 5002 + ComfyUI + Swap + W7800 DPM):
./scripts/free_agent_vram.sh --all
```

### D. W7800 GPU-Boost für lange Multi-Agent-Sessions aktivieren (`230W` + `65% Lüfter`)
```bash
# 230W Performance (+18% schnellerer Prefill, Hotspot -24°C kühler):
/home/clemi/Projekte/LLM/scripts/set-gpu-mode-performance.sh

# Zurück auf flüsterleisen 200W Alltagsbetrieb:
/home/clemi/Projekte/LLM/scripts/set-gpu-mode-daily.sh
```

---

## 📱💻 6. Remote-Zugriff von Laptop & Smartphone (über Tailscale `100.x.y.z`)

### A. Vom Laptop (persistente Tmux-Session über SSH)
```bash
ssh clemi@100.x.y.z -t "/home/clemi/Projekte/LLM/agent-cli-setup/scripts/remote_agent.sh tmux"
```
*(Tipp in Tmux: Mit `Strg+B` und danach `D` trennst du die Verbindung, während der Agent im Hintergrund weiterarbeitet!)*

### B. Vom Smartphone im Browser (Touch-Bedienung über `opencode web`)
1. Einmalig auf `clemi-pc` als Systemstart-Dienst aktivieren (oder manuell per `remote_agent.sh web`):
   ```bash
   /home/clemi/Projekte/LLM/agent-cli-setup/scripts/autostart_remote_service.sh enable
   ```
2. Auf dem Handy (bei aktivem Tailscale) im Browser öffnen:
   ```text
   http://100.x.y.z:4096
   ```

---

## 🏆 7. Großprojekt-Workflow mit unterschiedlichen Modellen (4-Phasen Copy-Paste Vorlagen)

Starte im Terminal den Multi-Model-Modus (`./scripts/multimodel_project_workflow.sh` -> Auswahl `1` für automatischen Rollenwechsel oder Auswahl `3` für den geführten 4-Phasen-Staffellauf) und nutze diese 4 Prompts nacheinander:

### Phase 1: Architektur & `PLAN.md` mit 70B/72B/80B erstellen
```text
@planner Analysiere die bestehende Struktur in agent-cli-setup/scripts/ und erstelle eine modulare Architektur-Spezifikation mit einer 4-Punkte-Checkliste für ein neues System-Health-Dashboard. Fass die Punkte präzise zusammen.
```

### Phase 2: Großer 64k-Kontext & Grundgerüst mit `qwen3-coder-speed` (64k Ctx)
```text
Lies alle relevanten Skripte in agent-cli-setup/scripts/ ein, erstelle im Worktree agent-cli-setup/projects/worktrees/coding/ eine PLAN.md mit den 4 Schritten und implementiere direkt das Grundgerüst von Schritt 1 und 2.
```
*(Danach `/compact` tippen, um den Kontext aufzuräumen).*

### Phase 3: Q8-Feinschliff & E2E-Tests mit `qwen3-coder-quality` (`@coder` & `@tester`)
```text
@coder Vervollständige Schritt 3 und 4 aus agent-cli-setup/projects/worktrees/coding/PLAN.md mit sauberem Type-Hinting und Error-Handling.
```
```text
@tester Schreibe im Worktree agent-cli-setup/projects/worktrees/testing/ passende pytest-Tests für die neuen Module aus ../coding/ und führe pytest aus.
```

### Phase 4: Unabhängiges Vier-Augen-Audit mit `Llama 3.3 70B Abliterated` (`@reviewer`)
```text
/review agent-cli-setup/projects/worktrees/coding/
```
*(Hier prüft ein 70B-Llama-Modell den Code des Qwen-Coders auf blinde Flecken, Race Conditions und Sicherheitslücken!)*


