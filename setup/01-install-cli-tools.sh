#!/usr/bin/env bash
set -eo pipefail

export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${PATH}"

echo "=========================================================="
echo "📦 Installation von OpenCode & Goose CLI"
echo "=========================================================="

# 1. OpenCode Installation
if ! command -v opencode &>/dev/null; then
    echo "• Installiere OpenCode CLI..."
    curl -fsSL https://opencode.ai/install | bash
else
    echo "• OpenCode ist bereits installiert ($(opencode --version 2>/dev/null || echo "ok"))."
fi

# 2. Goose CLI Installation
if ! command -v goose &>/dev/null; then
    echo "• Installiere Goose CLI..."
    CONFIGURE=false curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | bash
else
    echo "• Goose ist bereits installiert ($(goose --version 2>/dev/null || echo "ok"))."
fi

# 3. Tmux & Jq (optional, falls sudo verfügbar)
echo "• Prüfe System-Utilities (tmux, jq, curl)..."
if ! command -v tmux &>/dev/null || ! command -v jq &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq tmux jq curl || echo "ℹ️ Tmux/Jq Installation übersprungen (kein sudo)."
else
    echo "• tmux und jq sind bereits vorhanden."
fi

# 4. PATH dauerhaft in ~/.bashrc eintragen (verhindert Ubuntu "snap install" Meldung)
if [ -f "${HOME}/.bashrc" ] && ! grep -q ".opencode/bin" "${HOME}/.bashrc"; then
    echo 'export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc"
    echo "• PATH (~/.opencode/bin) dauerhaft in ~/.bashrc eingetragen."
fi

export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${PATH}"
echo -e "\n✅ CLI-Basiswerkzeuge erfolgreich installiert!"
echo "   OpenCode Pfad: $(command -v opencode || echo '~/.opencode/bin/opencode')"
echo "   Goose Pfad:    $(command -v goose || echo '~/.local/bin/goose')"
