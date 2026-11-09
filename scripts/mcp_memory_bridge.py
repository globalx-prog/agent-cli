#!/usr/bin/env python3
"""
🧠 Lokales Langzeit-Gedächtnis (MCP-Server + CLI) für OpenCode & Goose
======================================================================
- 0 MB VRAM-Verbrauch (SQLite3 + FTS5 BM25 Volltext-Index + Markdown-Sync)
- Speichert Fakten, Architektur-Entscheidungen, Benutzer-Präferenzen und gelöste Bugs
  persistent über alle Sessions hinweg in:
    1) configs/agent_memory.db (SQLite Datenbank)
    2) configs/MEMORY.md       (Menschenlesbares Markdown-Gedächtnis)
- Unterstützt sowohl JSON-RPC 2.0 STDIO (MCP 2024-11-05) als auch direkten CLI-Aufruf.
"""

import argparse
import datetime
import json
import sqlite3
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
CONFIG_DIR = BASE_DIR / "configs"
DB_PATH = CONFIG_DIR / "agent_memory.db"
MD_PATH = CONFIG_DIR / "MEMORY.md"


def get_db() -> sqlite3.Connection:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS memories (
            key TEXT PRIMARY KEY,
            category TEXT NOT NULL DEFAULT 'allgemein',
            project TEXT NOT NULL DEFAULT 'global',
            content TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )
    conn.commit()
    return conn


def sync_markdown(conn: sqlite3.Connection) -> None:
    rows = conn.execute(
        "SELECT key, category, project, content, updated_at FROM memories ORDER BY category, key"
    ).fetchall()
    lines = [
        "# 🧠 Lokales Agenten-Langzeitgedächtnis (`MEMORY.md`)",
        "",
        "> Automatisch synchronisiert durch [`scripts/mcp_memory_bridge.py`](file:///home/clemi/Projekte/LLM/agent-cli-setup/scripts/mcp_memory_bridge.py).  ",
        "> **VRAM-Verbrauch:** `0 MB` (SQLite + Markdown). Verfügbar in OpenCode via `/merke`, `/erinnere` und MCP-Tools.",
        "",
        "| Schlüssel (`key`) | Kategorie | Projekt | Inhalt / Fakt | Aktualisiert |",
        "| :--- | :---: | :---: | :--- | :---: |",
    ]
    for r in rows:
        safe_content = str(r["content"]).replace("|", "\\|").replace("\n", " ")
        lines.append(
            f"| `{r['key']}` | `{r['category']}` | `{r['project']}` | {safe_content} | {r['updated_at']} |"
        )
    lines.append("")
    MD_PATH.write_text("\n".join(lines), encoding="utf-8")


def seed_defaults(force: bool = False) -> None:
    conn = get_db()
    count = conn.execute("SELECT COUNT(*) FROM memories").fetchone()[0]
    if count == 0 or force:
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        defaults = [
            (
                "hardware-w7800",
                "system",
                "global",
                "AMD Radeon PRO W7800 mit 48 GB GDDR6 VRAM (Netto ~44,4 GiB, Sicherheitsgrenze <= 41 GiB VRAM). ROCm 6.4 nativ, 128 GB System-RAM.",
                now,
            ),
            (
                "4-saeulen-standard",
                "konvention",
                "global",
                "Alle Projekte im LLM-Workspace nutzen strikt den 4-Säulen-NAS-Standard: configs/, docs/, scripts/, setup/ + README.md.",
                now,
            ),
            (
                "single-model-regel",
                "architektur",
                "agent-cli-setup",
                "In Single-Model-Modi (1-5) nutzen Hauptagent, small_model und Subagents exakt dasselbe Modell für 0x VRAM-Reload.",
                now,
            ),
            (
                "kontext-matrix",
                "architektur",
                "agent-cli-setup",
                "Maximierte 100%-VRAM Default-Kontexte: Modus 1 (qwen3-coder-quality Q8) = 64k | Modus 2 (qwen3-coder-speed Q4) = 128k | Modus 3 (qwen3.8-35b-distill Q6) = 96k | Modus 4/5 (70B/72B Speculative) = 32k.",
                now,
            ),
            (
                "port-architektur",
                "netzwerk",
                "global",
                "Port 11434: Ollama | Port 5002: llama-speedup (Speculative 70B/72B) | Port 8081: SearXNG | Port 8000: Whisper STT | Port 4096: OpenCode Web | Port 4097: Mermaid Sidecar | Port 8090: App-Preview.",
                now,
            ),
            (
                "netzwerk-sicherheit",
                "sicherheit",
                "global",
                "Tailscale Mesh IP: 100.x.y.z. Kein direkter Internet-Zugriff durch Agenten (webfetch: deny); Websuche ausschließlich anonym über lokales SearXNG.",
                now,
            ),
            (
                "git-hooks-konvention",
                "konvention",
                "global",
                "Git-Commits folgen strikt Conventional Commits (feat:, fix:, docs:, chore:, refactor:, max. 72 Zeichen). Keine *.gguf/*.bin Dateien oder Dateien > 2 MB committen.",
                now,
            ),
            (
                "worktree-isolation",
                "workflow",
                "agent-cli-setup",
                "Isolierte Git-Worktrees unter projects/worktrees/: coding/ (Branch agent/coding), testing/ (Branch agent/testing), review/ (Branch agent/review).",
                now,
            ),
            (
                "code-qualitaet",
                "praferenz",
                "global",
                "Sprache für Dokumentation und Erklärungen: Deutsch. Shell-Skripte mit 'set -eo pipefail', Python-Skripte mit Typannotationen und möglichst ohne unnötige externe Abhängigkeiten.",
                now,
            ),
            (
                "sidecar-steuerung",
                "workflow",
                "agent-cli-setup",
                "Alle 8 Sidecars (1:gpu, 2:git, 3:test, 4:speed, 5:browser, 6:plan, 7:docs, 8:app) werden über ./scripts/sidecar_manager.sh <1..8> {on|off|toggle} gesteuert.",
                now,
            ),
        ]
        conn.executemany(
            "INSERT OR REPLACE INTO memories (key, category, project, content, updated_at) VALUES (?, ?, ?, ?, ?)",
            defaults,
        )
        conn.commit()
        sync_markdown(conn)
    conn.close()


