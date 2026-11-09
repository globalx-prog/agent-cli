#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# 🧹 VRAM- & Backend-Bereinigung für Multi-Agent-Wechsel (AMD Radeon PRO W7800)
# ==============================================================================
# Verhindert VRAM-Kollisionen (48 GB Limit) beim Wechsel zwischen:
#   - Ollama (Port 11434)
#   - llama-speedup / llama-swap (Port 5002 Speculative Decoding)
#   - ComfyUI (Port 8188)
#
# Optionen:
#   --only-ollama   Entlädt nur Ollama-Modelle (macht Platz für llama-speedup)
#   --only-speedup  Entlädt nur llama-speedup auf Port 5002 (macht Platz für Ollama)
#   --all           Vollständige Bereinigung (Ollama + llama-speedup + ComfyUI + Swap)
# ==============================================================================

MODE="all"
for arg in "$@"; do
    case "$arg" in
        --only-ollama)  MODE="ollama" ;;
        --only-speedup) MODE="speedup" ;;
        --all)          MODE="all" ;;
        -h|--help)
            echo "Nutzung: $0 [--only-ollama | --only-speedup | --all]"
            exit 0
            ;;
    esac
done

echo "=========================================================="
echo "🧹 Agent VRAM-Management (Modus: ${MODE})"
echo "=========================================================="

unload_ollama() {
    echo "▶ [Ollama] Prüfe geladene Modelle auf 127.0.0.1:11434 & Tailscale..."
    if command -v ollama &>/dev/null; then
        local ts_ip
        ts_ip="$(tailscale ip -4 2>/dev/null || echo '127.0.0.1')"
        for host in "http://127.0.0.1:11434" "http://${ts_ip}:11434"; do
            ACTIVE_MODELS=$(OLLAMA_HOST="$host" timeout 3 ollama ps 2>/dev/null | awk 'NR>1 {print $1}' || true)
            if [ -n "$ACTIVE_MODELS" ]; then
                for model in $ACTIVE_MODELS; do
                    echo "  -> Stoppe Ollama-Modell ($host): $model"
                    OLLAMA_HOST="$host" timeout 6 ollama stop "$model" 2>/dev/null || true
                done
            fi
        done
        echo "  ✓ Ollama VRAM freigegeben."
    fi
}

unload_speedup() {
    echo "▶ [llama-speedup] Prüfe Speculative Decoding Proxy (Port 5002)..."
    if curl -s -m 2 http://127.0.0.1:5002/unload >/dev/null 2>&1; then
        echo "  ✓ llama-speedup (Port 5002) Modelle entladen."
    else
        echo "  ℹ llama-speedup nicht aktiv oder bereits leer."
    fi
}

if [ "$MODE" = "ollama" ]; then
    unload_ollama
elif [ "$MODE" = "speedup" ]; then
    unload_speedup
else
    unload_speedup
    MASTER_FREE="/home/clemi/Projekte/LLM/image-video-setup/scripts/free_vram.sh"
    if [ -x "$MASTER_FREE" ]; then
        echo "▶ Rufe zentrales System-Bereinigungsskript (free_vram.sh) auf..."
        "$MASTER_FREE"
        exit 0
    else
        unload_ollama
    fi
fi

echo -e "\n✅ Bereinigung abgeschlossen. Aktueller Hardware-Status:"
if [ -x "/home/clemi/Projekte/LLM/scripts/gpu-status.sh" ]; then
    /home/clemi/Projekte/LLM/scripts/gpu-status.sh
elif command -v rocm-smi &>/dev/null; then
    rocm-smi --showmeminfo vram || true
fi
