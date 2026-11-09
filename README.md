# 🤖 Lokales Multi-Agent-Ökosystem & CLI-Setup (AMD Radeon PRO W7800 48 GB)

> **Hardware:** AMD Radeon PRO W7800 (48 GB GDDR6 VRAM, 384-Bit Bus, Netto ~44,4 GiB) | 16 Kerne | 128 GB RAM | Ubuntu Linux (ROCm 6.4 nativ)  
> **Netzwerk & Schutz:** Tailscale VPN (`100.x.y.z`), Cloudflare Zero Trust (`openwebui.deine-domain.de`), Loopback (`127.0.0.1`)  
> **Kern-Runtimes:** OpenCode CLI (Coding-Agent & Subagents), Goose CLI (Orchestrator & Recipes), Ollama (Port 11434) & `llama-speedup` (Port 5002 Speculative Decoding)  
> **Ziel:** Vollständige lokale Replizierung moderner Agentic CLIs (wie Google Antigravity) mit 100 % Datenschutz, Zero-Data-Egress und nativer GPU-Beschleunigung.

---

## 🏛️ System- & Service-Architektur

```text
                                [ CLIENT-ZUGRIFF ]
                                         │
                    ┌────────────────────┴────────────────────┐
                    ▼                                         ▼
          Cloudflare Zero Trust                       Tailscale WireGuard
       (openwebui.deine-domain.de)                   (100.x.y.z Mesh)
                    │                                         │
           (Nur WebUI Ingress)                        (Remote CLI & SSH)
                    │                                         │
  ══════════════════╪═════════════════════════════════════════╪══════════════════════
                    │                                         │
                    ▼                                         ▼
           Open WebUI (Port 3000)                   OpenCode / Goose CLI
                    │                                         │
                    │                    ┌────────────────────┼────────────────────┐
                    │                    ▼                    ▼                    ▼
                    │               📐 Planner           💻 Coder             🧪 Tester
                    │             (DeepSeek 70B /      (Qwen 3 Coder Q8     (Qwen 3 Speed 80 t/s
                    │              Qwen 72B Spec.)      62.7 t/s, 1773 PF)   + Playwright MCP)
                    │                    │                    │                    │
                    │                    └──────────────┬─────┴────────────────────┘
                    ▼                                   ▼
        ┌────────────────────────────────────────────────────────────────────────┐
        │                 Lokale Inferenz-Ebene (W7800 48 GB VRAM)               │
        │   • Ollama Server (Port 11434 / Flash Attention / q4_0 KV-Cache)       │
        │   • llama-speedup (Port 5002 / Speculative Decoding +269% Speedup)     │
        │   • SearXNG Private Search (Port 8081 / Docker ai-network)             │
        └────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 4-Säulen-Verzeichnisstruktur (NAS-Standard)

```text
agent-cli-setup/
├── README.md                            # Dieses Dokument (Übersicht & Schnellstart)
│
├── configs/                             # 1. Konfigurationen & Agentenprofile
│   ├── opencode.json                    # OpenCode Master-Config (Ollama + llama-speedup Port 5002 + Auto-Memory)
│   ├── MEMORY.md                        # Menschenlesbares Langzeit-Gedächtnis (wird automatisch geladen)
│   ├── agent_memory.db                  # Lokale SQLite-Gedächtnis-Datenbank (0 MB VRAM)
│   ├── goose-config.yaml                # Goose Orchestrator-Config (Recipes, 32k Context)
│   ├── mcp-servers.json                 # Standardisierte MCP-Server-Definitionen
│   ├── tailscale-remote.env             # Remote-CLI & Endpunkt-Definitionen für Tailscale
│   └── agents/                          # Spezialisierte Subagenten-Definitionen
│       ├── planner.md                   # Deep Architecture & Planer (DeepSeek R1 70B, read-only)
│       ├── coder.md                     # High-Precision Implementation (qwen3-coder-quality Q8)
│       ├── reviewer.md                  # Security- & Quality-Auditor (DeepSeek R1 70B, read-only)
│       └── tester.md                    # QA & Playwright-Browser-Tester (qwen3-coder-speed + MCP)
│
├── docs/                                # 2. Dokumentation & Architektur-Leitfäden
│   ├── 01_ARCHITEKTUR_UND_TOOL_INTERAKTION.md # Detaillierte Mermaid-Diagramme & Tool-Interaktion
│   ├── 02_HARDWARE_UND_VRAM_STRATEGIE_W7800.md # Reale Benchmarks, 64k Speed, Next-80B & Thermik
│   ├── 03_VERGLEICH_ANTIGRAVITY_VS_LOCAL_STACK.md # Feature-Matrix: Sind alle Antigravity-Funktionen da?
│   ├── 04_NETZWERK_TAILSCALE_CLOUDFLARE_DATENSCHUTZ.md # Zero-Egress, Tailscale Mesh vs. Cloudflare
│   ├── 05_WORKTREE_UND_MULTI_AGENTEN_WORKFLOW.md # Git Worktree Isolierung für parallele Agenten
│   ├── 06_PRAXIS_LEITFADEN_GROSSE_PROJEKTE_UND_BEDIENUNG.md # 32k/64k-Strategie, Laptop/Handy-Remote & Git
│   ├── 07_ANWENDUNGSBEISPIELE_UND_KOPIERVORLAGEN.md # Copy-Paste-Katalog (/suche, /plan, /webtest, Workflows)
│   ├── 08_KOMPLETTHANDBUCH_WORKFLOWS_MODELLE_UND_ERWEITERUNGEN.md # Multi-Model-Pipeline, 64k/80B, Websuche, Sidecars & Autostart
│   ├── 09_TAEGLICHER_PRAXIS_GUIDE_UND_TOOL_KOMBINATIONEN.md # Täglicher Workflow-Guide & beste Tool-Kombinationen
│   ├── 10_LOKALES_GEDAECHTNIS_UND_DEFAULT_CONFIG.md # Lokales Dual-Gedächtnis (MEMORY.md + MCP) & Default-Profile
│   ├── 11_SYSTEM_LANDKARTE_UND_TOOL_MATRIX.md # Grafische System-Landkarte aller umgesetzten & möglichen Tools
│   └── 12_GESAMTDOKU_SETUP_VON_SCRATCH.md   # Masterplan für kompletten Neuaufbau (Phase 0 bis 7)
│
├── scripts/                             # 3. Tägliche Betriebs-Skripte
│   ├── start_agent_session.sh           # Interaktiver Launcher (5 Single-Model Modi + Modus 6 Multi-Model)
│   ├── sidecar_manager.sh               # Zentraler Sidecar-Manager (alle 8 Sidecars einzeln/kombiniert on/off/toggle)
│   ├── live_mermaid_sidecar.py          # Dark-Mode Web-Sidecar (Port 4097) für Live-Mermaid-Diagramme & PLAN.md
│   ├── memory.sh                        # CLI-Steuerung für das lokale Langzeit-Gedächtnis (list/add/search/delete)
│   ├── mcp_memory_bridge.py             # JSON-RPC 2.0 MCP-Server für lokales SQLite + MEMORY.md Gedächtnis
│   ├── multimodel_project_workflow.sh   # Großprojekt-Workflow (70B/72B Planer -> 64k Speed -> Q8 Coder -> 70B Audit)
│   ├── remote_agent.sh                  # Remote-Launcher für Laptop (SSH/Tmux) & Handy (Web-UI Port 4096)
│   ├── autostart_remote_service.sh      # Prüft Boot-Autostart & aktiviert systemd-Service für Port 4096
│   ├── suche.sh                         # Direkte SearXNG-Schnellsuche fürs Linux-Terminal
│   ├── fix_ollama_tool_templates.sh     # Patcht Qwen3-Coder Tool-Template & setzt qwen3-coder-speed auf 64k Ctx
│   ├── setup_worktrees.sh               # Sichere Initialisierung isolierter Git-Worktrees
│   ├── status.sh                        # Status-Dashboard (W7800 Thermik, Ports 11434/5002/8081)
│   ├── free_agent_vram.sh               # Gezielter VRAM-Flush (--only-ollama / --only-speedup / --all)
│   └── mcp_searxng_bridge.py            # JSON-RPC 2.0 konformer MCP-Server für SearXNG (Port 8081)
│
├── setup/                               # 4. Nummerierte Installations-Skripte
│   ├── 01-install-cli-tools.sh          # Installation von OpenCode CLI & Goose
│   ├── 02-install-mcp-playwright.sh     # Installation von Playwright MCP & Chromium
│   ├── 03-link-agent-configs.sh         # Automatische Verlinkung nach ~/.config/opencode
│   └── 04-verify-amd-rocm-inference.sh  # Hardware-, ROCm- & MCP-Protokoll-Selbsttest
│
└── projects/                            # Isolierte Git-Arbeitsbereiche (via setup_worktrees.sh)
    ├── main/                            # Branch: main (Sauberes Basis-Repo)
    └── worktrees/
        ├── coding/                      # Branch: agent/coding (Coder Subagent)
        ├── testing/                     # Branch: agent/testing (Tester Subagent)
        └── review/                      # Branch: agent/review (Reviewer Subagent)