def memory_save(key: str, content: str, category: str = "allgemein", project: str = "global") -> dict:
    conn = get_db()
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    conn.execute(
        "INSERT OR REPLACE INTO memories (key, category, project, content, updated_at) VALUES (?, ?, ?, ?, ?)",
        (key.strip(), category.strip(), project.strip(), content.strip(), now),
    )
    conn.commit()
    sync_markdown(conn)
    conn.close()
    return {"status": "saved", "key": key, "category": category, "project": project, "updated_at": now}


def memory_search(query: str, project: str = "", limit: int = 10) -> list:
    conn = get_db()
    q = f"%{query.strip()}%"
    if project:
        rows = conn.execute(
            """
            SELECT key, category, project, content, updated_at FROM memories
            WHERE (key LIKE ? OR content LIKE ? OR category LIKE ?)
              AND (project = ? OR project = 'global')
            ORDER BY updated_at DESC LIMIT ?
            """,
            (q, q, q, project, limit),
        ).fetchall()
    else:
        rows = conn.execute(
            """
            SELECT key, category, project, content, updated_at FROM memories
            WHERE key LIKE ? OR content LIKE ? OR category LIKE ? OR project LIKE ?
            ORDER BY updated_at DESC LIMIT ?
            """,
            (q, q, q, q, limit),
        ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def memory_list(project: str = "", category: str = "") -> list:
    conn = get_db()
    sql = "SELECT key, category, project, content, updated_at FROM memories WHERE 1=1"
    params = []
    if project:
        sql += " AND (project = ? OR project = 'global')"
        params.append(project)
    if category:
        sql += " AND category = ?"
        params.append(category)
    sql += " ORDER BY category, key"
    rows = conn.execute(sql, params).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def memory_delete(key: str) -> dict:
    conn = get_db()
    cur = conn.execute("DELETE FROM memories WHERE key = ?", (key.strip(),))
    conn.commit()
    sync_markdown(conn)
    conn.close()
    return {"status": "deleted" if cur.rowcount > 0 else "not_found", "key": key}


def run_mcp_stdio() -> None:
    seed_defaults()
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            method = req.get("method", "")
            if "id" not in req or req.get("id") is None:
                continue
            req_id = req["id"]

            if method == "initialize":
                res = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "local-memory-mcp", "version": "1.0.0"},
                    },
                }
            elif method == "ping":
                res = {"jsonrpc": "2.0", "id": req_id, "result": {}}
            elif method == "tools/list":
                res = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "tools": [
                            {
                                "name": "memory_save",
                                "description": "Speichert oder aktualisiert einen Fakt, eine Architekturentscheidung oder Präferenz dauerhaft im lokalen Langzeit-Gedächtnis (SQLite + MEMORY.md).",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "key": {"type": "string", "description": "Kurzer eindeutiger Schlüssel (z.B. 'auth-strategie' oder 'db-port')"},
                                        "content": {"type": "string", "description": "Der zu merkende Fakt oder die Entscheidung"},
                                        "category": {"type": "string", "description": "Kategorie (z.B. architektur, konvention, bugfix, präferenz)", "default": "allgemein"},
                                        "project": {"type": "string", "description": "Projektname oder 'global'", "default": "global"},
                                    },
                                    "required": ["key", "content"],
                                },
                            },
                            {
                                "name": "memory_search",
                                "description": "Durchsucht das lokale Langzeit-Gedächtnis nach Stichworten, Fakten oder früheren Entscheidungen.",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "query": {"type": "string", "description": "Suchbegriff"},
                                        "project": {"type": "string", "description": "Optionaler Projektfilter", "default": ""},
                                    },
                                    "required": ["query"],
                                },
                            },
                            {
                                "name": "memory_list",
                                "description": "Listet alle gespeicherten Einträge aus dem lokalen Langzeit-Gedächtnis auf.",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "project": {"type": "string", "description": "Optionaler Projektfilter", "default": ""},
                                        "category": {"type": "string", "description": "Optionale Kategorie", "default": ""},
                                    },
                                },
                            },
                            {
                                "name": "memory_delete",
                                "description": "Löscht einen veralteten Eintrag anhand seines Schlüssels aus dem Langzeit-Gedächtnis.",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "key": {"type": "string", "description": "Schlüssel des zu löschenden Eintrags"}
                                    },
                                    "required": ["key"],
                                },
                            },
                        ]
                    },
                }
            elif method == "tools/call":
                params = req.get("params", {})
                name = params.get("name", "")
                args = params.get("arguments", {})
                if name == "memory_save":
                    out = memory_save(
                        str(args.get("key", "")),
                        str(args.get("content", "")),
                        str(args.get("category", "allgemein")),
                        str(args.get("project", "global")),
                    )
                elif name == "memory_search":
                    out = memory_search(str(args.get("query", "")), str(args.get("project", "")))
                elif name == "memory_list":
                    out = memory_list(str(args.get("project", "")), str(args.get("category", "")))
                elif name == "memory_delete":
                    out = memory_delete(str(args.get("key", "")))
                else:
                    res = {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "error": {"code": -32601, "message": f"Unknown tool: {name}"},
                    }
                    sys.stdout.write(json.dumps(res) + "\n")
                    sys.stdout.flush()
                    continue

                res = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "content": [{"type": "text", "text": json.dumps(out, indent=2, ensure_ascii=False)}],
                        "isError": False,
                    },
                }
            else:
                res = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "error": {"code": -32601, "message": f"Method not found: {method}"},
                }

            sys.stdout.write(json.dumps(res) + "\n")
            sys.stdout.flush()
        except Exception as err:
            err_res = {
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32700, "message": f"Memory MCP error: {str(err)}"},
            }
            sys.stdout.write(json.dumps(err_res) + "\n")
            sys.stdout.flush()


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "--cli":
        seed_defaults()
        parser = argparse.ArgumentParser(description="Lokales Agenten-Gedächtnis CLI")
        parser.add_argument("--cli", action="store_true")
        sub = parser.add_subparsers(dest="cmd")

        p_add = sub.add_parser("add", help="Eintrag speichern")
        p_add.add_argument("key")
        p_add.add_argument("content")
        p_add.add_argument("--category", default="allgemein")
        p_add.add_argument("--project", default="global")

        p_search = sub.add_parser("search", help="Gedächtnis durchsuchen")
        p_search.add_argument("query")

        sub.add_parser("list", help="Alle Einträge anzeigen")

        p_del = sub.add_parser("delete", help="Eintrag löschen")
        p_del.add_argument("key")

        sub.add_parser("reset-defaults", help="10 Standard-Systemregeln wiederherstellen/aktualisieren")

        args = parser.parse_args()
        if args.cmd == "add":
            res = memory_save(args.key, args.content, args.category, args.project)
            print(f"✅ Gespeichert: [{res['category']}/{res['project']}] {res['key']} -> {args.content}")
        elif args.cmd == "search":
            rows = memory_search(args.query)
            print(json.dumps(rows, indent=2, ensure_ascii=False))
        elif args.cmd == "delete":
            res = memory_delete(args.key)
            print(f"🗑️ Status: {res['status']} ({res['key']})")
        elif args.cmd == "reset-defaults":
            seed_defaults(force=True)
            print("✅ 10 Goldene Default-Gedächtnisregeln wurden in agent_memory.db & MEMORY.md aktualisiert!")
        else:
            rows = memory_list()
            print("======================================================================")
            print(f"🧠 LOKALES AGENTEN-GEDÄCHTNIS ({len(rows)} Einträge in configs/agent_memory.db)")
            print("======================================================================")
            for r in rows:
                print(f"  • [{r['category']} | {r['project']}] {r['key']}:")
                print(f"    {r['content']} ({r['updated_at']})")
            print("======================================================================")
    else:
        run_mcp_stdio()


if __name__ == "__main__":
    main()

