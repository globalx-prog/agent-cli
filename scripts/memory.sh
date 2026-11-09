#!/usr/bin/env bash
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
exec python3 "${SCRIPT_DIR}/mcp_memory_bridge.py" --cli "${1:-list}" "${@:2}"
