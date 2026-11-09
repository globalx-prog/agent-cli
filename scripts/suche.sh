#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# 🔍 Direkte SearXNG Schnellsuche fürs Terminal (Port 8081)
# ==============================================================================
# Nutzung: ./scripts/suche.sh "ROCm 6.4 AMD W7800"
# ==============================================================================

QUERY="${*:-}"
if [ -z "$QUERY" ]; then
    echo "Nutzung: $0 \"Suchbegriff\""
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"searxng_search","arguments":{"query":"%s","max_results":5}}}\n' "$QUERY" \
  | python3 "${SCRIPT_DIR}/mcp_searxng_bridge.py" \
  | python3 -c "
import sys, json
line = sys.stdin.read().strip()
data = json.loads(line)
items = json.loads(data['result']['content'][0]['text'])
for i, item in enumerate(items, 1):
    if 'error' in item:
        print('❌ ' + item['error'])
    else:
        print(f'{i}. \033[1;36m{item.get(\"title\")}\033[0m')
        print(f'   🔗 {item.get(\"url\")}')
        print(f'   📝 {item.get(\"snippet\", \"\")}\n')
"

