#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# 🌳 Git Worktrees Initialisierung für Multi-Agenten
# ==============================================================================
# Nutzung:
#   ./scripts/setup_worktrees.sh                     -> Nutzt agent-cli-setup/projects/main
#   ./scripts/setup_worktrees.sh /pfad/zum/git-repo  -> Nutzt ein bestehendes Git-Projekt
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -n "${1:-}" ]; then
    MAIN_REPO="$(realpath "$1")"
    WORKTREE_DIR="${MAIN_REPO}-worktrees"
else
    MAIN_REPO="${BASE_DIR}/projects/main"
    WORKTREE_DIR="${BASE_DIR}/projects/worktrees"
fi

echo "=========================================================="
echo "🌳 Git Worktrees Initialisierung für Multi-Agenten"
echo "Haupt-Repository: ${MAIN_REPO}"
echo "Ziel-Worktrees:   ${WORKTREE_DIR}"
echo "=========================================================="

mkdir -p "${MAIN_REPO}" "${WORKTREE_DIR}"

# Sicherstellen, dass MAIN_REPO ein sauberes Git-Repository mit mindestens 1 Commit ist
if [ ! -d "${MAIN_REPO}/.git" ]; then
    echo "ℹ️ Initialisiere neues Git-Repository in ${MAIN_REPO}..."
    git -C "${MAIN_REPO}" init -b main
    if [ ! -f "${MAIN_REPO}/README.md" ]; then
        cat << 'EOF' > "${MAIN_REPO}/README.md"
# Multi-Agent Workspace Project
Isoliertes Haupt-Repository für parallele KI-Agenten (Coder, Tester, Reviewer).
EOF
    fi
    git -C "${MAIN_REPO}" add README.md
    git -C "${MAIN_REPO}" -c user.name="Multi-Agent Setup" -c user.email="agent@localhost" commit -m "chore: initial commit for multi-agent worktrees"
fi

# 1. Coder Worktree
if [ ! -d "${WORKTREE_DIR}/coding" ]; then
    echo "• Erstelle Worktree 'coding' (Branch: agent/coding)..."
    git -C "${MAIN_REPO}" worktree add -B agent/coding "${WORKTREE_DIR}/coding"
else
    echo "• Worktree 'coding' existiert bereits (${WORKTREE_DIR}/coding)."
fi

# 2. Tester Worktree
if [ ! -d "${WORKTREE_DIR}/testing" ]; then
    echo "• Erstelle Worktree 'testing' (Branch: agent/testing)..."
    git -C "${MAIN_REPO}" worktree add -B agent/testing "${WORKTREE_DIR}/testing"
else
    echo "• Worktree 'testing' existiert bereits (${WORKTREE_DIR}/testing)."
fi

# 3. Reviewer Worktree
if [ ! -d "${WORKTREE_DIR}/review" ]; then
    echo "• Erstelle Worktree 'review' (Branch: agent/review)..."
    git -C "${MAIN_REPO}" worktree add -B agent/review "${WORKTREE_DIR}/review"
else
    echo "• Worktree 'review' existiert bereits (${WORKTREE_DIR}/review)."
fi

echo -e "\n✅ Alle Worktrees erfolgreich verknüpft:"
git -C "${MAIN_REPO}" worktree list
