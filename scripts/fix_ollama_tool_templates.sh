#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# 🔧 Fix für Qwen3-Coder Tool-Calling in Ollama (Multi-Turn History Fix)
# ==============================================================================
# Hintergrund:
#   1. Die GGUF von hf.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF enthält ein
#      XML-Template (<tool_call><function=...>), das Ollamas JSON-Parser verwirft.
#   2. WICHTIG: Im Assistant-Turn müssen {{ if .Content }} UND {{ if .ToolCalls }}
#      getrennte IF-Blöcke sein (NICHT "else if"!), da das Modell sonst bei
#      Text + ToolCall in derselben Nachricht seine eigenen ToolCalls in der
#      Historie verliert und nach 3-4 Schritten nur noch Text ("Ich werde nun...")
#      ohne Tool-Call ausgibt!
# ==============================================================================

TMP_DIR="/tmp/ollama-tool-fix"
mkdir -p "${TMP_DIR}"

cat << 'EOF' > "${TMP_DIR}/qwen_json_tools.tpl"
TEMPLATE """{{- if .Suffix }}<|fim_prefix|>{{ .Prompt }}<|fim_suffix|>{{ .Suffix }}<|fim_middle|>
{{- else }}
{{- if .Messages }}
{{- if or .System .Tools }}<|im_start|>system
{{- if .System }}
{{ .System }}
{{- end }}
{{- if .Tools }}

# Tools

You may call one or more functions to assist with the user query.

You are provided with function signatures within <tools></tools> XML tags:
<tools>
{{- range .Tools }}
{"type": "function", "function": {{ .Function }}}
{{- end }}
</tools>

CRITICAL: To invoke a function, you MUST return a valid JSON object within <tool_call></tool_call> XML tags:
<tool_call>
{"name": "<function-name>", "arguments": <args-json-object>}
</tool_call>
Never output <tools> tags in your response. Never output raw JSON outside <tool_call></tool_call> tags.
{{- end }}<|im_end|>
{{ end }}
{{- range $i, $_ := .Messages }}
{{- $last := eq (len (slice $.Messages $i)) 1 -}}
{{- if eq .Role "user" }}<|im_start|>user
{{ .Content }}<|im_end|>
{{ else if eq .Role "assistant" }}<|im_start|>assistant
{{- if .Content }}
{{ .Content }}
{{- end }}
{{- if .ToolCalls }}
{{- range .ToolCalls }}
<tool_call>
{"name": "{{ .Function.Name }}", "arguments": {{ .Function.Arguments }}}
</tool_call>
{{- end }}
{{- end }}{{ if not $last }}<|im_end|>
{{ end }}
{{- else if eq .Role "tool" }}<|im_start|>user
<tool_response>
{{ .Content }}
</tool_response><|im_end|>
{{ end }}
{{- if and (ne .Role "assistant") $last }}<|im_start|>assistant
{{ end }}
{{- end }}
{{- else }}
{{- if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}{{ if .Prompt }}<|im_start|>user
{{ .Prompt }}<|im_end|>
{{ end }}<|im_start|>assistant
{{ end }}{{ .Response }}{{ if .Response }}<|im_end|>{{ end }}
{{- end }}"""

PARAMETER stop "<|im_end|>"
PARAMETER stop "<|endoftext|>"
EOF

echo "======================================================================"
echo "🔧 Patche Qwen3-Coder Modelle in Ollama (JSON Tool-Call + History Fix)"
echo "======================================================================"

for MODEL in "qwen3-coder-quality" "qwen3-coder-speed" "qwen3.8-35b-distill"; do
    if ollama list 2>/dev/null | grep -q "^${MODEL}"; then
        # Maximierter, 100% VRAM-sicherer Default-Kontext auf der 48 GB W7800 (mit q4_0 KV-Cache):
        # - qwen3-coder-speed (Q4_K_M, ~18.5 GB Gewichte): 131072 (128k!) -> ~24.5 GB Gesamt-VRAM
        # - qwen3.8-35b-distill (Q6_K, ~25.5 GB Gewichte): 98304  (96k!)  -> ~33.0 GB Gesamt-VRAM
        # - qwen3-coder-quality (Q8_0, ~32.0 GB Gewichte): 65536  (64k!)  -> ~35.5 GB Gesamt-VRAM
        if [ "${MODEL}" = "qwen3-coder-speed" ]; then
            CTX_SIZE=131072
            PREDICT_SIZE=16384
        elif [ "${MODEL}" = "qwen3.8-35b-distill" ]; then
            CTX_SIZE=98304
            PREDICT_SIZE=16384
        else
            CTX_SIZE=65536
            PREDICT_SIZE=16384
        fi
        echo "▶ Aktualisiere Template & Max-Kontext für '${MODEL}' (num_ctx=${CTX_SIZE}, ohne Neu-Download)..."
        cat << EOF > "${TMP_DIR}/Modelfile.${MODEL}"
FROM ${MODEL}
PARAMETER num_gpu 999
PARAMETER num_ctx ${CTX_SIZE}
PARAMETER num_batch 2048
PARAMETER num_predict ${PREDICT_SIZE}
PARAMETER temperature 0.2
PARAMETER top_p 0.95
PARAMETER repeat_penalty 1.0
EOF
        cat "${TMP_DIR}/qwen_json_tools.tpl" >> "${TMP_DIR}/Modelfile.${MODEL}"
        ollama create "${MODEL}" -f "${TMP_DIR}/Modelfile.${MODEL}"
        echo "  ✅ '${MODEL}' erfolgreich gepatcht (Max-Kontext: ${CTX_SIZE} Tokens)!"
    else
        echo "  ℹ️ '${MODEL}' nicht in 'ollama list' gefunden (übersprungen)."
    fi
done

rm -rf "${TMP_DIR}"
touch "/tmp/.qwen3_tool_template_patched_v5"
echo "======================================================================"
echo "✅ Fertig! Multi-Turn Tool-Calls bleiben jetzt in der Historie erhalten."
echo "======================================================================"
