#!/usr/bin/env python3
"""
📊 Sidecar 7: Live Markdown, PLAN.md & Mermaid.js Viewer (Port 4097)
Rendert PLAN.md sowie alle Handbücher in agent-cli-setup/docs/ inkl. Mermaid-Diagrammen
im Dark-Mode mit automatischem Live-Reload bei Dateiänderungen.
"""
import html
import http.server
import os
import socketserver
import urllib.parse
from pathlib import Path

PORT = int(os.environ.get("SIDECAR_DOCS_PORT", "4097"))
HOST = os.environ.get("SIDECAR_DOCS_HOST", "0.0.0.0")
BASE_DIR = Path(__file__).resolve().parent.parent
CODING_WT = BASE_DIR / "projects" / "worktrees" / "coding"
DOCS_DIR = BASE_DIR / "docs"

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>📊 OpenCode Sidecar 7 — Live Plan & Mermaid Viewer</title>
<style>
  :root {{ --bg: #0d1117; --panel: #161b22; --text: #e6edf3; --accent: #58a6ff; --border: #30363d; }}
  body {{ margin: 0; font-family: system-ui, -apple-system, sans-serif; background: var(--bg); color: var(--text); display: flex; height: 100vh; }}
  nav {{ width: 280px; background: var(--panel); border-right: 1px solid var(--border); padding: 16px; overflow-y: auto; flex-shrink: 0; }}
  nav h3 {{ margin-top: 0; color: var(--accent); font-size: 1rem; }}
  nav a {{ display: block; color: var(--text); text-decoration: none; padding: 8px 10px; border-radius: 6px; margin-bottom: 4px; font-size: 0.88rem; word-break: break-all; }}
  nav a:hover, nav a.active {{ background: #1f2937; color: var(--accent); font-weight: 600; }}
  main {{ flex: 1; padding: 28px 40px; overflow-y: auto; }}
  pre {{ background: var(--panel); padding: 14px; border-radius: 8px; border: 1px solid var(--border); overflow-x: auto; }}
  code {{ font-family: 'JetBrains Mono', monospace; font-size: 0.9rem; }}
  table {{ border-collapse: collapse; width: 100%; margin: 16px 0; }}
  th, td {{ border: 1px solid var(--border); padding: 8px 12px; text-align: left; }}
  th {{ background: var(--panel); }}
  .badge {{ display: inline-block; padding: 3px 8px; border-radius: 12px; background: #238636; color: #fff; font-size: 0.75rem; margin-bottom: 12px; }}
  .mermaid {{ background: #161b22; padding: 16px; border-radius: 8px; border: 1px solid var(--border); margin: 16px 0; }}
</style>
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
  mermaid.initialize({{ startOnLoad: true, theme: 'dark' }});
</script>
<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
</head>
<body>
  <nav>
    <h3>📊 Sidecar 7: Live-Docs</h3>
    <div class="badge">🔄 Auto-Sync aktiv</div>
    {nav_links}
  </nav>
  <main>
    <div id="content"></div>
    <script id="raw-md" type="text/plain">{raw_markdown}</script>
    <script>
      const raw = document.getElementById('raw-md').textContent;
      const renderer = new marked.Renderer();
      const origCode = renderer.code.bind(renderer);
      renderer.code = function(token) {{
        const text = typeof token === 'object' ? token.text : token;
        const lang = typeof token === 'object' ? token.lang : arguments[1];
        if (lang === 'mermaid') {{
          return '<div class="mermaid">' + text + '</div>';
        }}
        return '<pre><code>' + text.replace(/</g, '&lt;') + '</code></pre>';
      }};
      marked.setOptions({{ renderer }});
      document.getElementById('content').innerHTML = marked.parse(raw);
      setTimeout(() => location.reload(), 6000);
    </script>
  </main>
</body>
</html>
"""


class SidecarHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        selected = params.get("file", ["PLAN.md"])[0]

        files = []
        plan_candidates = [
            ("📋 PLAN.md (Coding Worktree)", CODING_WT / "PLAN.md"),
            ("📋 PLAN.md (Hauptverzeichnis)", BASE_DIR / "PLAN.md"),
            ("🧠 MEMORY.md (Langzeit-Gedächtnis)", BASE_DIR / "configs" / "MEMORY.md"),
            ("📘 README.md (Dashboard)", BASE_DIR / "README.md"),
        ]
        for label, p in plan_candidates:
            files.append((label, str(p)))

        if DOCS_DIR.exists():
            for md in sorted(DOCS_DIR.glob("*.md")):
                files.append((f"📄 {md.name}", str(md)))

        target_path = None
        for label, fpath in files:
            if selected in (label, fpath, Path(fpath).name):
                target_path = Path(fpath)
                break
        if target_path is None:
            target_path = BASE_DIR / "README.md"

        if target_path.exists():
            content = target_path.read_text(encoding="utf-8", errors="replace")
        else:
            content = (
                f"# ⏳ `{target_path.name}` existiert noch nicht\n\n"
                "Sobald `@planner` oder `@coder` eine `PLAN.md` im Coding-Worktree anlegt, "
                "erscheint sie hier automatisch in Echtzeit!\n\n"
                "Wähle links in der Seitenleiste ein Handbuch oder Architektur-Diagramm aus."
            )

        nav_html = []
        for label, fpath in files:
            fname = Path(fpath).name
            cls = "active" if target_path and Path(fpath) == target_path else ""
            nav_html.append(
                f'<a class="{cls}" href="/?file={urllib.parse.quote(fname)}">{html.escape(label)}</a>'
            )

        page = HTML_TEMPLATE.format(
            nav_links="\n".join(nav_html),
            raw_markdown=content.replace("</script>", "<\\/script>"),
        )
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(page.encode("utf-8"))


if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer((HOST, PORT), SidecarHandler) as httpd:
        print(f"📊 Sidecar 7 (Live Plan & Mermaid Viewer) läuft auf http://127.0.0.1:{PORT}")
        httpd.serve_forever()

