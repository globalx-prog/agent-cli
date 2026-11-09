# 🧠 Lokales Agenten-Langzeitgedächtnis (`MEMORY.md`)

> Automatisch synchronisiert durch [`scripts/mcp_memory_bridge.py`](file:///home/clemi/Projekte/LLM/agent-cli-setup/scripts/mcp_memory_bridge.py).  
> **VRAM-Verbrauch:** `0 MB` (SQLite + Markdown). Verfügbar in OpenCode via `/merke`, `/erinnere` und MCP-Tools.

| Schlüssel (`key`) | Kategorie | Projekt | Inhalt / Fakt | Aktualisiert |
| :--- | :---: | :---: | :--- | :---: |
| `kontext-matrix` | `architektur` | `agent-cli-setup` | Maximierte 100%-VRAM Default-Kontexte: Modus 1 (qwen3-coder-quality Q8) = 64k \| Modus 2 (qwen3-coder-speed Q4) = 128k \| Modus 3 (qwen3.8-35b-distill Q6) = 96k \| Modus 4/5 (70B/72B Speculative) = 32k. | 2026-11-06 13:21 |
| `single-model-regel` | `architektur` | `agent-cli-setup` | In Single-Model-Modi (1-5) nutzen Hauptagent, small_model und Subagents exakt dasselbe Modell für 0x VRAM-Reload. | 2026-11-06 13:21 |
| `4-saeulen-standard` | `konvention` | `global` | Alle Projekte im LLM-Workspace nutzen strikt den 4-Säulen-NAS-Standard: configs/, docs/, scripts/, setup/ + README.md. | 2026-11-06 13:21 |
| `git-hooks-konvention` | `konvention` | `global` | Git-Commits folgen strikt Conventional Commits (feat:, fix:, docs:, chore:, refactor:, max. 72 Zeichen). Keine *.gguf/*.bin Dateien oder Dateien > 2 MB committen. | 2026-11-06 13:21 |
| `port-architektur` | `netzwerk` | `global` | Port 11434: Ollama \| Port 5002: llama-speedup (Speculative 70B/72B) \| Port 8081: SearXNG \| Port 8000: Whisper STT \| Port 4096: OpenCode Web \| Port 4097: Mermaid Sidecar \| Port 8090: App-Preview. | 2026-11-06 13:21 |
| `code-qualitaet` | `praferenz` | `global` | Sprache für Dokumentation und Erklärungen: Deutsch. Shell-Skripte mit 'set -eo pipefail', Python-Skripte mit Typannotationen und möglichst ohne unnötige externe Abhängigkeiten. | 2026-11-06 13:21 |
| `netzwerk-sicherheit` | `sicherheit` | `global` | Tailscale Mesh IP: 100.x.y.z. Kein direkter Internet-Zugriff durch Agenten (webfetch: deny); Websuche ausschließlich anonym über lokales SearXNG. | 2026-11-06 13:21 |
| `hardware-w7800` | `system` | `global` | AMD Radeon PRO W7800 mit 48 GB GDDR6 VRAM (Netto ~44,4 GiB, Sicherheitsgrenze <= 41 GiB VRAM). ROCm 6.4 nativ, 128 GB System-RAM. | 2026-11-06 13:21 |
| `sidecar-steuerung` | `workflow` | `agent-cli-setup` | Alle 8 Sidecars (1:gpu, 2:git, 3:test, 4:speed, 5:browser, 6:plan, 7:docs, 8:app) werden über ./scripts/sidecar_manager.sh <1..8> {on\|off\|toggle} gesteuert. | 2026-11-06 13:21 |
| `worktree-isolation` | `workflow` | `agent-cli-setup` | Isolierte Git-Worktrees unter projects/worktrees/: coding/ (Branch agent/coding), testing/ (Branch agent/testing), review/ (Branch agent/review). | 2026-11-06 13:21 |
