#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LLM_ROOT="$(cd "${BASE_DIR}/.." && pwd)"
CONFIG_SRC="${BASE_DIR}/configs"

echo "=========================================================="
echo "🔗 Verknüpfung der Agent-Konfigurationen"
echo "Quelle: ${CONFIG_SRC}"
echo "=========================================================="

# 1. Projekt-lokale Verknüpfung in /home/clemi/Projekte/LLM (funktioniert sofort ohne ~/.config)
mkdir -p "${LLM_ROOT}/.opencode/agents"
ln -sf "${CONFIG_SRC}/opencode.json" "${LLM_ROOT}/opencode.json"
for agent in "${CONFIG_SRC}/agents/"*.md; do
    filename=$(basename "$agent")
    ln -sf "$agent" "${LLM_ROOT}/.opencode/agents/${filename}"
done
echo "✅ Projekt-lokale OpenCode-Konfiguration in ${LLM_ROOT} verlinkt."

# 2. Globale OpenCode Verzeichnisse & Symlinks (~/.config/opencode)
if mkdir -p "${HOME}/.config/opencode/agents" 2>/dev/null; then
    echo "• Verlinke opencode.json -> ${HOME}/.config/opencode/opencode.json"
    ln -sf "${CONFIG_SRC}/opencode.json" "${HOME}/.config/opencode/opencode.json"

    echo "• Verlinke Subagenten (planner, coder, reviewer, tester)..."
    for agent in "${CONFIG_SRC}/agents/"*.md; do
        filename=$(basename "$agent")
        ln -sf "$agent" "${HOME}/.config/opencode/agents/${filename}"
        echo "  -> ${filename}"
    done
fi

# 3. Globale Goose Verzeichnisse & Symlinks (~/.config/goose)
if mkdir -p "${HOME}/.config/goose" 2>/dev/null; then
    echo "• Verlinke goose-config.yaml -> ${HOME}/.config/goose/config.yaml"
    ln -sf "${CONFIG_SRC}/goose-config.yaml" "${HOME}/.config/goose/config.yaml"
fi

echo -e "\n✅ Alle Konfigurationen und Subagenten erfolgreich verlinkt!"
