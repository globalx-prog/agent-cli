#!/usr/bin/env python3
"""
Lokaler MCP-Server für SearXNG (JSON-RPC 2.0 / MCP 2024-11-05 konform)
Verbindet lokale KI-Agenten (OpenCode, Goose) mit der privaten SearXNG-Instanz (Port 8081).
Garantiert 100% private Websuche ohne Datenweitergabe an externe Search-APIs.
"""

import os
import sys
import json
import urllib.request
import urllib.parse

SEARXNG_URL = os.environ.get("SEARXNG_URL", "http://127.0.0.1:8081/search")

def query_searxng(query: str, max_results: int = 5):
    params = {
        "q": query,
        "format": "json",
        "language": "de-DE",
        "categories": "general"
    }
    url = f"{SEARXNG_URL}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": "Agent-CLI-MCP/1.1"})
    
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                data = json.loads(response.read().decode("utf-8"))
                results = []
                for item in data.get("results", [])[:max_results]:
                    results.append({
                        "title": item.get("title", ""),
                        "url": item.get("url", ""),
                        "snippet": item.get("content", "")
                    })
                return results, False
    except Exception as e:
        return [{"error": f"SearXNG nicht erreichbar ({SEARXNG_URL}): {str(e)}"}], True
    return [], False

def main():
    # JSON-RPC 2.0 STDIO Interface für Model Context Protocol (MCP)
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            method = req.get("method", "")

            # WICHTIG (JSON-RPC 2.0 Spezifikation):
            # Notifications (z. B. "notifications/initialized") besitzen keine "id"
            # und dürfen NIEMALS beantwortet werden!
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
                        "serverInfo": {"name": "local-searxng-mcp", "version": "1.1.0"}
                    }
                }
            elif method == "ping":
                res = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {}
                }
            elif method == "tools/list":
                res = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "tools": [
                            {
                                "name": "searxng_search",
                                "description": "Führt eine lokale, private Websuche über die eigene SearXNG-Instanz (Port 8081) aus.",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "query": {"type": "string", "description": "Suchbegriff / Query"},
                                        "max_results": {"type": "integer", "description": "Maximale Anzahl an Treffern (Standard: 5)", "default": 5}
                                    },
                                    "required": ["query"]
                                }
                            }
                        ]
                    }
                }
            elif method == "tools/call":
                params = req.get("params", {})
                name = params.get("name")
                args = params.get("arguments", {})

                if name == "searxng_search":
                    query = str(args.get("query", ""))
                    max_results = int(args.get("max_results", 5))
                    results, is_error = query_searxng(query, max_results)
                    res = {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "result": {
                            "content": [
                                {"type": "text", "text": json.dumps(results, indent=2, ensure_ascii=False)}
                            ],
                            "isError": is_error
                        }
                    }
                else:
                    res = {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "error": {"code": -32601, "message": f"Tool not found: {name}"}
                    }
            else:
                res = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "error": {"code": -32601, "message": f"Method not found: {method}"}
                }

            sys.stdout.write(json.dumps(res) + "\n")
            sys.stdout.flush()
        except Exception as err:
            err_res = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": f"Parse/Internal error: {str(err)}"}}
            sys.stdout.write(json.dumps(err_res) + "\n")
            sys.stdout.flush()

if __name__ == "__main__":
    main()