```

---

## ⚡ Schnellstart & Tägliche Befehle

### 1. Einmalige Installation & Verlinkung:
```bash
cd /home/clemi/Projekte/LLM/agent-cli-setup
./setup/01-install-cli-tools.sh
./setup/02-install-mcp-playwright.sh
./setup/03-link-agent-configs.sh
./scripts/setup_worktrees.sh
```

### 2. System-, VRAM- & MCP-Selbsttest ausführen:
```bash
./setup/04-verify-amd-rocm-inference.sh
./scripts/status.sh
```

### 3. Agenten-Session im gewünschten Modus starten (1 Modell pro Modus = 0x Entladen):
```bash
./scripts/start_agent_session.sh
```
*Die 5 Single-Model-Modi im Startmenü (alle Subagenten `@planner`, `@coder`, `@tester`, `@reviewer` erben automatisch das Modus-Modell – dadurch 0,0s Wechselzeit ohne VRAM-Reload!):*

| Taste | Modus-Name | Modell-Zuweisung | Backend | Speed & VRAM | Max-Default-Kontext |
| :---: | :--- | :--- | :---: | :---: | :---: |
| **`1`** | **💻 Coding Quality 64k** *(Standard)* | `ollama/qwen3-coder-quality` *(Q8_0 MoE, 0x Entladen)* | Ollama `11434` | **62,7 t/s** (`~35,5 GB`) | **`64k` (`65.536`)** |
| **`2`** | **⚡ Coding Speed 128k** *(Ultra-Kontext)* | `ollama/qwen3-coder-speed` *(Q4_K_M MoE, 0x Entladen)* | Ollama `11434` | **80,6 t/s** (`~24,5 GB`) | **`128k (!)` (`131.072`)** |
| **`3`** | **🧠 Allround Distill 96k** | `ollama/qwen3.8-35b-distill` *(Q6_K, 0x Entladen)* | Ollama `11434` | **66,6 t/s** (`~33,0 GB`) | **`96k` (`98.304`)** |
| **`4`** | **👑 72B Speculative Flaggschiff** | `llama-speedup/qwen2.5-72b-speculative` *(0x Entladen)* | Port `5002` | **33,6 t/s** (`42,0 GB`) | **`32k` (`32.768`)** |
| **`5`** | **🔓 70B Unzensiert / Security** | `llama-speedup/llama3.3-70b-abliterated-speculative` | Port `5002` | **30,0 t/s** (`40,3 GB`) | **`32k` (`32.768`)** |
| **`6`** | **🏆 Multi-Model Großprojekt-Workflow** | `@planner`=70B(32k), `Build`=Speed(128k), `@coder`=Q8(64k), `@reviewer`=70B | Hybrid | **13–80 t/s** *(Spezialisten)* | **`32k–128k`** |
| **`7`** | **🖥️ Tmux Split-Studio** | Startet den aktiven Modus links + Sidecar 1 (GPU) & Sidecar 2 (Git) rechts | - | - | - |
| **`s`** | **🎛️ Sidecar-Manager (1–8)** | Öffnet [`scripts/sidecar_manager.sh`](file:///home/clemi/Projekte/LLM/agent-cli-setup/scripts/sidecar_manager.sh) (alle 8 Sidecars einzeln `on`/`off`/`toggle`) | - | - | - |
| **`8`** | **🪿 Goose CLI** | Startet eine interaktive Goose-Orchestrator-Session (`32k` Context) | Ollama `11434` | - | `32k` |
| **`9`** | **🔥/❄️ GPU Power-Profil** | Schaltet zwischen `230W Performance (65% Lüfter)` und `200W Daily Silent` um | - | - | - |
| **`0`** | **🧹 VRAM-Flush** | Entlädt sofort alle Modelle (Ollama + Port 5002 + ComfyUI + Swap) | - | - | - |

---

## ⚙️ Was macht `start_agent_session.sh` im Hintergrund? (Alle Funktionen im Detail)

Beim Aufruf von [`./scripts/start_agent_session.sh`](file:///home/clemi/Projekte/LLM/agent-cli-setup/scripts/start_agent_session.sh) laufen vor dem Menü automatisch **5 Sicherheits- & Pre-Flight-Funktionen** ab:

1. **`PATH`-Initialisierung:** Bindet `~/.opencode/bin` und `~/.local/bin` automatisch ein, damit OpenCode & Goose ohne Snap-Konflikte gefunden werden.
2. **Pre-Flight Check 1–3 (Port-Prüfung):** Prüft live per `curl`, ob **Ollama (`Port 11434`)**, **`llama-speedup` (`Port 5002`)** und **SearXNG (`Port 8081`)** antworten, und zeigt den Status an.
3. **Pre-Flight Check 4 (Symlink-Selbstheilung):** Prüft, ob `~/.config/opencode/opencode.json` verlinkt ist – falls nicht, führt es automatisch [`setup/03-link-agent-configs.sh`](file:///home/clemi/Projekte/LLM/agent-cli-setup/setup/03-link-agent-configs.sh) aus.
4. **Pre-Flight Check 5 (Auto-Template- & Kontext-Patch `v4`):** Prüft die Marker-Datei `/tmp/.qwen3_tool_template_patched_v4` und führt bei Bedarf einmalig [`scripts/fix_ollama_tool_templates.sh`](file:///home/clemi/Projekte/LLM/agent-cli-setup/scripts/fix_ollama_tool_templates.sh) aus (repariert Multi-Turn JSON-Tool-Calls und setzt die maximierten Kontexte `128k` / `96k` / `64k`).
5. **Interne Funktion `set_single_model_mode(target_model)` (bei Auswahl `1`–`5`):**
   - Setzt etwaige Multi-Model-Einträge in `configs/agents/*.md` via `multimodel_project_workflow.sh reset` zurück.
   - Räumt den jeweils anderen Backend-Port frei (`--only-speedup` bei Wahl von Ollama; `--only-ollama` bei Wahl von Port 5002).
   - Schreibt das gewählte Modell gleichzeitig in `"model"` **und** `"small_model"` der [`configs/opencode.json`](file:///home/clemi/Projekte/LLM/agent-cli-setup/configs/opencode.json), sodass während der gesamten Session **0x entladen** werden muss!
